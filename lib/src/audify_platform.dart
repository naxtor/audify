import 'dart:async';
import 'package:flutter/services.dart';

/// Platform abstraction for Audify plugin.
///
/// This allows injecting a test/mock implementation for unit tests and
/// keeps `AudifyController` decoupled from `MethodChannel`/`EventChannel`.
abstract class AudifyPlatform {
  Future<void> initialize(int audioSessionId, int captureSize);
  Future<void> startCapture();
  Future<void> stopCapture();
  Future<void> release();

  /// Streams raw bytes from the platform FFT event channel.
  Stream<List<int>> fftStream();

  /// Streams raw bytes from the platform waveform event channel.
  Stream<List<int>> waveformStream();
}

/// Default implementation using `MethodChannel`/`EventChannel`.
class MethodChannelAudify implements AudifyPlatform {
  static const MethodChannel _methodChannel = MethodChannel('audify');
  static const EventChannel _fftEventChannel = EventChannel('audify/fft');
  static const EventChannel _waveformEventChannel =
      EventChannel('audify/waveform');

  @override
  Future<void> initialize(int audioSessionId, int captureSize) async {
    await _methodChannel.invokeMethod('initialize', {
      'audioSessionId': audioSessionId,
      'captureSize': captureSize,
    });
  }

  @override
  Future<void> startCapture() async {
    await _methodChannel.invokeMethod('startCapture');
  }

  @override
  Future<void> stopCapture() async {
    await _methodChannel.invokeMethod('stopCapture');
  }

  @override
  Future<void> release() async {
    await _methodChannel.invokeMethod('release');
  }

  @override
  Stream<List<int>> fftStream() {
    return _fftEventChannel
        .receiveBroadcastStream()
        .map((event) => (event as List).cast<int>());
  }

  @override
  Stream<List<int>> waveformStream() {
    return _waveformEventChannel
        .receiveBroadcastStream()
        .map((event) => (event as List).cast<int>());
  }
}
