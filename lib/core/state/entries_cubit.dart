// ignore_for_file: prefer_initializing_formals
// Fields are private (a cubit owns its collaborators) and the constructor must
// call super(state), so initializing formals do not apply.

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';

/// The journal list: loads entries, deletes them, and re-transcribes kept audio.
class EntriesState {
  const EntriesState({this.entries = const [], this.busyId, this.error});

  /// Newest first.
  final List<Entry> entries;

  /// Id of an entry with an in-flight action (re-transcribe/delete), for UI hints.
  final String? busyId;

  /// Last action failure, for the UI to surface. Cleared on the next action.
  final String? error;

  EntriesState copyWith({
    List<Entry>? entries,
    String? busyId,
    String? error,
    bool clearBusy = false,
    bool clearError = false,
  }) => EntriesState(
    entries: entries ?? this.entries,
    busyId: clearBusy ? null : (busyId ?? this.busyId),
    error: clearError ? null : (error ?? this.error),
  );
}

class EntriesCubit extends Cubit<EntriesState> {
  EntriesCubit({required TranscriptionService service})
    : _service = service,
      super(const EntriesState());

  final TranscriptionService _service;

  void load() => emit(state.copyWith(entries: _service.entries()));

  Future<void> delete(Entry entry) async {
    emit(state.copyWith(busyId: entry.id));
    try {
      await _service.deleteEntry(entry);
    } finally {
      emit(state.copyWith(entries: _service.entries(), clearBusy: true));
    }
  }

  Future<void> retranscribe(Entry entry) async {
    emit(state.copyWith(busyId: entry.id, clearError: true));
    String? failure;
    try {
      await _service.retranscribe(entry);
    } catch (e) {
      failure = e.toString();
    }
    emit(EntriesState(entries: _service.entries(), error: failure));
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
