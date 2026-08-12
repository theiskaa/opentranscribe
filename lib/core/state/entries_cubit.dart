// ignore_for_file: prefer_initializing_formals
// Fields are private (a cubit owns its collaborators) and the constructor must
// call super(state), so initializing formals do not apply.

import 'dart:async';

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

/// The in-flight action's kind. The transcript view dissolves into its shimmer
/// only for a transcribe; a delete must not run it on the way out.
enum EntriesAction { transcribe, delete }

/// The journal list: loads entries, deletes them, and re-transcribes kept audio.
class EntriesState {
  const EntriesState({
    this.entries = const [],
    this.busyId,
    this.busyAction,
    this.error,
    this.errorTick = 0,
  });

  /// Newest first.
  final List<Entry> entries;

  /// Id of an entry with an in-flight action (re-transcribe/delete), for UI
  /// hints; [busyAction] says which action it is.
  final String? busyId;
  final EntriesAction? busyAction;

  /// Last action failure, for the UI to surface ON ITS OWN ENTRY. Cleared
  /// when a retry succeeds; a retry in flight keeps it standing, so the
  /// failure surface never blinks away just to come back.
  final EntriesFailure? error;

  /// Bumped with every failure landing, so a surface can re-announce a repeat
  /// of the same error rather than sit still.
  final int errorTick;

  /// The failure kind for [entryId], or null: the one lookup screens use, so
  /// none of them can accidentally render another entry's failure.
  EntriesError? errorFor(String entryId) => error?.entryId == entryId ? error!.kind : null;

  EntriesState copyWith({
    List<Entry>? entries,
    String? busyId,
    EntriesAction? busyAction,
    EntriesFailure? error,
    int? errorTick,
    bool clearBusy = false,
    bool clearError = false,
  }) => EntriesState(
    entries: entries ?? this.entries,
    busyId: clearBusy ? null : (busyId ?? this.busyId),
    busyAction: clearBusy ? null : (busyAction ?? this.busyAction),
    error: clearError ? null : (error ?? this.error),
    errorTick: errorTick ?? this.errorTick,
  );
}

class EntriesCubit extends Cubit<EntriesState> {
  // Seeded from the service, not empty: the detail screen looks its entry up
  // here the moment it opens, and an empty seed would read as "deleted".
  EntriesCubit({required TranscriptionService service})
    : _service = service,
      super(EntriesState(entries: service.entries())) {
    // A detached discard (keep-audio off) nulls an entry's audio behind the
    // scenes; without this, an open detail screen keeps offering the player
    // and re-transcribe for a file that no longer exists.
    _changesSub = _service.entriesChanged.listen((_) => load(), onError: (Object _) {});
  }

  final TranscriptionService _service;
  late final StreamSubscription<void> _changesSub;

  void load() {
    if (isClosed) return;
    emit(state.copyWith(entries: _service.entries()));
  }

  /// Renames an entry (null or blank clears back to the date default). The
  /// service applies the title to the stored entry, so a racing re-transcribe
  /// cannot be clobbered.
  Future<void> rename(Entry entry, String? title) async {
    // Deliberately no busyId: a title commit must not flash the transcript
    // into a spinner, and it must not clear a running retranscribe's busy.
    try {
      await _service.renameEntry(entry, title);
    } catch (e) {
      if (!isClosed) emit(_withFailure(entry, e));
    } finally {
      if (!isClosed) emit(state.copyWith(entries: _service.entries()));
    }
  }

  /// Applies a hand edit of the transcript text, pushed onto the entry's
  /// history (blank or unchanged writes nothing). The service applies it to
  /// the stored entry, so a racing re-transcribe cannot be clobbered.
  Future<void> edit(Entry entry, String text) async {
    // Deliberately no busyId, like rename: a text commit must not dissolve the
    // transcript into the shimmer, and it must not clear a running
    // retranscribe's busy.
    try {
      await _service.editTranscript(entry, text);
    } catch (e) {
      if (!isClosed) emit(_withFailure(entry, e));
    } finally {
      if (!isClosed) emit(state.copyWith(entries: _service.entries()));
    }
  }

  /// Restores [revision] as the entry's new head (a pushed copy; history only
  /// grows). Same shape as [edit] for the same reasons.
  Future<void> restore(Entry entry, Revision revision) async {
    try {
      await _service.restoreRevision(entry, revision);
    } catch (e) {
      if (!isClosed) emit(_withFailure(entry, e));
    } finally {
      if (!isClosed) emit(state.copyWith(entries: _service.entries()));
    }
  }

  /// Removes [revision] from the entry's history for good. Same shape as
  /// [edit] for the same reasons.
  Future<void> deleteRevision(Entry entry, Revision revision) async {
    try {
      await _service.deleteRevision(entry, revision);
    } catch (e) {
      if (!isClosed) emit(_withFailure(entry, e));
    } finally {
      if (!isClosed) emit(state.copyWith(entries: _service.entries()));
    }
  }

  Future<void> delete(Entry entry) async {
    emit(state.copyWith(busyId: entry.id, busyAction: EntriesAction.delete));
    try {
      await _service.deleteEntry(entry);
    } catch (e) {
      // A delete that failed with the file still on disk kept the record (so the
      // recording is not resurrected by the reconcile sweep); the finally below
      // restores the row, and the user is told so they can retry.
      if (!isClosed) emit(_withFailure(entry, e));
    } finally {
      if (!isClosed) emit(state.copyWith(entries: _service.entries(), clearBusy: true));
    }
  }

  /// Re-transcribes in the entry's own language by default; [localeId] is the
  /// user's explicit override (the Transcribe-in picker). The landing pushes
  /// the replaced words into the entry's history.
  Future<void> retranscribe(Entry entry, {String? localeId}) async {
    // The pill and its sheet stay tappable through a retry; a second run on
    // the same entry would double-transcribe and confuse the one busy slot.
    if (state.busyId == entry.id) return;
    emit(state.copyWith(busyId: entry.id, busyAction: EntriesAction.transcribe));
    Object? failure;
    try {
      await _service.retranscribe(entry, localeId: localeId);
    } catch (e) {
      failure = e;
    }
    // A re-transcribe can run minutes; the screen may be gone by now.
    if (isClosed) return;
    // copyWith, never a fresh state: another entry's in-flight action owns
    // busyId by now if it claimed it after this one started.
    final clearBusy = state.busyId == entry.id;
    emit(
      failure == null
          ? state.copyWith(entries: _service.entries(), clearBusy: clearBusy, clearError: true)
          : _withFailure(
              entry,
              failure,
            ).copyWith(entries: _service.entries(), clearBusy: clearBusy),
    );
  }

  /// One failure landing: the error pinned to its entry plus the tick bump
  /// that lets a surface re-announce a repeat of the same failure.
  EntriesState _withFailure(Entry entry, Object e) => state.copyWith(
    error: EntriesFailure(entryId: entry.id, kind: _kind(e)),
    errorTick: state.errorTick + 1,
  );

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

  @override
  Future<void> close() async {
    await _changesSub.cancel();
    return super.close();
  }
}
