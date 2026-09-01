import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/share_export.dart';
import 'package:opentranscribe/core/export/stored_zip.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/services/backup_settings.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';

/// Which one-at-a-time backup operation is running; every action row
/// disables together while any is.
enum BackupBusy { none, exporting, archiving, importing }

/// How an export action ended. Cancel is a quiet outcome (the user closed
/// the share sheet, nothing to explain); the failed values earn a failure
/// sheet, the specific two naming their cause.
enum BackupActionResult { shared, cancelled, failed, failedTooLarge, failedNoSpace }

/// POSIX ENOSPC; iOS is the only shipped platform.
const _enospc = 28;

/// The one reading of a share escape, for every export surface: a share that
/// never presented (sheet busy, unavailable) is a quiet cancel, because a
/// sheet claiming the export broke would be a lie; the two failures a user
/// can act on keep their cause; anything else is the generic failure.
BackupActionResult shareFailureResult(Object error) {
  if (error is ShareExportException &&
      (error.code == ShareExportException.busy || error.code == ShareExportException.unavailable)) {
    return BackupActionResult.cancelled;
  }
  if (error is StoredZipException && error.error == StoredZipError.tooLarge) {
    return BackupActionResult.failedTooLarge;
  }
  if (error is FileSystemException && error.osError?.errorCode == _enospc) {
    return BackupActionResult.failedNoSpace;
  }
  return BackupActionResult.failed;
}

/// What a finished import attempt means for the flow: show the summary, ask
/// for the passphrase again, or fail with which copy. The one mapping from
/// [ArchiveError] to a next step, pure so the choreography is testable.
enum ImportResolution {
  success,
  retryPassphrase,
  failedNewerVersion,
  failedRezipped,
  failed,

  /// Adoption was already writing when something broke: unlike every other
  /// failure, the journal HAS changed, and the copy must not deny it.
  failedMidway,
}

ImportResolution importResolutionOf(ArchiveError error) => switch (error) {
  ArchiveError.cannotDecrypt => ImportResolution.retryPassphrase,
  ArchiveError.unsupportedVersion => ImportResolution.failedNewerVersion,
  ArchiveError.unsupportedZip => ImportResolution.failedRezipped,
  ArchiveError.malformed => ImportResolution.failed,
};

/// One import attempt's outcome for the screen: [resolution] drives the next
/// sheet, [summary] is present only on success.
@immutable
final class ImportOutcome {
  const ImportOutcome.success(ImportSummary this.summary) : resolution = ImportResolution.success;

  ImportOutcome.failure(ArchiveError error)
    : resolution = importResolutionOf(error),
      summary = null;

  const ImportOutcome.midway() : resolution = ImportResolution.failedMidway, summary = null;

  /// An import that broke before adoption wrote anything: the plain failure
  /// resolution, never the midway one.
  const ImportOutcome.aborted() : resolution = ImportResolution.failed, summary = null;

  final ImportResolution resolution;
  final ImportSummary? summary;
}

@immutable
final class BackupState {
  const BackupState({
    this.measure,
    this.formatId = '',
    this.seal = true,
    this.lastArchiveAt,
    this.busy = BackupBusy.none,
  });

  /// Null until the first measure lands; the intro reads generic until then.
  final JournalMeasure? measure;
  final String formatId;
  final bool seal;
  final DateTime? lastArchiveAt;
  final BackupBusy busy;

  bool get isBusy => busy != BackupBusy.none;

  BackupState copyWith({
    JournalMeasure? measure,
    String? formatId,
    bool? seal,
    DateTime? lastArchiveAt,
    BackupBusy? busy,
  }) => BackupState(
    measure: measure ?? this.measure,
    formatId: formatId ?? this.formatId,
    seal: seal ?? this.seal,
    lastArchiveAt: lastArchiveAt ?? this.lastArchiveAt,
    busy: busy ?? this.busy,
  );

  @override
  bool operator ==(Object other) =>
      other is BackupState &&
      other.measure == measure &&
      other.formatId == formatId &&
      other.seal == seal &&
      other.lastArchiveAt == lastArchiveAt &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(measure, formatId, seal, lastArchiveAt, busy);
}

/// Drives the Backup screen: measures the entry count, holds the persisted
/// choices, and runs the one-at-a-time export, archive and import actions.
/// Cubit methods return one-shot outcomes while [BackupState.busy] gates the
/// rows; the sheet choreography lives in the screen. Never rethrows: an
/// export answers an outcome, an import answers a failure outcome.
class BackupCubit extends Cubit<BackupState> {
  BackupCubit({
    required this._service,
    required this._export,
    required this._import,
    required this._settings,
    required this._descriptors,
    DateTime Function()? clock,
    this._remeasureQuiet = const Duration(milliseconds: 300),
  }) : _clock = clock ?? DateTime.now,
       super(const BackupState()) {
    _entriesSub = _service.entriesChanged.listen((_) {
      // Change signals arrive in bursts (each bulk re-transcribe landing, an
      // import's adoptions); one trailing walk stats the files per burst.
      _remeasureTimer?.cancel();
      _remeasureTimer = Timer(_remeasureQuiet, () => unawaited(_measure()));
    });
  }

