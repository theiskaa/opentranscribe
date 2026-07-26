import 'package:opentranscribe/core/audio/playback.dart';

/// Plays a kept recording. Pure playback: it is handed an absolute file path and
/// knows nothing about entries or where audio is stored (resolution is the caller's
/// job), mirroring how [AudioRecorder] is pure capture. One playback at a time.
abstract interface class AudioPlayer {
  /// Starts playing the file at [path] from the beginning, replacing any current
  /// playback (the replaced playback emits no terminal state; the stream simply
  /// moves to the new file). Throws [PlaybackException] if the file cannot be
  /// opened, or if a recording is in progress (the two share the audio session).
  Future<void> play(String path);

  /// Pauses the current playback, holding position.
  Future<void> pause();

  /// Resumes a paused playback. Throws [PlaybackException] with code
  /// [PlaybackException.noPlayback] when nothing is paused (completed, stopped, or
  /// yielded to a recording), so the caller can fall back to [play], and with
  /// [PlaybackException.busyRecording] while a recording is live.
  Future<void> resume();

  /// Jumps to [position] in the current file.
  Future<void> seek(Duration position);

  /// Stops playback and releases the file.
  Future<void> stop();

  /// Playback state: periodic position ticks while playing, plus every transition
  /// (play, pause, seek, stop, and completion when the file plays to its end).
  Stream<PlaybackState> get state;

  /// Sets the playback speed, 1 being normal. Applies to the current playback
  /// and to the next one: every play builds a fresh native player, so the rate
  /// is the player's, not one playback's.
  Future<void> setRate(double rate);

  /// The master resolution an entry's shape is read (and persisted) at.
  /// Generous enough that any bar count a phone can show resamples DOWN from
  /// it, so layout never drives a native read.
  static const int defaultPeakBuckets = 320;

  /// The amplitude envelope of the file at [path]: [buckets] values in 0..1, one
  /// per equal slice of the recording, each the loudest sample in its slice.
  /// Normalized against the file's own loudest sample, so the shape says where
  /// the sound is and not how close the microphone was.
  ///
  /// Independent of playback: reading a file's shape does not touch the audio
  /// session, so it works while something else is playing and while nothing is.
  /// Throws [PlaybackException] when the file cannot be read.
  Future<List<double>> peaks(String path, {int buckets});
}
