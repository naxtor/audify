import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Platform abstraction for Audify plugin.
///
/// This allows injecting a test/mock implementation for unit tests and
/// keeps `AudifyController` decoupled from `MethodChannel`/`EventChannel`.
abstract class AudifyPlatform {
  Future<AudifyInitializationResult> initialize(
    int audioSessionId,
    int captureSize,
  );
  Future<void> startCapture();
  Future<void> stopCapture();
  /// Changes the native capture size and returns the size actually applied.
  ///
  /// Call this only after initialization and while capture is stopped.
  Future<int> setCaptureSize(int captureSize);
  Future<void> release();

  /// Streams raw bytes from the platform FFT event channel.
  Stream<List<int>> fftStream();

  /// Streams raw bytes from the platform waveform event channel.
  Stream<List<int>> waveformStream();
}

/// Metadata returned by the native platform after initialization.
class AudifyInitializationResult {
  const AudifyInitializationResult({this.sampleRate, this.captureSize});

  /// Native audio sample rate in Hz.
  final int? sampleRate;

  /// Actual native capture size after platform validation.
  final int? captureSize;
}

/// Default implementation using `MethodChannel`/`EventChannel`.
class MethodChannelAudify implements AudifyPlatform {
  static const MethodChannel _methodChannel = MethodChannel('audify');
  static const EventChannel _fftEventChannel = EventChannel('audify/fft');
  static const EventChannel _waveformEventChannel = EventChannel(
    'audify/waveform',
  );

  @override
  Future<AudifyInitializationResult> initialize(
    int audioSessionId,
    int captureSize,
  ) async {
    final result = await _methodChannel.invokeMethod<dynamic>('initialize', {
      'audioSessionId': audioSessionId,
      'captureSize': captureSize,
    });

    if (result is Map) {
      return AudifyInitializationResult(
        sampleRate: result['sampleRate'] as int?,
        captureSize: result['captureSize'] as int?,
      );
    }

    return const AudifyInitializationResult();
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
  Future<int> setCaptureSize(int captureSize) async {
    final result = await _methodChannel.invokeMethod<dynamic>(
      'setCaptureSize',
      {'captureSize': captureSize},
    );

    if (result is Map) {
      final actualCaptureSize = result['captureSize'];
      if (actualCaptureSize is int && actualCaptureSize > 0) {
        return actualCaptureSize;
      }
    }

    if (result is int && result > 0) {
      return result;
    }

    throw StateError('Platform did not return a valid capture size.');
  }

  @override
  Future<void> release() async {
    await _methodChannel.invokeMethod('release');
  }

  @override
  Stream<List<int>> fftStream() {
    return _fftEventChannel.receiveBroadcastStream().map(decodeAudioByteEvent);
  }

  @override
  Stream<List<int>> waveformStream() {
    return _waveformEventChannel.receiveBroadcastStream().map(
      decodeAudioByteEvent,
    );
  }
}

/// Decodes platform audio byte payloads from typed data or legacy lists.
List<int> decodeAudioByteEvent(dynamic event) {
  if (event is Uint8List) {
    return event;
  }

  if (event is Int8List) {
    return event.map((byte) => byte & 0xFF).toList(growable: false);
  }

  if (event is List) {
    return event.cast<int>();
  }

  throw FormatException(
    'Unsupported audio byte event type: ${event.runtimeType}',
  );
}
