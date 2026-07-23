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
    // Build the shared pipeline once so listeners share a single native
    // subscription rather than clobbering each other's sink. Native replays the
    // live state only on the 0->1 listener transition, so the Dart side caches the
    // last status and hands it to each additional listener: the contract's
    // replay-on-listen then holds for a second concurrent subscriber too.
    final shared = _statusEvents
        .receiveBroadcastStream()
        .map((event) => _statusFrom(event as String?))
        .where((status) => status != null)
        .cast<CaptureStatus>()
        .map((status) => _lastStatus = status);
    _status = Stream<CaptureStatus>.multi((controller) {
      final last = _lastStatus;
      if (last != null) controller.add(last);
      final sub = shared.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  final MethodChannel _methods;
  final EventChannel _statusEvents;
  late final Stream<CaptureStatus> _status;
  CaptureStatus? _lastStatus;

  @override
  Future<PermissionStatus> ensurePermission() async {
    try {
      final raw = await _methods.invokeMethod<String>('ensurePermission');
      return _permissionFrom(raw);
    } on PlatformException catch (e) {
      throw CaptureFailed(e.message, e.code);
    } on MissingPluginException catch (e) {
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
      throw CaptureFailed(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw CaptureFailed(e.message);
    }
  }

  @override
  Future<Recording> stop() async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('stop');
      return Recording(
        path: (result?['name'] as String?) ?? '',
        duration: Duration(milliseconds: (result?['durationMs'] as int?) ?? 0),
      );
    } on PlatformException catch (e) {
      throw CaptureFailed(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw CaptureFailed(e.message);
    }
  }

  @override
  Future<String> recordingsDirectory() async {
    try {
      return await _methods.invokeMethod<String>('recordingsDirectory') ?? '';
    } on PlatformException catch (e) {
      throw CaptureFailed(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw CaptureFailed(e.message);
    }
  }

  @override
  Future<Duration?> probeRecording(String name) async {
    try {
      final ms = await _methods.invokeMethod<int>('probeAudio', {'name': name});
      return ms == null ? null : Duration(milliseconds: ms);
    } on PlatformException catch (e) {
      throw CaptureFailed(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw CaptureFailed(e.message);
    }
  }

  @override
  Future<void> setBackupExcluded(bool excluded) async {
    try {
      await _methods.invokeMethod<void>('setBackupExcluded', {'excluded': excluded});
    } on PlatformException catch (e) {
      throw CaptureFailed(e.message, e.code);
    } on MissingPluginException catch (e) {
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
