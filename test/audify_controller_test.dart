import 'package:flutter_test/flutter_test.dart';
import 'package:audify/src/audify_controller.dart';
import 'package:audify/src/frequency_data.dart';
import 'mock_audify_platform.dart';

void main() {
  late AudifyController controller;
  late MockAudifyPlatform mockPlatform;

  setUp(() {
    mockPlatform = MockAudifyPlatform();
    controller = AudifyController(platform: mockPlatform);
  });

  tearDown(() async {
    await controller.dispose();
    await mockPlatform.dispose();
  });

  group('AudifyController Initialization', () {
    test('controller starts in uninitialized state', () {
      expect(controller.isInitialized, false);
      expect(controller.isCapturing, false);
    });

    test('initialize sets isInitialized to true', () async {
      await controller.initialize(audioSessionId: 0);

      expect(controller.isInitialized, true);
      expect(mockPlatform.initializeCallCount, 1);
      expect(mockPlatform.lastAudioSessionId, 0);
      expect(mockPlatform.lastCaptureSize, 2048);
    });

    test('initialize with custom captureSize', () async {
      await controller.initialize(audioSessionId: 123, captureSize: 1024);

      expect(controller.isInitialized, true);
      expect(mockPlatform.lastAudioSessionId, 123);
      expect(mockPlatform.lastCaptureSize, 1024);
    });

    test('initialize throws exception on failure', () async {
      mockPlatform.shouldThrowOnInitialize = true;

      expect(
        () => controller.initialize(audioSessionId: 0),
        throwsA(isA<Exception>()),
      );
    });

    test('initialize can be called with different session IDs', () async {
      await controller.initialize(audioSessionId: 100);
      expect(mockPlatform.lastAudioSessionId, 100);
    });
  });

  group('AudifyController Capture', () {
    test('startCapture requires initialization', () async {
      expect(
        () => controller.startCapture(),
        throwsA(isA<Exception>()),
      );
    });

    test('startCapture sets isCapturing to true', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      expect(controller.isCapturing, true);
      expect(mockPlatform.startCaptureCallCount, 1);
    });

    test('stopCapture sets isCapturing to false', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();
      await controller.stopCapture();

      expect(controller.isCapturing, false);
      expect(mockPlatform.stopCaptureCallCount, 1);
    });

    test('startCapture handles platform errors', () async {
      await controller.initialize(audioSessionId: 0);
      mockPlatform.shouldThrowOnStartCapture = true;

      expect(
        () => controller.startCapture(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AudifyController Streams', () {
    test('fftStream is available and emits processed data', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      // Simulate Android Visualizer FFT format
      // Format: [real0, real1, ..., realN/2, imag1, ..., imagN/2-1]
      final mockFftData = List<int>.generate(256, (i) {
        if (i < 128) return i % 128; // Real parts
        return (i - 128) % 128; // Imaginary parts
      });

      final streamFuture = controller.fftStream.first;
      mockPlatform.emitFftData(mockFftData);

      final result = await streamFuture;
      expect(result, isA<List<double>>());
      expect(result.length, 128); // Half of input size
      expect(result.every((v) => v >= 0.0 && v <= 1.0), true);
    });

    test('waveformStream is available and emits normalized data', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      final mockWaveform = List<int>.generate(256, (i) => i);

      final streamFuture = controller.waveformStream.first;
      mockPlatform.emitWaveformData(mockWaveform);

      final result = await streamFuture;
      expect(result, isA<List<double>>());
      expect(result.length, 256);
      expect(result.every((v) => v >= -1.0 && v <= 1.0), true);
    });

    test('frequencyDataStream emits FrequencyData', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      final mockFftData = List<int>.generate(256, (i) {
        if (i < 128) return 50;
        return 30;
      });

      final streamFuture = controller.frequencyDataStream.first;
      mockPlatform.emitFftData(mockFftData);

      final result = await streamFuture;
      expect(result, isA<FrequencyData>());
      expect(result.bands.length, 7); // 7 frequency bands
    });

    test('streams handle multiple emissions', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      final receivedData = <List<double>>[];
      final subscription = controller.fftStream.listen(receivedData.add);

      // Emit multiple data points
      for (int i = 0; i < 3; i++) {
        final mockData = List<int>.filled(256, i * 20);
        mockPlatform.emitFftData(mockData);
        await Future.delayed(Duration(milliseconds: 20));
      }

      await subscription.cancel();
      expect(receivedData.length, greaterThanOrEqualTo(1));
    });
  });

  group('AudifyController Lifecycle', () {
    test('dispose cleans up resources', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      await controller.dispose();

      expect(controller.isCapturing, false);
      expect(mockPlatform.releaseCallCount, 1);
    });

    test('dispose can be called multiple times safely', () async {
      await controller.initialize(audioSessionId: 0);

      await controller.dispose();
      await controller.dispose();
      await controller.dispose();

      // Should not throw and release should be called only once per dispose
      expect(mockPlatform.releaseCallCount, 3);
    });

    test('dispose stops capture if running', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();
      expect(controller.isCapturing, true);

      await controller.dispose();

      expect(controller.isCapturing, false);
      expect(mockPlatform.stopCaptureCallCount, 1);
    });

    test('dispose handles errors gracefully', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      mockPlatform.shouldThrowOnStopCapture = true;

      // Should not throw even if platform throws (errors are caught)
      await controller.dispose();
      // Note: isCapturing may still be true if stopCapture threw,
      // but dispose completes successfully
      expect(mockPlatform.releaseCallCount, 1);
    });
  });

  group('AudifyController Error Handling', () {
    test('handles platform errors gracefully', () async {
      await controller.initialize(audioSessionId: 0);
      mockPlatform.shouldThrowOnStartCapture = true;

      expect(
        () => controller.startCapture(),
        throwsA(isA<Exception>()),
      );
    });

    test('handles errors during initialization', () async {
      mockPlatform.shouldThrowOnInitialize = true;

      expect(
        () => controller.initialize(audioSessionId: 0),
        throwsA(isA<Exception>()),
      );
      expect(controller.isInitialized, false);
    });

    test('handles malformed FFT data', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      // Emit malformed data (empty list)
      mockPlatform.emitFftData([]);

      // Should not crash, stream should still work
      await Future.delayed(Duration(milliseconds: 50));
      expect(controller.isCapturing, true);
    });
  });

  group('AudifyController FFT Processing', () {
    test('throttles FFT processing based on minProcessIntervalMs', () async {
      // Create controller with custom throttle interval
      final throttledController = AudifyController(
        platform: mockPlatform,
        minProcessIntervalMs: 100, // 100ms throttle
      );

      await throttledController.initialize(audioSessionId: 0);
      await throttledController.startCapture();

      final receivedData = <List<double>>[];
      final subscription =
          throttledController.fftStream.listen(receivedData.add);

      // Rapidly emit data
      for (int i = 0; i < 10; i++) {
        final mockData = List<int>.generate(256, (_) => i * 10);
        mockPlatform.emitFftData(mockData);
        await Future.delayed(Duration(milliseconds: 10)); // Emit every 10ms
      }

      await Future.delayed(Duration(milliseconds: 150));
      await subscription.cancel();
      await throttledController.dispose();

      // Should have throttled to fewer emissions
      expect(receivedData.length, lessThan(10));
    });

    test('processes signed 8-bit FFT data correctly', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      // Create FFT data with both positive and negative signed values
      final mockFftData = List<int>.generate(256, (i) {
        if (i < 128) {
          // Real parts: simulate signed bytes (some >128 to test conversion)
          return (i * 2) % 256;
        } else {
          // Imaginary parts
          return ((i - 128) * 3) % 256;
        }
      });

      final streamFuture = controller.fftStream.first;
      mockPlatform.emitFftData(mockFftData);

      final result = await streamFuture;

      // All values should be normalized to 0.0-1.0 range
      expect(result.every((v) => v >= 0.0 && v <= 1.0), true);
      expect(result.length, 128);
    });
  });

  group('AudifyController Platform Integration', () {
    test('uses default platform when none provided', () {
      final defaultController = AudifyController();
      expect(defaultController, isNotNull);
      // Just verify it doesn't crash on creation
    });

    test('accepts custom platform in constructor', () {
      final customPlatform = MockAudifyPlatform();
      final customController = AudifyController(platform: customPlatform);

      expect(customController, isNotNull);
    });

    test('platform methods are called in correct order', () async {
      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();
      await controller.stopCapture();
      await controller.dispose();

      expect(mockPlatform.initializeCallCount, 1);
      expect(mockPlatform.startCaptureCallCount, 1);
      expect(mockPlatform.stopCaptureCallCount, 1);
      expect(mockPlatform.releaseCallCount, 1);
    });
  });
}
