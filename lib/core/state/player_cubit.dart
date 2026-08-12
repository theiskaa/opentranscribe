import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:transcriber/transcriber.dart';

/// The speeds the player cycles through. Normal first, so one tap is the way
/// back to it from anywhere in the ring.
const List<double> playbackRates = [1, 1.25, 1.5, 2];

/// How finely a recording's shape is read; see [AudioPlayer.defaultPeakBuckets].
const int _peakBuckets = AudioPlayer.defaultPeakBuckets;

/// The transcript segment lit at [position]: the one whose span contains it,
/// else the latest segment already begun, so gaps between segments keep the
/// previous one lit instead of flickering to nothing. Null before the first
/// segment or when there are none.
int? activeSegmentIndex(List<TranscriptSegment> segments, Duration position) {
  int? latestBegun;
  for (final (i, segment) in segments.indexed) {
    if (segment.start > position) break;
    latestBegun = i;
    if (position < segment.end) return i;
  }
  return latestBegun;
}

/// What the player bar renders.
@immutable
final class PlayerState {
  const PlayerState({
    this.status = PlaybackStatus.stopped,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.peaks = const [],
    this.rate = 1,
    this.failed = false,
  });

  final PlaybackStatus status;
  final Duration position;
  final Duration duration;

  /// The recording's amplitude envelope, 0..1, read once from the file. Empty
  /// until it arrives, and empty for good if the file could not be read: the
  /// wave draws itself flat rather than inventing a shape.
  final List<double> peaks;

  /// Playback speed, one of [playbackRates].
  final double rate;

  /// A play/resume failed (recording live, unreadable file). Rendered as a
  /// quiet inline notice next to the controls; any later stream event (a
  /// successful play) rebuilds the state without it.
  final bool failed;

  bool get isPlaying => status == PlaybackStatus.playing;

  // Value equality, so a position tick that says nothing new rebuilds nothing.
  // The native side ticks 5x a second and the transcript is a whole paragraph
  // of spans; without this it re-laid-out on every one of them.
  @override
  bool operator ==(Object other) =>
      other is PlayerState &&
      other.status == status &&
      other.position == position &&
      other.duration == duration &&
      other.rate == rate &&
      other.failed == failed &&
      identical(other.peaks, peaks);

  @override
  int get hashCode => Object.hash(status, position, duration, rate, failed, peaks);

  PlayerState copyWith({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    List<double>? peaks,
    double? rate,
    bool? failed,
  }) => PlayerState(
    status: status ?? this.status,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    peaks: peaks ?? this.peaks,
    rate: rate ?? this.rate,
    failed: failed ?? this.failed,
  );
}

