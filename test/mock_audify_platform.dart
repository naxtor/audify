import 'dart:async';
import 'package:audify/src/audify_platform.dart';

/// Mock implementation of [AudifyPlatform] for testing.
///
/// Allows tests to simulate platform behavior without requiring actual
/// MethodChannel/EventChannel communication.
class MockAudifyPlatform implements AudifyPlatform {
  bool _isInitialized = false;
  bool _isCapturing = false;

  final StreamController<List<int>> _fftController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> _waveformController =
      StreamController<List<int>>.broadcast();

  // Test control: simulate platform errors
  bool shouldThrowOnInitialize = false;
  bool shouldThrowOnStartCapture = false;
  bool shouldThrowOnStopCapture = false;

  // Test inspection: track method calls
  int initializeCallCount = 0;
  int startCaptureCallCount = 0;
  int stopCaptureCallCount = 0;
  int releaseCallCount = 0;

  int? lastAudioSessionId;
  int? lastCaptureSize;

  @override
  Future<void> initialize(int audioSessionId, int captureSize) async {
    initializeCallCount++;
    lastAudioSessionId = audioSessionId;
    lastCaptureSize = captureSize;

    if (shouldThrowOnInitialize) {
      throw Exception('Mock initialization error');
    }

    _isInitialized = true;
  }

  @override
  Future<void> startCapture() async {
    startCaptureCallCount++;

    if (shouldThrowOnStartCapture) {
      throw Exception('Mock start capture error');
    }

    if (!_isInitialized) {
      throw Exception('Platform not initialized');
    }

    _isCapturing = true;
  }

  @override
  Future<void> stopCapture() async {
    if (shouldThrowOnStopCapture) {
      stopCaptureCallCount++;
      throw Exception('Mock stop capture error');
    }

    stopCaptureCallCount++;
    _isCapturing = false;
  }

  @override
  Future<void> release() async {
    releaseCallCount++;
    _isInitialized = false;
    _isCapturing = false;
  }

  @override
  Stream<List<int>> fftStream() {
    return _fftController.stream;
  }

  @override
  Stream<List<int>> waveformStream() {
    return _waveformController.stream;
  }

  // Test helpers: emit mock data
  void emitFftData(List<int> data) {
    _fftController.add(data);
  }

  void emitWaveformData(List<int> data) {
    _waveformController.add(data);
  }

  // Test cleanup
  Future<void> dispose() async {
    await _fftController.close();
    await _waveformController.close();
  }

  // Test helpers: state inspection
  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
}
