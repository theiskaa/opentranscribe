import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/transcription_service.dart';

@immutable
final class CacheState {
  const CacheState({this.usage, this.clearing = false});

  /// Null while the first sweep is still running; the screen shows a quiet
  /// placeholder rather than zeros that would read as "nothing stored".
  final AudioUsage? usage;

  /// True while a clear is purging and re-measuring, so the action can
  /// disable in place instead of double-firing.
  final bool clearing;

  CacheState copyWith({AudioUsage? usage, bool? clearing}) =>
      CacheState(usage: usage ?? this.usage, clearing: clearing ?? this.clearing);
}

/// Drives the Cache screen: what the kept recordings occupy and the one bulk
/// action against it. Screen-scoped; a fresh screen re-measures on open, and
/// store changes landing WHILE it is open (a detached discard, a delete
/// elsewhere) re-measure through [TranscriptionService.entriesChanged], so the
/// numbers the destructive confirm quotes stay honest.
class CacheCubit extends Cubit<CacheState> {
  CacheCubit({required this._service}) : super(const CacheState()) {
    _changesSub = _service.entriesChanged.listen((_) => load(), onError: (Object _) {});
    unawaited(load());
  }

  final TranscriptionService _service;
  late final StreamSubscription<void> _changesSub;

  /// Bumped by every measure, so a slow sweep started earlier can never land
  /// its stale numbers over a fresher emit (the post-clear zero especially).
  int _measureGeneration = 0;

  Future<void> load() async {
    final generation = ++_measureGeneration;
    try {
      final usage = await _service.audioUsage();
      if (isClosed || generation != _measureGeneration) return;
      emit(state.copyWith(usage: usage));
    } catch (e) {
      // A corrupt store must not reject into the zone at screen open; the
      // placeholder stays and a later change signal retries.
      if (kDebugMode) debugPrint('cache: usage sweep failed: $e');
    }
  }

  /// Purges transcribed audio and re-measures. Quiet when nothing is
  /// reclaimable or a clear is already running.
  Future<void> clear() async {
    if (isClosed || state.clearing) return;
    emit(state.copyWith(clearing: true));
    try {
      await _service.purgeTranscribedAudio();
      final generation = ++_measureGeneration;
      final usage = await _service.audioUsage();
      if (isClosed) return;
      if (generation != _measureGeneration) {
        // A newer measure owns the numbers; only release the button.
        emit(state.copyWith(clearing: false));
        return;
      }
      emit(CacheState(usage: usage));
    } catch (e) {
      // Best effort: the numbers on screen stay; a reopen re-measures.
      if (kDebugMode) debugPrint('cache: clear failed: $e');
      if (!isClosed) emit(state.copyWith(clearing: false));
    }
  }

  @override
  Future<void> close() async {
    await _changesSub.cancel();
    return super.close();
  }
}
