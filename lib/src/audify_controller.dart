// lib/src/audio_visualizer_controller.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'frequency_data.dart';
import 'audify_platform.dart';

/// Main controller for audio visualization.
///
/// This is the primary app-facing interface for the audify plugin.
/// Use this controller to initialize, start, stop, and manage audio visualization.
///
/// Example:
/// ```dart
/// final controller = AudifyController();
/// await controller.initialize(audioSessionId: 0);
/// await controller.startCapture();
///
/// // Use with widgets
/// CircularSpectrumVisualizer(controller: controller)
/// ```
class AudifyController {
  static const int _defaultCaptureSize = 2048;
  static const int _defaultSampleRate = 44100;

  final AudifyPlatform _platform;

  StreamSubscription<List<int>>? _fftSubscription;
  StreamSubscription<List<int>>? _waveformSubscription;

  final StreamController<List<double>> _fftStreamController =
      StreamController<List<double>>.broadcast();
  final StreamController<List<double>> _waveformStreamController =
      StreamController<List<double>>.broadcast();
  final StreamController<FrequencyData> _frequencyDataStreamController =
      StreamController<FrequencyData>.broadcast();

  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isDisposed = false;
  int _captureSize = _defaultCaptureSize;
  int _sampleRate = _defaultSampleRate;

  DateTime? _lastProcessTime;

  /// Minimum time between FFT processing calls (in milliseconds).
  /// Default targets ~60 FPS -> 16ms.
  final int _minProcessIntervalMs;

  /// Create an `AudifyController`.
  ///
  /// Provide a custom `AudifyPlatform` for testing; otherwise the default
  /// `MethodChannelAudify` is used.
  AudifyController({AudifyPlatform? platform, this._minProcessIntervalMs = 16})
    : _platform = platform ?? MethodChannelAudify();

  /// Stream of raw FFT magnitude data (0.0 - 1.0)
  Stream<List<double>> get fftStream => _fftStreamController.stream;

  /// Stream of raw waveform data (-1.0 - 1.0)
  Stream<List<double>> get waveformStream => _waveformStreamController.stream;

  /// Stream of processed frequency band data
  Stream<FrequencyData> get frequencyDataStream =>
      _frequencyDataStreamController.stream;

  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;

  /// Initialize the visualizer.
  ///
  /// On Android, `audioSessionId: 0` requests output-mix visualization when the
  /// device permits it. Specific player session IDs can target that player.
  /// The current iOS implementation does not use `audioSessionId`.
  Future<void> initialize({
    int audioSessionId = 0,
    int captureSize = _defaultCaptureSize,
  }) async {
    if (_isDisposed) {
      throw StateError('Cannot initialize a disposed AudifyController.');
    }
    _validateCaptureSize(captureSize);

    try {
      // Pass captureSize during initialization (required for API 36+).
      final initializationResult = await _platform.initialize(
        audioSessionId,
        captureSize,
      );

      _captureSize = _positiveOrDefault(
        initializationResult.captureSize,
        captureSize,
      );
      _sampleRate = _positiveOrDefault(
        initializationResult.sampleRate,
        _defaultSampleRate,
      );

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize visualizer: $e');
    }
  }

  /// Start capturing audio data
  Future<void> startCapture() async {
    if (_isDisposed) {
      throw StateError('Cannot start a disposed AudifyController.');
    }

    if (!_isInitialized) {
      throw Exception('Visualizer not initialized. Call initialize() first.');
    }

    if (_isCapturing) {
      return;
    }

    try {
      await _platform.startCapture();

      _fftSubscription = _platform.fftStream().listen(
        (data) => _processFftData(data),
        onError: (error) {
          if (kDebugMode) {
            print('FFT stream error: $error');
          }
        },
      );

      _waveformSubscription = _platform.waveformStream().listen(
        (data) => _processWaveformData(data),
        onError: (error) {
          if (kDebugMode) {
            print('Waveform stream error: $error');
          }
        },
      );

      _isCapturing = true;
    } catch (e) {
      throw Exception('Failed to start capture: $e');
    }
  }

  /// Stop capturing audio data
  Future<void> stopCapture() async {
    if (!_isCapturing) {
      return;
    }

    try {
      await _platform.stopCapture();
    } catch (e) {
      throw Exception('Failed to stop capture: $e');
    } finally {
      await _cancelCaptureSubscriptions();
      _isCapturing = false;
    }
  }

  /// Changes the native capture size used for future audio buffers and FFTs.
  ///
  /// Capture must be stopped first because Android's `Visualizer` does not
  /// permit its capture size to change while enabled. The native platform may
  /// adjust the requested size; the controller uses the applied value when
  /// calculating frequency bands.
  Future<void> setCaptureSize(int captureSize) async {
    if (_isDisposed) {
      throw StateError(
        'Cannot change capture size on a disposed AudifyController.',
      );
    }
    if (!_isInitialized) {
      throw StateError('Initialize the visualizer before changing capture size.');
    }
    if (_isCapturing) {
      throw StateError('Stop capture before changing the capture size.');
    }
    _validateCaptureSize(captureSize);

    try {
      final appliedCaptureSize = await _platform.setCaptureSize(captureSize);
      _validateCaptureSize(appliedCaptureSize);
      _captureSize = appliedCaptureSize;
    } catch (e) {
      throw Exception('Failed to set capture size: $e');
    }
  }

