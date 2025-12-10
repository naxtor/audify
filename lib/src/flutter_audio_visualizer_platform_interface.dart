import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_audio_visualizer_method_channel.dart';

abstract class FlutterAudioVisualizerPlatform extends PlatformInterface {
  /// Constructs a FlutterAudioVisualizerPlatform.
  FlutterAudioVisualizerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAudioVisualizerPlatform _instance =
      MethodChannelFlutterAudioVisualizer();

  /// The default instance of [FlutterAudioVisualizerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterAudioVisualizer].
  static FlutterAudioVisualizerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterAudioVisualizerPlatform] when
  /// they register themselves.
  static set instance(FlutterAudioVisualizerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize the audio visualizer with an audio session ID
  /// For system audio: use 0
  /// For specific MediaPlayer: use player.audioSessionId
  Future<bool> initialize({required int audioSessionId}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Set the capture size for FFT processing
  Future<bool> setCaptureSize({required int size}) {
    throw UnimplementedError('setCaptureSize() has not been implemented.');
  }

  /// Start capturing audio data
  Future<bool> startCapture() {
    throw UnimplementedError('startCapture() has not been implemented.');
  }

  /// Stop capturing audio data
  Future<bool> stopCapture() {
    throw UnimplementedError('stopCapture() has not been implemented.');
  }

  /// Release all resources
  Future<bool> release() {
    throw UnimplementedError('release() has not been implemented.');
  }
}
