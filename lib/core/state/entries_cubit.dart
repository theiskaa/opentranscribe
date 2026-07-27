// ignore_for_file: prefer_initializing_formals
// Fields are private (a cubit owns its collaborators) and the constructor must
// call super(state), so initializing formals do not apply.

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

/// What went wrong with an entry action, as a kind the UI can word for the
/// user. Raw platform errors (NSError dumps) are debug-logged, never shown.
enum EntriesError {
  permissionDenied,
  onDeviceUnavailable,
  modelInstallFailed,
  reservationCap,
  generic,
}

/// One action's failure, pinned to the entry it happened to. Scoped so a
/// failed re-transcribe of one entry can never render as an error banner on
/// another entry's screen.
@immutable
final class EntriesFailure {
  const EntriesFailure({required this.entryId, required this.kind});

  final String entryId;
  final EntriesError kind;

  @override
  bool operator ==(Object other) =>
      other is EntriesFailure && other.entryId == entryId && other.kind == kind;

  @override
  int get hashCode => Object.hash(entryId, kind);
}

/// The journal list: loads entries, deletes them, and re-transcribes kept audio.
class EntriesState {
  const EntriesState({this.entries = const [], this.busyId, this.error});

  /// Newest first.
  final List<Entry> entries;

  /// Id of an entry with an in-flight action (re-transcribe/delete), for UI hints.
  final String? busyId;

  /// Last action failure, for the UI to surface ON ITS OWN ENTRY. Cleared on
  /// the next action or on dismiss.
  final EntriesFailure? error;

  /// The failure kind for [entryId], or null: the one lookup screens use, so
  /// none of them can accidentally render another entry's failure.
  EntriesError? errorFor(String entryId) => error?.entryId == entryId ? error!.kind : null;

  EntriesState copyWith({
    List<Entry>? entries,
    String? busyId,
    EntriesFailure? error,
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
      if (!isClosed) {
        emit(state.copyWith(error: EntriesFailure(entryId: entry.id, kind: _kind(e))));
      }
    } finally {
      if (!isClosed) emit(state.copyWith(entries: _service.entries()));
    }
  }

  Future<void> delete(Entry entry) async {
    emit(state.copyWith(busyId: entry.id));
    try {
      await _service.deleteEntry(entry);
    } catch (e) {
      // A delete that failed with the file still on disk kept the record (so the
      // recording is not resurrected by the reconcile sweep); the finally below
      // restores the row, and the user is told so they can retry.
      if (!isClosed) {
        emit(state.copyWith(error: EntriesFailure(entryId: entry.id, kind: _kind(e))));
      }
    } finally {
      if (!isClosed) emit(state.copyWith(entries: _service.entries(), clearBusy: true));
    }
  }

  /// Re-transcribes in the entry's own language by default; [localeId] is the
  /// user's explicit override (the Transcribe-in picker).
  Future<void> retranscribe(Entry entry, {String? localeId}) async {
    emit(state.copyWith(busyId: entry.id, clearError: true));
    EntriesFailure? failure;
    try {
      await _service.retranscribe(entry, localeId: localeId);
    } catch (e) {
      failure = EntriesFailure(entryId: entry.id, kind: _kind(e));
    }
    // A re-transcribe can run minutes; the screen may be gone by now.
    if (isClosed) return;
    // copyWith, never a fresh state: another entry's in-flight action owns
    // busyId by now if it claimed it after this one started.
    emit(
      failure == null
          ? state.copyWith(
              entries: _service.entries(),
              clearBusy: state.busyId == entry.id,
              clearError: true,
            )
          : state.copyWith(
              entries: _service.entries(),
              clearBusy: state.busyId == entry.id,
              error: failure,
            ),
    );
  }

  void clearError() => emit(state.copyWith(clearError: true));

  /// Folds a raw failure into the kind the UI words for the user; the raw error
  /// (often a native NSError dump) is only ever debug-logged.
  EntriesError _kind(Object error) {
    if (kDebugMode) debugPrint('entries: $error');
    return switch (error) {
      PermissionDenied() => EntriesError.permissionDenied,
      OnDeviceUnavailable() => EntriesError.onDeviceUnavailable,
      ModelInstallFailed() => EntriesError.modelInstallFailed,
      // Its own kind: the fix is removing a language, not checking the network.
      ReservationCapReached() => EntriesError.reservationCap,
      _ => EntriesError.generic,
    };
  }
}
