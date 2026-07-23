import 'dart:async';

import 'package:opentranscribe/core/audio/audio_recorder.dart';
import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

/// In-memory [AudioRecorder] for tests. Emits capture status and, on stop,
/// completes [stopped] so a paired streaming engine can settle its final event,
/// modeling the native session both share without a mic.
class FakeAudioRecorder implements AudioRecorder {
  FakeAudioRecorder({
    this.path = 'fake-recording.m4a',
    this.duration = const Duration(seconds: 2),
    this.permission = PermissionStatus.granted,
    this.recordingsDir = '/tmp',
    this.throwOnSetBackup = false,
    this.throwOnStart = false,
    this.stopDelay,
    this.startDelay,
    this.probe,
  });

  final String path;
  final Duration duration;
  final PermissionStatus permission;
  final String recordingsDir;

  /// Delays [stop]'s completion, so a test can open the window where a finalize is
  /// in flight and race it with a user stop.
  final Duration? stopDelay;

  /// When true, [setBackupExcluded] throws, to exercise best-effort apply paths.
  final bool throwOnSetBackup;

  /// When true, [start] throws, to exercise failed-start cleanup paths. Mutable
  /// so a test can fail the SECOND start after a successful first.
  bool throwOnStart;

  /// Answers [probeRecording] per name; null (the default) probes nothing readable.
  final Duration? Function(String name)? probe;

  /// The last value passed to [setBackupExcluded], for assertions.
  bool? backupExcluded;

  final StreamController<CaptureStatus> _status = StreamController<CaptureStatus>.broadcast();
  final Completer<void> _stopped = Completer<void>();

  /// Completes when [stop] is called. Wire this into a FakeStreamingEngine's
  /// stopSignal so its final event lands when capture stops.
  Future<void> get stopped => _stopped.future;

  @override
  Future<PermissionStatus> ensurePermission() async => permission;

  @override
  Stream<CaptureStatus> get status => _status.stream;

  /// Delays [start]'s completion, so a test can interleave an interruption with
  /// an in-flight start.
  final Duration? startDelay;

  @override
  Future<void> start() async {
    if (throwOnStart) throw const CaptureFailed('fake start failure');
    if (startDelay != null) await Future<void>.delayed(startDelay!);
    _status.add(CaptureStatus.recording);
  }

  /// Simulates a native interruption (a phone call), so a test can exercise the
  /// service's auto-finalize. [stop] still returns a [Recording] afterward.
  void interrupt() {
    _status.add(CaptureStatus.interrupted);
  }

  @override
  Future<Recording> stop() async {
    if (stopDelay != null) await Future<void>.delayed(stopDelay!);
    _status.add(CaptureStatus.stopped);
    if (!_stopped.isCompleted) _stopped.complete();
    return Recording(path: path, duration: duration);
  }

  @override
  Future<String> recordingsDirectory() async => recordingsDir;

  @override
  Future<Duration?> probeRecording(String name) async => probe?.call(name);

  @override
  Future<void> setBackupExcluded(bool excluded) async {
    if (throwOnSetBackup) throw Exception('backup set failed');
    backupExcluded = excluded;
  }
}
