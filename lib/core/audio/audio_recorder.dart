import 'package:opentranscribe/core/audio/recording.dart';

/// App-owned audio capture and custody of the files it writes. Produces a kept
/// file (via [Recording]) and a capture lifecycle stream, and owns where those
/// files live ([recordingsDirectory]) and whether they ride the device backup
/// ([setBackupExcluded]). It stays engine-agnostic: it knows nothing about any
/// transcription engine, only how to capture, write, and keep audio.
///
/// A streaming engine taps the same native capture session directly, so no audio
/// crosses into Dart.
abstract interface class AudioRecorder {
  /// Requests microphone permission if not already decided, and reports the result.
  Future<PermissionStatus> ensurePermission();

  /// Begins capture to a fresh file.
  Future<void> start();

  /// Suspends capture without ending it: the mic goes silent, the file stays
  /// open, and [stop] later seals one continuous recording. Throws when nothing
  /// is capturing or already paused.
  Future<void> pause();

  /// Resumes a paused capture into the same file. Throws when not paused; a
  /// failure leaves the capture paused, never half-running.
  Future<void> resume();

  /// Ends capture and deletes its audio: nothing is kept and nothing is
  /// returned. Quiet when nothing is capturing, so callers can cancel
  /// defensively.
  Future<void> cancel();

  /// Input level while capturing, normalized 0..1, around 20 Hz. Ephemeral: no
  /// replay, silent while paused or idle. Feeds a live waveform, never storage.
  Stream<double> get level;

  /// Capture lifecycle: recording, interruption, stopped. Contract for every
  /// implementation: past events are NOT replayed, but each new listener receives
  /// the current live state on subscribe (so a screen attaching mid-capture is not
  /// stale). Callers should subscribe before [start] to observe the whole session.
  Stream<CaptureStatus> get status;

  /// Finalizes the file and returns its reference and duration. The reference is
  /// a bare filename, stable across a backup/restore that would move the app's
  /// container; resolve it against [recordingsDirectory] to read the file.
  /// Throws only when no audio was captured at all, in which case no kept file
  /// remains behind; a throw never strands audio on disk.
  Future<Recording> stop();

  /// Absolute path of the durable directory where kept recordings live, used to
  /// resolve a stored filename to a full path for reading, deleting, or playback.
  Future<String> recordingsDirectory();

  /// Whether the kept file named [name] is a readable recording, and how long it
  /// runs; null when it cannot be opened (e.g. an unfinalized container after a
  /// mid-recording kill). Powers the orphan-reconciliation sweep.
  Future<Duration?> probeRecording(String name);

  /// Includes or excludes kept audio from the platform backup. Excluded by
  /// default, so nothing leaves the device until the user opts in.
  Future<void> setBackupExcluded(bool excluded);
}