/// Drives playback of one entry's kept audio. Scoped to the detail screen: a
/// fresh cubit per visit, [stopAndDetach] on the way out, so playback never
/// outlives the screen and no state leaks across entries.
// ignore_for_file: prefer_initializing_formals
// The fields are private (a cubit owns its collaborators) and the constructor
// must call super(state), so initializing formals do not apply.
class PlayerCubit extends Cubit<PlayerState> {
  PlayerCubit({required AudioPlayer player, required TranscriptionService service})
    : _player = player,
      _service = service,
      super(const PlayerState()) {
    _sub = _player.state.listen((snapshot) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: snapshot.status,
          position: snapshot.position,
          duration: snapshot.duration,
          // A live snapshot supersedes a failure: any state at all means the
          // native side is answering again.
          failed: false,
        ),
      );
    }, onError: (Object _) {});
  }

  final AudioPlayer _player;
  final TranscriptionService _service;
  late final StreamSubscription<PlaybackState> _sub;
  bool _detached = false;

  /// The chosen speed. Held outside the state as well, because a fresh play has
  /// to re-apply it after the native player is rebuilt.
  double _rate = 1;

  /// Loads the entry's shape for the wave, once per screen. The persisted
  /// envelope answers instantly; only an entry from before peaks were stored
  /// pays a decode, and its result is written back so it pays exactly once.
  /// A failure is quiet: the wave stays flat and playback is unaffected,
  /// since reading a file and playing it are independent of each other.
  Future<void> loadPeaks(Entry entry, {int buckets = _peakBuckets}) async {
    if (state.peaks.isNotEmpty) return;
    final stored = entry.peaks;
    if (stored != null && stored.isNotEmpty) {
      emit(state.copyWith(peaks: [for (final v in stored) v / 255]));
      return;
    }
    try {
      final path = await _service.resolveAudioPath(entry);
      final peaks = await _player.peaks(path, buckets: buckets);
      if (isClosed || _detached) return;
      emit(state.copyWith(peaks: peaks));
      // Backfill the record so the next open skips the decode entirely.
      unawaited(_service.saveEntryPeaks(entry, peaks));
    } catch (_) {
      // Unreadable, missing, or a codec the decoder will not open. There is
      // nothing to say about it that the flat wave does not already say.
    }
  }

  /// One control for the one button: plays from the start when stopped or
  /// completed, pauses when playing, resumes when paused. A stale paused
  /// status (native completed or yielded meanwhile) falls back to a fresh
  /// play per the [AudioPlayer.resume] contract.
  Future<void> toggle(Entry entry) async {
    // Transcript-only entry: resolveAudioPath would throw StateError, which the
    // PlaybackException catch below does not cover. The UI hides the player for
    // these; this guard keeps a stale entry object from crashing the screen.
    if (!entry.hasAudio) return;
    try {
      switch (state.status) {
        case PlaybackStatus.playing:
          await _player.pause();
        case PlaybackStatus.paused:
          try {
            await _player.resume();
          } on PlaybackException catch (e) {
            if (e.code != PlaybackException.noPlayback) rethrow;
            await _playFresh(entry);
          }
        case PlaybackStatus.stopped || PlaybackStatus.completed:
          await _playFresh(entry);
      }
    } on PlaybackException {
      if (isClosed) return;
      emit(state.copyWith(failed: true));
    }
  }

  Future<void> _playFresh(Entry entry) async {
    final path = await _service.resolveAudioPath(entry);
    // The screen may have popped during the resolve; starting playback then
    // would orphan audio with no UI left to stop it.
    if (isClosed || _detached) return;
    // Where the wave was left. Scrubbing with nothing playing is a real
    // instruction - you chose a point and then pressed play - and play() starts
    // at zero, so the choice has to be re-applied on the other side of it. Not
    // from the very end, which is where a finished take rests: that reads as
    // replay, not resume.
    final from = state.position;
    final resume = from > Duration.zero && from < state.duration ? from : null;
    await _player.play(path);
    if (resume != null && !isClosed && !_detached) await _player.seek(resume);
    if (_rate != 1 && !isClosed && !_detached) await _player.setRate(_rate);
  }

  /// Seeks within the current file. [duration] lets the bar clamp against the
  /// entry's known length before the first play, when the stream has not
  /// reported one yet.
  Future<void> seek(Duration position, {Duration? duration}) async {
    final limit = state.duration == Duration.zero ? (duration ?? Duration.zero) : state.duration;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (limit > Duration.zero && position > limit ? limit : position);
    // Held on the state whatever the native side does with it. With nothing
    // loaded there is no player to move, and without this the wave would snap
    // back to where playback last was - so scrubbing a stopped entry would look
    // broken, and the position would be lost when play finally started.
    emit(state.copyWith(position: clamped, duration: limit > Duration.zero ? limit : null));
    try {
      await _player.seek(clamped);
    } on PlaybackException {
      // Seeking nothing is not worth a notice; the wave simply stays put.
    }
  }

  /// Steps to the next playback speed and applies it. The rate outlives a stop,
  /// so a take resumed or replayed keeps the speed it was being heard at.
  Future<void> cycleRate() async {
    final next = playbackRates[(playbackRates.indexOf(_rate) + 1) % playbackRates.length];
    _rate = next;
    emit(state.copyWith(rate: next));
    try {
      await _player.setRate(next);
    } on PlaybackException {
      // Nothing is loaded yet; the rate is remembered and applied on play.
    }
  }

  /// Silences playback for screen exit. Safe to call with nothing playing.
  Future<void> stopAndDetach() async {
    _detached = true;
    try {
      await _player.stop();
    } on PlaybackException {
      // Already silent.
    }
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
