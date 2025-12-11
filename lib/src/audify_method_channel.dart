import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audify_platform_interface.dart';

/// An implementation of [AudifyPlatform] that uses method channels.
class MethodChannelAudify extends AudifyPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audify');

  @override
  Future<bool> initialize({required int audioSessionId}) async {
    try {
      final result = await methodChannel.invokeMethod<bool>('initialize', {
        'audioSessionId': audioSessionId,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing visualizer: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> setCaptureSize({required int size}) async {
    try {
      final result = await methodChannel.invokeMethod<bool>('setCaptureSize', {
        'size': size,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error setting capture size: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> startCapture() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('startCapture');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting capture: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> stopCapture() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('stopCapture');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping capture: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> release() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('release');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error releasing visualizer: $e');
      }
      return false;
    }
  }
}
