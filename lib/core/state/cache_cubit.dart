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
/// action against it. Screen-scoped; a fresh screen re-measures on open.
class CacheCubit extends Cubit<CacheState> {
  CacheCubit({required this._service}) : super(const CacheState()) {
    unawaited(load());
  }

  final TranscriptionService _service;

  Future<void> load() async {
    final usage = await _service.audioUsage();
    if (isClosed) return;
    emit(state.copyWith(usage: usage));
  }

  /// Purges transcribed audio and re-measures. Quiet when nothing is
  /// reclaimable or a clear is already running.
  Future<void> clear() async {
    // A confirm can land after programmatic navigation tore the screen down.
    if (isClosed || state.clearing) return;
    emit(state.copyWith(clearing: true));
    try {
      await _service.purgeTranscribedAudio();
      final usage = await _service.audioUsage();
      if (isClosed) return;
      emit(CacheState(usage: usage));
    } catch (_) {
      // Best effort: the numbers on screen stay; a reopen re-measures.
      if (!isClosed) emit(state.copyWith(clearing: false));
    }
  }
}
