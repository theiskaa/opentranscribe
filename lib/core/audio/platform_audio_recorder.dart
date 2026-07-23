import 'package:flutter/services.dart';

import 'package:opentranscribe/core/audio/audio_recorder.dart';
import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

// Channel identifiers. Must match AudioCapture.swift.
const _controlChannel = 'opentranscribe/audio';
const _statusChannel = 'opentranscribe/audio/status';

/// The iOS-native [AudioRecorder]: an AVAudioEngine capture session reached over
/// platform channels. Control on a MethodChannel, capture status on an
/// EventChannel. Audio itself stays native; only the file path, duration, and
/// status cross into Dart. Channel failures are mapped to the transcription
/// exception taxonomy, so callers never see a raw PlatformException.
class PlatformAudioRecorder implements AudioRecorder {
  PlatformAudioRecorder({MethodChannel? methods, EventChannel? statusEvents})
    : _methods = methods ?? const MethodChannel(_controlChannel),
      _statusEvents = statusEvents ?? const EventChannel(_statusChannel) {
    // Build the status stream once so multiple listeners share a single native
    // subscription rather than clobbering each other's sink.
    _status = _statusEvents
        .receiveBroadcastStream()
        .map((event) => _statusFrom(event as String?))
        .where((status) => status != null)
        .cast<CaptureStatus>();
  }

  final MethodChannel _methods;
  final EventChannel _statusEvents;
  late final Stream<CaptureStatus> _status;

  @override
  Future<PermissionStatus> ensurePermission() async {
    try {
      final raw = await _methods.invokeMethod<String>('ensurePermission');
      return _permissionFrom(raw);
    } on PlatformException catch (e) {
      throw CaptureFailed(e.message);
    }
  }

  /// Capture lifecycle. Subscribe before calling [start]; the stream does not
  /// replay past events to a late listener except the current live state on listen.
  @override
  Stream<CaptureStatus> get status => _status;

  @override
  Future<void> start() async {
    try {
      await _methods.invokeMethod<void>('start');
    } on PlatformException catch (e) {
      throw CaptureFailed(e.message);
    }
  }

  @override
  Future<Recording> stop() async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('stop');
      return Recording(
        path: (result?['path'] as String?) ?? '',
        duration: Duration(milliseconds: (result?['durationMs'] as int?) ?? 0),
      );
    } on PlatformException catch (e) {
      throw CaptureFailed(e.message);
    }
  }

  PermissionStatus _permissionFrom(String? raw) => switch (raw) {
    'granted' => PermissionStatus.granted,
    'denied' => PermissionStatus.denied,
    'restricted' => PermissionStatus.restricted,
    _ => PermissionStatus.undetermined,
  };

  CaptureStatus? _statusFrom(String? raw) => switch (raw) {
    'recording' => CaptureStatus.recording,
    'interrupted' => CaptureStatus.interrupted,
    'stopped' => CaptureStatus.stopped,
    _ => null,
  };
}
