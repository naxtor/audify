import 'package:flutter_test/flutter_test.dart';
import 'package:audify/src/audify_platform_interface.dart';
import 'package:audify/src/audify_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAudifyPlatform
    with MockPlatformInterfaceMixin
    implements AudifyPlatform {
  @override
  Future<bool> initialize({required int audioSessionId}) => Future.value(true);

  @override
  Future<bool> setCaptureSize({required int size}) => Future.value(true);

  @override
  Future<bool> startCapture() => Future.value(true);

  @override
  Future<bool> stopCapture() => Future.value(true);

  @override
  Future<bool> release() => Future.value(true);
}

void main() {
  final AudifyPlatform initialPlatform = AudifyPlatform.instance;

  test('$MethodChannelAudify is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelAudify>(),
    );
  });

  test('initialize', () async {
    final mockPlatform = MockAudifyPlatform();
    AudifyPlatform.instance = mockPlatform;

    expect(await mockPlatform.initialize(audioSessionId: 0), true);
  });
}