  /// Release resources
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    try {
      if (_isCapturing) {
        await stopCapture();
      }
    } catch (_) {}

    await _cancelCaptureSubscriptions();

    try {
      await _platform.release();
    } catch (_) {}

    await _fftStreamController.close();
    await _waveformStreamController.close();
    await _frequencyDataStreamController.close();
    _isInitialized = false;
    _isDisposed = true;
  }

  void _processFftData(List<int> fftData) {
    try {
      // Throttle processing to _minProcessIntervalMs
      final now = DateTime.now();
      if (_lastProcessTime != null) {
        final diff = now.difference(_lastProcessTime!).inMilliseconds;
        if (diff < _minProcessIntervalMs) return;
      }
      _lastProcessTime = now;

      // Convert Android Visualizer-compatible FFT bytes into magnitudes.
      // The layout is [real0, realNyquist, real1, imag1, real2, imag2, ...].
      // Values are signed 8-bit samples.
      final bytes = fftData;
      final binCount = bytes.length ~/ 2;
      final magnitudes = List<double>.filled(binCount, 0.0);

      for (int i = 0; i < binCount; i++) {
        final realByte = i == 0 ? bytes[0] : bytes[2 * i];
        final imagByte = i == 0 ? 0 : bytes[(2 * i) + 1];

        final real = _signedByteValue(realByte);
        final imag = _signedByteValue(imagByte);

        // Calculate magnitude using Pythagorean theorem
        final magnitude = math.sqrt((real * real) + (imag * imag));

        // Normalize to 0..1 range
        // Maximum possible magnitude: sqrt(128^2 + 128^2), about 181.02.
        final normalized = (magnitude / 181.02).clamp(0.0, 1.0);

        // Apply power curve for better visual response
        // Power < 1.0 compresses dynamic range, making quiet sounds more visible
        // This is intentional for music visualization to show all frequency content
        final enhanced = math.pow(normalized, 0.6).toDouble();

        magnitudes[i] = enhanced;
      }

      _fftStreamController.add(magnitudes);

      final frequencyData = _extractFrequencyBands(magnitudes);
      _frequencyDataStreamController.add(frequencyData);
    } catch (e) {
      if (kDebugMode) {
        print('Error processing FFT data: $e');
      }
    }
  }

  void _processWaveformData(List<int> waveformData) {
    try {
      // Android Visualizer waveform bytes are unsigned 8-bit mono samples
      // centered at 128. Platform codecs may surface raw bytes as signed ints,
      // so mask first and then normalize around the unsigned midpoint.
      final normalized = waveformData.map((b) {
        final centered = _unsignedByteValue(b) - 128;
        final divisor = centered < 0 ? 128.0 : 127.0;
        return (centered / divisor).clamp(-1.0, 1.0);
      }).toList();

      _waveformStreamController.add(normalized);
    } catch (e) {
      if (kDebugMode) {
        print('Error processing waveform data: $e');
      }
    }
  }

  FrequencyData _extractFrequencyBands(List<double> magnitudes) {
    // Define frequency bands (in Hz)
    final frequencyResolution = _sampleRate / _captureSize;

    // Frequency bands for trap/dubstep visualization
    final bands = [
      _getBandMagnitude(magnitudes, 20, 60, frequencyResolution), // Sub bass
      _getBandMagnitude(magnitudes, 60, 250, frequencyResolution), // Bass
      _getBandMagnitude(magnitudes, 250, 500, frequencyResolution), // Low mids
      _getBandMagnitude(magnitudes, 500, 2000, frequencyResolution), // Mids
      _getBandMagnitude(
        magnitudes,
        2000,
        4000,
        frequencyResolution,
      ), // High mids
      _getBandMagnitude(
        magnitudes,
        4000,
        6000,
        frequencyResolution,
      ), // Presence
      _getBandMagnitude(
        magnitudes,
        6000,
        20000,
        frequencyResolution,
      ), // Brilliance
    ];

    return FrequencyData(bands: bands, rawMagnitudes: magnitudes);
  }

  double _getBandMagnitude(
    List<double> magnitudes,
    double startFreq,
    double endFreq,
    double frequencyResolution,
  ) {
    final startBin = (startFreq / frequencyResolution).floor();
    final endBin = (endFreq / frequencyResolution).ceil();

    if (startBin >= magnitudes.length) return 0.0;

    final clampedEndBin = endBin.clamp(startBin, magnitudes.length - 1);

    double sum = 0.0;
    int count = 0;

    for (int i = startBin; i <= clampedEndBin; i++) {
      sum += magnitudes[i];
      count++;
    }

    return count > 0 ? sum / count : 0.0;
  }

  static int _positiveOrDefault(int? value, int fallback) {
    return value != null && value > 0 ? value : fallback;
  }

  static void _validateCaptureSize(int captureSize) {
    if (captureSize <= 0) {
      throw ArgumentError.value(
        captureSize,
        'captureSize',
        'Must be greater than zero.',
      );
    }
  }

  static int _unsignedByteValue(int byte) => byte & 0xFF;

  static int _signedByteValue(int byte) {
    final unsigned = _unsignedByteValue(byte);
    return unsigned >= 128 ? unsigned - 256 : unsigned;
  }

  Future<void> _cancelCaptureSubscriptions() async {
    await _fftSubscription?.cancel();
    _fftSubscription = null;

    await _waveformSubscription?.cancel();
    _waveformSubscription = null;
  }
}
