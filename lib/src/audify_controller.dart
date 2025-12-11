// lib/src/audio_visualizer_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'frequency_data.dart';

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
  static const MethodChannel _methodChannel = MethodChannel(
    'audify',
  );
  static const EventChannel _fftEventChannel = EventChannel(
    'audify/fft',
  );
  static const EventChannel _waveformEventChannel = EventChannel(
    'audify/waveform',
  );

  StreamSubscription<dynamic>? _fftSubscription;
  StreamSubscription<dynamic>? _waveformSubscription;

  final StreamController<List<double>> _fftStreamController =
      StreamController<List<double>>.broadcast();
  final StreamController<List<double>> _waveformStreamController =
      StreamController<List<double>>.broadcast();
  final StreamController<FrequencyData> _frequencyDataStreamController =
      StreamController<FrequencyData>.broadcast();

  bool _isInitialized = false;
  bool _isCapturing = false;
  int _captureSize = 2048;

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
      await _methodChannel.invokeMethod('initialize', {
        'audioSessionId': audioSessionId,
        'captureSize': _captureSize,
      });

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
      await _methodChannel.invokeMethod('startCapture');

      _fftSubscription = _fftEventChannel.receiveBroadcastStream().listen(
        (data) {
          if (data is List) {
            _processFftData(data.cast<int>());
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('FFT stream error: $error');
          }
        },
      );

      _waveformSubscription =
          _waveformEventChannel.receiveBroadcastStream().listen(
        (data) {
          if (data is List) {
            _processWaveformData(data.cast<int>());
          }
        },
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
      await _methodChannel.invokeMethod('stopCapture');
      await _fftSubscription?.cancel();
      await _waveformSubscription?.cancel();
      _isCapturing = false;
    } catch (e) {
      throw Exception('Failed to stop capture: $e');
    }
  }

  /// Release resources
  Future<void> dispose() async {
    await stopCapture();
    await _methodChannel.invokeMethod('release');
    await _fftStreamController.close();
    await _waveformStreamController.close();
    await _frequencyDataStreamController.close();
    _isInitialized = false;
  }

  void _processFftData(List<int> fftData) {
    try {
      // Convert Android FFT format to magnitude spectrum
      final magnitudes = <double>[];

      // Android Visualizer FFT format: [real0, real1, ..., realN/2, imag1, ..., imagN/2-1]
      final halfSize = fftData.length ~/ 2;

      for (int i = 0; i < halfSize; i++) {
        double real = 0.0;
        double imag = 0.0;

        if (i == 0) {
          // DC component
          real = fftData[0].toDouble();
          imag = 0.0;
        } else if (i == halfSize - 1) {
          // Nyquist frequency
          real = fftData[halfSize].toDouble();
          imag = 0.0;
        } else {
          // Regular bins
          real = fftData[i].toDouble();
          imag = fftData[halfSize + i].toDouble();
        }

        // Calculate magnitude and normalize
        final magnitude = (real * real + imag * imag).abs();
        final normalizedMagnitude =
            magnitude / 32768.0; // Normalize from byte range

        // Apply logarithmic scaling for better visualization
        final logMagnitude = (normalizedMagnitude > 0.0)
            ? (20 * (normalizedMagnitude).clamp(0.0001, 1.0)).clamp(0.0, 1.0)
            : 0.0;

        magnitudes.add(logMagnitude);
      }

      _fftStreamController.add(magnitudes);

      // Process frequency bands
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
      // Convert byte waveform data to normalized doubles (-1.0 to 1.0)
      final normalized = waveformData.map((byte) {
        return (byte - 128) / 128.0;
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
