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
  int _captureSize = 2048;

  DateTime? _lastProcessTime;

  /// Minimum time between FFT processing calls (in milliseconds).
  /// Default targets ~60 FPS -> 16ms.
  final int _minProcessIntervalMs;

  /// Create an `AudifyController`.
  ///
  /// Provide a custom `AudifyPlatform` for testing; otherwise the default
  /// `MethodChannelAudify` is used.
  AudifyController({AudifyPlatform? platform, int minProcessIntervalMs = 16})
      : _platform = platform ?? MethodChannelAudify(),
        _minProcessIntervalMs = minProcessIntervalMs;

  /// Stream of raw FFT magnitude data (0.0 - 1.0)
  Stream<List<double>> get fftStream => _fftStreamController.stream;

  /// Stream of raw waveform data (-1.0 - 1.0)
  Stream<List<double>> get waveformStream => _waveformStreamController.stream;

  /// Stream of processed frequency band data
  Stream<FrequencyData> get frequencyDataStream =>
      _frequencyDataStreamController.stream;

  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;

  /// Initialize the visualizer with an audio session ID
  /// For system audio: use 0
  /// For specific MediaPlayer: use player.audioSessionId
  Future<void> initialize({
    int audioSessionId = 0,
    int captureSize = 2048,
  }) async {
    try {
      _captureSize = captureSize;
      // Pass captureSize during initialization (required for API 36+)
      await _platform.initialize(audioSessionId, _captureSize);

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize visualizer: $e');
    }
  }

  /// Start capturing audio data
  Future<void> startCapture() async {
    if (!_isInitialized) {
      throw Exception('Visualizer not initialized. Call initialize() first.');
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
    try {
      await _platform.stopCapture();

      await _fftSubscription?.cancel();
      _fftSubscription = null;

      await _waveformSubscription?.cancel();
      _waveformSubscription = null;

      _isCapturing = false;
    } catch (e) {
      throw Exception('Failed to stop capture: $e');
    }
  }

  /// Release resources
  Future<void> dispose() async {
    try {
      if (_isCapturing) {
        await stopCapture();
      }
    } catch (_) {}

    try {
      await _platform.release();
    } catch (_) {}

    await _fftStreamController.close();
    await _waveformStreamController.close();
    await _frequencyDataStreamController.close();
    _isInitialized = false;
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

      // Convert Android Visualizer FFT format (bytes) into magnitudes.
      // Visualizer returns bytes representing signed 8-bit values.
      final bytes = fftData;
      final halfSize = bytes.length ~/ 2;
      final magnitudes = <double>[];

      for (int i = 0; i < halfSize; i++) {
        int realByte = bytes[i];
        // Android FFT format: imaginary parts start at index n/2+1 for frequency bin 1
        // So for bin i (where i > 0 and i < n/2), imaginary is at halfSize + i - 1
        int imagByte =
            (i == 0 || i == halfSize - 1) ? 0 : bytes[halfSize + i - 1];

        // Convert to signed 8-bit (-128..127)
        int real = realByte & 0xFF;
        if (real >= 128) real -= 256;

        int imag = imagByte & 0xFF;
        if (imag >= 128) imag -= 256;

        // Calculate magnitude using Pythagorean theorem
        final magnitude = math.sqrt((real * real) + (imag * imag));

        // Normalize to 0..1 range
        // Maximum possible magnitude: sqrt(128^2 + 128^2) ≈ 181.02
        final normalized = (magnitude / 181.02).clamp(0.0, 1.0);

        // Apply power curve for better visual response
        // Power < 1.0 compresses dynamic range, making quiet sounds more visible
        // This is intentional for music visualization to show all frequency content
        final enhanced = math.pow(normalized, 0.6).toDouble();

        magnitudes.add(enhanced);
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
      // Convert bytes (0..255) or signed (-128..127) to -1.0..1.0
      // Use 127.0 as divisor since signed 8-bit range is -128 to +127
      final normalized = waveformData.map((b) {
        int v = b & 0xFF;
        if (v >= 128) v -= 256;
        return (v / 127.0).clamp(-1.0, 1.0);
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
    // Assuming sample rate of 44100 Hz
    const sampleRate = 44100;
    final frequencyResolution = sampleRate / _captureSize;

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
}
