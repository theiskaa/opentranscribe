import 'dart:async';

import 'package:opentranscribe/core/audio/audio_recorder.dart';
import 'package:opentranscribe/core/audio/recording.dart';

/// In-memory [AudioRecorder] for tests. Emits capture status and, on stop,
/// completes [stopped] so a paired streaming engine can settle its final event,
/// modeling the native session both share without a mic.
class FakeAudioRecorder implements AudioRecorder {
  FakeAudioRecorder({
    this.path = '/tmp/fake-recording.m4a',
    this.duration = const Duration(seconds: 2),
    this.permission = PermissionStatus.granted,
  });

  final String path;
  final Duration duration;
  final PermissionStatus permission;

  final StreamController<CaptureStatus> _status = StreamController<CaptureStatus>.broadcast();
  final Completer<void> _stopped = Completer<void>();

  /// Completes when [stop] is called. Wire this into a FakeStreamingEngine's
  /// stopSignal so its final event lands when capture stops.
  Future<void> get stopped => _stopped.future;

  @override
  Future<PermissionStatus> ensurePermission() async => permission;

  @override
  Stream<CaptureStatus> get status => _status.stream;

  @override
  Future<void> start() async {
    _status.add(CaptureStatus.recording);
  }

  @override
  Future<Recording> stop() async {
    _status.add(CaptureStatus.stopped);
    if (!_stopped.isCompleted) _stopped.complete();
    return Recording(path: path, duration: duration);
  }
}
