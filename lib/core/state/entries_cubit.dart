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
  // Seeded from the service, not empty: the detail screen looks its entry up
  // here the moment it opens, and an empty seed would read as "deleted".
  EntriesCubit({required TranscriptionService service})
    : _service = service,
      super(EntriesState(entries: service.entries()));

  final TranscriptionService _service;

  void load() => emit(state.copyWith(entries: _service.entries()));

  /// Renames an entry (null or blank clears back to the date default). The
  /// service applies the title to the stored entry, so a racing re-transcribe
  /// cannot be clobbered.
  Future<void> rename(Entry entry, String? title) async {
    // Deliberately no busyId: a title commit must not flash the transcript
    // into a spinner, and it must not clear a running retranscribe's busy.
    try {
      await _service.renameEntry(entry, title);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    } finally {
      emit(state.copyWith(entries: _service.entries()));
    }
  }

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
