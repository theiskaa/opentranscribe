import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/retranscribe_runner.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';

/// What asking for a bulk run got. [locked] is a non-supporter's ask; the
/// surface answers with the support gate, mirroring BackupActionResult.
enum RetranscribeStart { started, locked }

/// The bulk re-transcribe surface's whole vocabulary: the runner's live
/// progress plus the idle preview (what a run would do right now).
@immutable
final class RetranscribeState {
  const RetranscribeState({
    this.progress = const RetranscribeProgress(),
    this.runnable = 0,
    this.current = 0,
  });

  final RetranscribeProgress progress;

  /// Entries a run would queue right now: kept audio the current engine has
  /// not heard. The idle face's "34 to re-transcribe".
  final int runnable;

  /// Entries already stamped by the current engine, the idle face's
  /// "178 already current". Transcript-only entries count in neither number:
  /// they cannot run and are not waiting to.
  final int current;

  bool get isRunning => progress.phase == RetranscribePhase.running;

  RetranscribeState copyWith({RetranscribeProgress? progress, int? runnable, int? current}) =>
      RetranscribeState(
        progress: progress ?? this.progress,
        runnable: runnable ?? this.runnable,
        current: current ?? this.current,
      );

  @override
  bool operator ==(Object other) =>
      other is RetranscribeState &&
      other.progress == progress &&
      other.runnable == runnable &&
      other.current == current;

  @override
  int get hashCode => Object.hash(progress, runnable, current);
}

/// Drives [TranscriptionService.retranscribeAll] for the sheet: preview,
/// start (supporter-gated), cancel, live progress. Root-scoped so a run
/// outlives the sheet that started it and any navigation over it.
class RetranscribeCubit extends Cubit<RetranscribeState> {
  RetranscribeCubit({required this._service, required this._isSupporter})
    : super(RetranscribeState(progress: _service.retranscribeAll.state)) {
    refresh();
    _progressSub = _service.retranscribeAll.stream.listen(_onProgress);
    // A delete, import, or single-entry landing while the sheet sits idle
    // must not leave stale preview counts. Mid-run landings are skipped:
    // each fires this too, and a whole-journal rescan per landing would only
    // restate what progress already says; the terminal refresh re-syncs once.
    _changesSub = _service.entriesChanged.listen((_) {
      if (!state.isRunning) refresh();
    }, onError: (Object _) {});
  }

  final TranscriptionService _service;
  final bool Function() _isSupporter;
  late final StreamSubscription<RetranscribeProgress> _progressSub;
  late final StreamSubscription<void> _changesSub;

  void _onProgress(RetranscribeProgress progress) {
    if (isClosed) return;
    emit(state.copyWith(progress: progress));
    // The one preview re-sync per run: mid-run entriesChanged refreshes are
    // deliberately skipped above.
    if (progress.phase == RetranscribePhase.done || progress.phase == RetranscribePhase.cancelled) {
      refresh();
    }
  }

  /// Recomputes the idle preview through the runner's own skip rule, so the
  /// preview and the queue can never disagree.
  void refresh() {
    if (isClosed) return;
    final runner = _service.retranscribeAll;
    var runnable = 0, current = 0;
    for (final entry in _service.entries()) {
      if (runner.runnable(entry)) {
        runnable++;
      } else if (entry.hasAudio) {
        current++;
      }
    }
    emit(state.copyWith(runnable: runnable, current: current));
  }

  /// Fires the run and lets the stream drive state; the answer says only
  /// whether it started. Club-gated: a free user's ask starts nothing, so no
  /// code path runs the bulk pass around the gate.
  RetranscribeStart start() {
    if (!_isSupporter()) return RetranscribeStart.locked;
    unawaited(_service.retranscribeAll.start());
    return RetranscribeStart.started;
  }

  void cancel() => _service.retranscribeAll.cancel();

  @override
  Future<void> close() async {
    await _progressSub.cancel();
    await _changesSub.cancel();
    return super.close();
  }
}
