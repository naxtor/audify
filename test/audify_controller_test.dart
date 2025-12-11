import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audify/src/audify_controller.dart';
import 'package:audify/src/frequency_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('audify');
  const EventChannel fftEventChannel = EventChannel('audify/fft');
  const EventChannel waveformEventChannel = EventChannel('audify/waveform');

  late AudifyController controller;

  setUp(() {
    controller = AudifyController();
  });

  tearDown(() async {
    // Mock dispose methods to prevent errors during cleanup
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'stopCapture' ||
          methodCall.method == 'release') {
        return true;
      }
      return null;
    });

    await controller.dispose();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(fftEventChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(waveformEventChannel, null);
  });

  group('AudifyController Initialization', () {
    test('controller starts in uninitialized state', () {
      expect(controller.isInitialized, false);
      expect(controller.isCapturing, false);
    });

    test('initialize sets isInitialized to true', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          expect(methodCall.arguments['audioSessionId'], 0);
          expect(methodCall.arguments['captureSize'], 2048);
          return true;
        }
        return null;
      });

      await controller.initialize(audioSessionId: 0);
      expect(controller.isInitialized, true);
    });

    test('initialize with custom captureSize', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          expect(methodCall.arguments['captureSize'], 1024);
          return true;
        }
        return null;
      });

      await controller.initialize(audioSessionId: 0, captureSize: 1024);
      expect(controller.isInitialized, true);
    });

    test('initialize throws exception on failure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          throw PlatformException(
              code: 'INIT_ERROR', message: 'Failed to initialize');
        }
        return null;
      });

      expect(
        () => controller.initialize(audioSessionId: 0),
        throwsA(isA<Exception>()),
      );
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
      // Setup initialization
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          return true;
        }
        if (methodCall.method == 'startCapture') {
          return true;
        }
        return null;
      });

      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();
      expect(controller.isCapturing, true);
    });

    test('stopCapture sets isCapturing to false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          return true;
        }
        if (methodCall.method == 'startCapture') {
          return true;
        }
        if (methodCall.method == 'stopCapture') {
          return true;
        }
        return null;
      });

      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();
      await controller.stopCapture();
      expect(controller.isCapturing, false);
    });
  });

  group('AudifyController Streams', () {
    test('fftStream is available after initialization', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        return true;
      });

      await controller.initialize(audioSessionId: 0);

      // Verify stream is accessible (actual data emission tested in integration tests)
      expect(controller.fftStream, isNotNull);
      expect(controller.fftStream, isA<Stream<List<double>>>());
    });

    test('waveformStream is available after initialization', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        return true;
      });

      await controller.initialize(audioSessionId: 0);

      // Verify stream is accessible (actual data emission tested in integration tests)
      expect(controller.waveformStream, isNotNull);
      expect(controller.waveformStream, isA<Stream<List<double>>>());
    });

    test('frequencyDataStream is available after initialization', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        return true;
      });

      await controller.initialize(audioSessionId: 0);

      // Verify stream is accessible (actual data emission tested in integration tests)
      expect(controller.frequencyDataStream, isNotNull);
      expect(controller.frequencyDataStream, isA<Stream<FrequencyData>>());
    });
  });

  group('AudifyController Lifecycle', () {
    test('dispose cleans up resources', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        return true;
      });

      await controller.initialize(audioSessionId: 0);
      await controller.startCapture();

      // Should not throw
      await controller.dispose();

      // After dispose, controller should be in clean state
      expect(controller.isCapturing, false);
    });

    test('dispose can be called multiple times safely', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        return true;
      });

      await controller.initialize(audioSessionId: 0);

      // Should not throw
      await controller.dispose();
      await controller.dispose();
      await controller.dispose();
    });
  });

  group('AudifyController Error Handling', () {
    test('handles platform errors gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          return true;
        }
        if (methodCall.method == 'startCapture') {
          throw PlatformException(
              code: 'CAPTURE_ERROR', message: 'Failed to start');
        }
        return null;
      });

      await controller.initialize(audioSessionId: 0);

      expect(
        () => controller.startCapture(),
        throwsA(isA<Exception>()),
      );
    });

    test('handles null responses from platform', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel,
              (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          return null; // Simulate null response
        }
        return true;
      });

      // Should still set initialized state (implementation handles null)
      await controller.initialize(audioSessionId: 0);
      expect(controller.isInitialized, true);
    });
  });
}
