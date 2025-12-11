import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audify_method_channel.dart';

abstract class AudifyPlatform extends PlatformInterface {
  /// Constructs a AudifyPlatform.
  AudifyPlatform() : super(token: _token);

  static final Object _token = Object();

  static AudifyPlatform _instance = MethodChannelAudify();

  /// The default instance of [AudifyPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudify].
  static AudifyPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudifyPlatform] when
  /// they register themselves.
  static set instance(AudifyPlatform instance) {
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
