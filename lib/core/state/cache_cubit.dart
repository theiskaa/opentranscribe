import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/transcription_service.dart';

@immutable
final class CacheState {
  const CacheState({this.usage, this.modelBytes, this.clearing = false, this.freedBytes});

  /// Null while the first sweep is still running; the screen shows a quiet
  /// placeholder rather than zeros that would read as "nothing stored".
  final AudioUsage? usage;

  /// What downloaded engine models hold, measured with [usage]; null until
  /// the first sweep lands.
  final int? modelBytes;

  /// True while a clear is purging and re-measuring, so the action can
  /// disable in place instead of double-firing.
  final bool clearing;

  /// What this screen's last clear freed, for the completion it shows; null
  /// until a clear lands. Kept through re-measures: the screen shows it only
  /// while nothing is reclaimable again.
  final int? freedBytes;

  CacheState copyWith({AudioUsage? usage, int? modelBytes, bool? clearing, int? freedBytes}) =>
      CacheState(
        usage: usage ?? this.usage,
        modelBytes: modelBytes ?? this.modelBytes,
        clearing: clearing ?? this.clearing,
        freedBytes: freedBytes ?? this.freedBytes,
      );
}

/// Drives the Cache screen: what the kept recordings occupy and the one bulk
/// action against it. Screen-scoped; a fresh screen re-measures on open, and
/// store changes landing WHILE it is open (a detached discard, a delete
/// elsewhere) re-measure through [TranscriptionService.entriesChanged],
/// coalesced to one trailing sweep once the signals quiet, so the numbers the
/// destructive confirm quotes converge on the stored truth.
class CacheCubit extends Cubit<CacheState> {
  CacheCubit({
    required this._service,
    Future<int> Function()? modelBytes,
    this._remeasureQuiet = const Duration(milliseconds: 300),
  }) : _modelBytes = modelBytes ?? _noModels,
       super(const CacheState()) {
    _changesSub = _service.entriesChanged.listen((_) {
      // Change signals arrive in bursts (each bulk re-transcribe landing, an
      // import's adoptions); one trailing sweep stats the files per burst.
      _remeasureTimer?.cancel();
      _remeasureTimer = Timer(_remeasureQuiet, () => unawaited(load()));
    }, onError: (Object _) {});
    unawaited(load());
  }

  final TranscriptionService _service;

  /// Measures downloaded engine models, injected from the composition root
  /// so this cubit never names an engine.
  final Future<int> Function() _modelBytes;

  static Future<int> _noModels() async => 0;

  /// The quiet a burst of change signals must hold before the sweep runs.
  final Duration _remeasureQuiet;
  late final StreamSubscription<void> _changesSub;
  Timer? _remeasureTimer;

  /// Bumped by every measure, so a slow sweep started earlier can never land
  /// its stale numbers over a fresher emit (the post-clear zero especially).
  int _measureGeneration = 0;

  Future<void> load() async {
    final generation = ++_measureGeneration;
    try {
      // A failed model measure zeroes its own row, never the recordings.
      final (usage, modelBytes) = await (
        _service.audioUsage(),
        _modelBytes().catchError((Object _) => 0),
      ).wait;
      if (isClosed || generation != _measureGeneration) return;
      emit(state.copyWith(usage: usage, modelBytes: modelBytes));
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
    final before = state.usage?.reclaimableBytes ?? 0;
    emit(state.copyWith(clearing: true));
    try {
      await _service.purgeTranscribedAudio();
      final generation = ++_measureGeneration;
      final usage = await _service.audioUsage();
      if (isClosed) return;
      // Measured, not counted by the purge, whose count is approximate.
      final freed = before - usage.reclaimableBytes;
      final freedBytes = freed > 0 ? freed : 0;
      if (generation != _measureGeneration) {
        // A newer measure owns the numbers; release the button and keep what
        // was freed.
        emit(state.copyWith(clearing: false, freedBytes: freedBytes));
        return;
      }
      emit(state.copyWith(usage: usage, clearing: false, freedBytes: freedBytes));
    } catch (e) {
      // Best effort: the numbers on screen stay; a reopen re-measures.
      if (kDebugMode) debugPrint('cache: clear failed: $e');
      if (!isClosed) emit(state.copyWith(clearing: false));
    }
  }

  @override
  Future<void> close() async {
    _remeasureTimer?.cancel();
    await _changesSub.cancel();
    return super.close();
  }
}
