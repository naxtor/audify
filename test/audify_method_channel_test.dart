import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audify/src/audify_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelAudify platform = MethodChannelAudify();
  const MethodChannel channel = MethodChannel('audify');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'initialize':
          return true;
        case 'startCapture':
          return true;
        case 'stopCapture':
          return true;
        case 'release':
          return true;
        case 'setCaptureSize':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize returns true', () async {
    expect(await platform.initialize(audioSessionId: 0), true);
  });

  test('startCapture returns true', () async {
    expect(await platform.startCapture(), true);
  });

  test('stopCapture returns true', () async {
    expect(await platform.stopCapture(), true);
  });

  test('release returns true', () async {
    expect(await platform.release(), true);
  });

  test('setCaptureSize returns true', () async {
    expect(await platform.setCaptureSize(size: 2048), true);
  });
}