  final TranscriptionService _service;
  final ExportService _export;
  final ImportService _import;
  final BackupSettings _settings;
  final List<ExporterDescriptor> _descriptors;
  final DateTime Function() _clock;

  late final StreamSubscription<void> _entriesSub;

  /// The quiet a burst of change signals must hold before the walk runs.
  final Duration _remeasureQuiet;
  Timer? _remeasureTimer;

  /// Bumped by every measure, so a slow file walk started earlier can never
  /// land its stale numbers over a fresher emit.
  int _measureGeneration = 0;

  /// The formats this build ships, in the order the picker lists them.
  List<ExporterDescriptor> get descriptors => _descriptors;

  /// The stored format id is resolved against the shipped descriptors HERE,
  /// so a stale id from a build that dropped its exporter can never leak
  /// into an export call.
  Future<void> load() async {
    emit(
      state.copyWith(
        formatId: resolveFormatId(_settings.formatId, _descriptors),
        seal: _settings.seal,
        lastArchiveAt: _settings.lastArchiveAt,
      ),
    );
    await _measure();
  }

  Future<void> _measure() async {
    final generation = ++_measureGeneration;
    try {
      final measure = await _export.measure();
      if (isClosed || generation != _measureGeneration) return;
      emit(state.copyWith(measure: measure));
    } catch (e) {
      // Best effort: the intro reads generic; a later change signal retries.
      if (kDebugMode) debugPrint('BackupCubit.measure failed: $e');
    }
  }

  Future<void> setFormat(String id) async {
    emit(state.copyWith(formatId: id));
    await _settings.setFormatId(id);
  }

  Future<void> setSeal(bool seal) async {
    emit(state.copyWith(seal: seal));
    await _settings.setSeal(seal);
  }

  Future<BackupActionResult> exportJournal({
    required ExportStrings strings,
    required String exporterId,
    required bool includeAudio,
  }) => _run(
    BackupBusy.exporting,
    () =>
        _export.shareJournal(exporterId: exporterId, includeAudio: includeAudio, strings: strings),
  );

  Future<BackupActionResult> exportArchive({String? passphrase}) =>
      _run(BackupBusy.archiving, () async {
        final shared = await _export.shareArchive(passphrase: passphrase);
        if (shared) {
          // Persisted even after close: the share sheet outlives the screen,
          // and a backup that finished is a backup that happened.
          final now = _clock();
          try {
            await _settings.setLastArchiveAt(now);
            if (!isClosed) emit(state.copyWith(lastArchiveAt: now));
          } catch (e) {
            // The share DID happen: losing the bookkeeping must not be
            // reported as an export that failed.
            if (kDebugMode) debugPrint('BackupCubit.archive date: $e');
          }
        }
        return shared;
      });

  Future<String?> pickArchive() async {
    try {
      return await _import.pickArchive();
    } on ShareExportException catch (e) {
      if (kDebugMode) debugPrint('BackupCubit.pick failed: $e');
      return null;
    }
  }

  Future<void> discardPicked(String path) => _import.discardPicked(path);

  Future<ImportProbe?> probeArchive(String path) async {
    try {
      return await _import.probe(path);
    } catch (e) {
      if (kDebugMode) debugPrint('BackupCubit.probe failed: $e');
      return null;
    }
  }

  /// Null when another operation is already running: a double-tap earns
  /// silence, never a wrong failure sheet.
  Future<ImportOutcome?> importArchive(String path, {String? passphrase}) async {
    if (state.isBusy) return null;
    emit(state.copyWith(busy: BackupBusy.importing));
    try {
      final summary = await _import.importArchive(path, passphrase: passphrase);
      return ImportOutcome.success(summary);
    } on ArchiveException catch (e) {
      return ImportOutcome.failure(e.error);
    } on ArgumentError {
      return ImportOutcome.failure(ArchiveError.malformed);
    } on ImportAbortedException catch (e) {
      // Broke before adoption wrote anything: a plain failure, whose copy
      // rightly says the journal was not touched.
      if (kDebugMode) debugPrint('BackupCubit.import aborted: $e');
      return const ImportOutcome.aborted();
    } catch (e) {
      // Anything else escaped past staging, i.e. adoption was writing.
      if (kDebugMode) debugPrint('BackupCubit.import failed: $e');
      return const ImportOutcome.midway();
    } finally {
      if (!isClosed) emit(state.copyWith(busy: BackupBusy.none));
    }
  }

  Future<BackupActionResult> _run(BackupBusy busy, Future<bool> Function() op) async {
    if (state.isBusy) return BackupActionResult.cancelled;
    emit(state.copyWith(busy: busy));
    try {
      return await op() ? BackupActionResult.shared : BackupActionResult.cancelled;
    } catch (e) {
      final result = shareFailureResult(e);
      if (kDebugMode && result != BackupActionResult.cancelled) {
        debugPrint('BackupCubit.${busy.name} failed: $e');
      }
      return result;
    } finally {
      if (!isClosed) emit(state.copyWith(busy: BackupBusy.none));
    }
  }

  @override
  Future<void> close() {
    _remeasureTimer?.cancel();
    _entriesSub.cancel();
    return super.close();
  }
}
