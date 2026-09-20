import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/transcription_service.dart';

/// The batch passes in flight: the one over a fresh take, and one per entry
/// being re-transcribed or continued. A pass leaves on its done event.
@immutable
final class BatchProgressState {
  const BatchProgressState({this.take, this.entries = const {}});

  final BatchProgress? take;
  final Map<String, BatchProgress> entries;

  /// The pass on [entryId], or null when none runs there.
  BatchProgress? forEntry(String entryId) => entries[entryId];

  @override
  bool operator ==(Object other) =>
      other is BatchProgressState && other.take == take && mapEquals(other.entries, entries);

  @override
  int get hashCode =>
      Object.hash(take, Object.hashAllUnordered(entries.entries.map((e) => (e.key, e.value))));
}

/// Mirrors [TranscriptionService.batchProgress] for the surfaces that wait on
/// a pass: the entry screen under its entry, home's bar under the take.
class BatchProgressCubit extends Cubit<BatchProgressState> {
  BatchProgressCubit({required TranscriptionService service}) : super(const BatchProgressState()) {
    _sub = service.batchProgress.listen(_onProgress, onError: (Object _) {});
  }

  late final StreamSubscription<BatchProgress> _sub;

  void _onProgress(BatchProgress event) {
    if (isClosed) return;
    final over = event.step == BatchStep.done;
    final id = event.entryId;
    if (id == null) {
      if (over && state.take == null) return;
      emit(BatchProgressState(take: over ? null : event, entries: state.entries));
      return;
    }
    final entries = Map.of(state.entries);
    if (over) {
      if (entries.remove(id) == null) return;
    } else {
      entries[id] = event;
    }
    emit(BatchProgressState(take: state.take, entries: Map.unmodifiable(entries)));
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
