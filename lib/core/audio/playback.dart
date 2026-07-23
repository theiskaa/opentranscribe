import 'package:flutter/foundation.dart';

/// Where playback is in its lifecycle. [completed] is distinct from [stopped]: the
/// file played to its end on its own, versus being stopped by the user.
enum PlaybackStatus { playing, paused, stopped, completed }

/// A snapshot of playback: what it is doing, and where it is in the file.
@immutable
final class PlaybackState {
  const PlaybackState({required this.status, required this.position, required this.duration});

  /// Nothing is playing. The resting state before the first play and after a stop.
  static const idle = PlaybackState(
    status: PlaybackStatus.stopped,
    position: Duration.zero,
    duration: Duration.zero,
  );

  final PlaybackStatus status;
  final Duration position;
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is PlaybackState &&
      other.status == status &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(status, position, duration);
}

/// A playback failure (file unreadable, decode error, recording in progress). Kept
/// separate from the transcription exception taxonomy, which is about recognition,
/// not playback. [code] carries the native error code (e.g. busy_recording vs
/// playback_failed) so callers can branch without matching message text.
class PlaybackException implements Exception {
  const PlaybackException([this.message, this.code]);

  /// Native error codes, spelled once so callers never hardcode the wire string.
  static const busyRecording = 'busy_recording';
  static const playbackFailed = 'playback_failed';
  static const noPlayback = 'no_playback';

  final String? message;
  final String? code;

  @override
  String toString() => message == null ? 'PlaybackException' : 'PlaybackException: $message';
}
