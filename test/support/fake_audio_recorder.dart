import 'dart:async';
import 'package:transcriber/transcriber.dart';

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
    this.throwOnEnsurePermission = false,
    this.throwOnStart = false,
    this.throwOnPause = false,
    this.throwOnResume = false,
    this.resumeRouteChanged = false,
    this.stopDelay,
    this.startDelay,
    this.pauseGate,
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

  /// When true, [ensurePermission] throws, modeling a channel error.
  final bool throwOnEnsurePermission;

  /// When true, [start] throws, to exercise failed-start cleanup paths. Mutable
  /// so a test can fail the SECOND start after a successful first.
  bool throwOnStart;

  /// Answers [probeRecording] per name; null (the default) probes nothing readable.
  final Duration? Function(String name)? probe;

  /// When true, [pause] / [resume] throw, to exercise failure paths.
  final bool throwOnPause;
  final bool throwOnResume;

  /// When true, [resume] tears the session down, emits `interrupted` on
  /// [status], then throws - modeling AudioCapture.swift's resume() finding a
  /// route change: teardown, `onStatus?("interrupted")`, then `throw
  /// CaptureError.routeChanged`, all before the Dart await settles.
  final bool resumeRouteChanged;

  /// Awaited inside [pause] before it does anything else, so a test can hold a
  /// pause round trip open (gate not yet completed) while it lands a
  /// concurrent stop, then release it to see how the delayed pause resolves.
  final Future<void>? pauseGate;

  /// The last value passed to [setBackupExcluded], for assertions.
  bool? backupExcluded;

  /// True after [cancel] ran on a live capture, for assertions that the audio
  /// was discarded rather than kept.
  bool cancelled = false;

  /// Whether the fake capture is currently paused, for assertions.
  bool paused = false;

  /// Push values here to feed [level] in tests.
  final StreamController<double> levelController = StreamController<double>.broadcast();

  final StreamController<CaptureStatus> _status = StreamController<CaptureStatus>.broadcast();
  final Completer<void> _stopped = Completer<void>();
  bool _capturing = false;

  /// Completes when [stop] is called. Wire this into a FakeStreamingEngine's
  /// stopSignal so its final event lands when capture stops.
  Future<void> get stopped => _stopped.future;

  @override
  Future<PermissionStatus> ensurePermission() async {
    if (throwOnEnsurePermission) throw const CaptureFailed('fake permission failure');
    return permission;
  }

  @override
  Stream<CaptureStatus> get status => _status.stream;

  /// Delays [start]'s completion, so a test can interleave an interruption with
  /// an in-flight start.
  final Duration? startDelay;

  @override
  Stream<double> get level => levelController.stream;

  @override
  Future<void> start() async {
    if (throwOnStart) throw const CaptureFailed('fake start failure');
    if (startDelay != null) await Future<void>.delayed(startDelay!);
    _capturing = true;
    paused = false;
    _status.add(CaptureStatus.recording);
  }

  @override
  Future<void> pause() async {
    // Snapshotted before the gate: a concurrent stop landing while this call is
    // held open must not retroactively change what this ALREADY-ISSUED call
    // sees, mirroring a native call whose checks ran before the race.
    final wasCapturing = _capturing;
    final wasPaused = paused;
    if (pauseGate != null) await pauseGate;
    if (throwOnPause) throw const CaptureFailed('fake pause failure', 'capture_failed');
    if (!wasCapturing) throw const CaptureFailed('not recording', 'not_running');
    if (wasPaused) throw const CaptureFailed('already paused', 'already_paused');
    paused = true;
    _status.add(CaptureStatus.paused);
  }

  @override
  Future<void> resume() async {
    if (throwOnResume) throw const CaptureFailed('fake resume failure', 'capture_failed');
    if (!_capturing || !paused) throw const CaptureFailed('not paused', 'not_paused');
    if (resumeRouteChanged) {
      _capturing = false;
      paused = false;
      _status.add(CaptureStatus.interrupted);
      // Let the status listener run (and flip the service's own bookkeeping)
      // before this call fails, matching the native ordering: teardown and the
      // status emit happen before the throw.
      await Future<void>.delayed(Duration.zero);
      throw const CaptureFailed('fake route changed', 'route_changed');
    }
    paused = false;
    _status.add(CaptureStatus.recording);
  }

  @override
  Future<void> cancel() async {
    if (!_capturing) return;
    _capturing = false;
    paused = false;
    cancelled = true;
    _status.add(CaptureStatus.stopped);
  }

  /// Simulates a native interruption (a phone call), so a test can exercise the
  /// service's auto-finalize. [stop] still returns a [Recording] afterward.
  void interrupt() {
    _capturing = false;
    paused = false;
    _status.add(CaptureStatus.interrupted);
  }

  @override
  Future<Recording> stop() async {
    if (stopDelay != null) await Future<void>.delayed(stopDelay!);
    _capturing = false;
    paused = false;
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

  /// Closes the fake's controllers. Optional: tests that leak a broadcast
  /// controller do not hang, but tidy tests can call this.
  Future<void> dispose() async {
    await _status.close();
    await levelController.close();
  }
}
