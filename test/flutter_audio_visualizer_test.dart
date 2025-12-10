import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_audio_visualizer/src/flutter_audio_visualizer_platform_interface.dart';
import 'package:flutter_audio_visualizer/src/flutter_audio_visualizer_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterAudioVisualizerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterAudioVisualizerPlatform {
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
  final FlutterAudioVisualizerPlatform initialPlatform =
      FlutterAudioVisualizerPlatform.instance;

  test('$MethodChannelFlutterAudioVisualizer is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelFlutterAudioVisualizer>(),
    );
  });

  test('initialize', () async {
    final mockPlatform = MockFlutterAudioVisualizerPlatform();
    FlutterAudioVisualizerPlatform.instance = mockPlatform;

    expect(await mockPlatform.initialize(audioSessionId: 0), true);
  });
}
