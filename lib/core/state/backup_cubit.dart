import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/share_export.dart';
import 'package:opentranscribe/core/export/stored_zip.dart';
import 'package:opentranscribe/core/export/zip_pack.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/services/backup_settings.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_merge.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/utils/percent.dart';

/// Which share is running, a backup or an export; every action row disables
/// together while either is. A restore runs as [BackupState.restore].
enum BackupBusy { none, exporting, archiving }

/// Where a running backup or export stands: [packing] the files, [sealing]
/// the archive under its passphrase, then [sharing], where the share sheet
/// waits on the user and nothing is left to do or cancel.
enum BackupPhase { packing, sealing, sharing }

/// How an export action ended. Cancel is a quiet outcome (the user closed
/// the share sheet, nothing to explain); the failed values are told where
/// the export ran, the specific two naming their cause.
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
  if (error is ZipPackAborted) return BackupActionResult.cancelled;
  if (error is StoredZipException && error.error == StoredZipError.tooLarge) {
    return BackupActionResult.failedTooLarge;
  }
  if (error is FileSystemException && error.osError?.errorCode == _enospc) {
    return BackupActionResult.failedNoSpace;
  }
  return BackupActionResult.failed;
}

/// Where an in-place restore stands. The screen renders it; the cubit owns
/// every transition and the staged archive behind it.
@immutable
sealed class RestoreFlow {
  const RestoreFlow();

  /// Picking, checking or running: the step cannot be called off, and no
  /// other restore step starts.
  bool get inFlight => false;

  /// From the pick until it is done, failed or let go: every other operation
  /// waits it out.
  bool get underWay => true;

  /// Done or failed: only a told result is left, nothing staged, and the
  /// next operation lets it go.
  bool get held => false;
}

/// No restore under way.
final class RestoreIdle extends RestoreFlow {
  const RestoreIdle();

  @override
  bool get underWay => false;

  @override
  bool operator ==(Object other) => other is RestoreIdle;

  @override
  int get hashCode => (RestoreIdle).hashCode;
}

/// The document picker is up, or the picked file is being probed.
final class RestorePicking extends RestoreFlow {
  const RestorePicking();

  @override
  bool get inFlight => true;

  @override
  bool operator ==(Object other) => other is RestorePicking;

  @override
  int get hashCode => (RestorePicking).hashCode;
}

/// A sealed archive waits for its passphrase. [attempt] counts the
/// passphrases that did not open it, so each miss is a state of its own.
final class RestoreProbed extends RestoreFlow {
  const RestoreProbed(this.probe, {this.attempt = 0});

  final ImportProbe probe;
  final int attempt;

  @override
  bool operator ==(Object other) =>
      other is RestoreProbed && other.probe == probe && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(probe, attempt);
}

/// Unlocking and parsing the picked file; nothing in the journal changes.
final class RestoreChecking extends RestoreFlow {
  const RestoreChecking(this.probe);

  final ImportProbe probe;

  @override
  bool get inFlight => true;

  @override
  bool operator ==(Object other) => other is RestoreChecking && other.probe == probe;

  @override
  int get hashCode => probe.hashCode;
}

/// Staged and planned, waiting for the user's go-ahead.
final class RestorePlanned extends RestoreFlow {
  const RestorePlanned(this.probe, this.plan);

  final ImportProbe probe;
  final ImportPlan plan;

  @override
  bool operator ==(Object other) =>
      other is RestorePlanned && other.probe == probe && other.plan == plan;

  @override
  int get hashCode => Object.hash(probe, plan);
}

/// Adoption is writing into the journal; [progress] is 0..1 in whole
/// percents of the entries, null through the grace unless a whole percent
/// lands first, so a quick restore never flashes 0%.
final class RestoreRunning extends RestoreFlow {
  const RestoreRunning(this.probe, this.plan, {this.progress});

  final ImportProbe probe;
  final ImportPlan plan;
  final double? progress;

  @override
  bool get inFlight => true;

  @override
  bool operator ==(Object other) =>
      other is RestoreRunning &&
      other.probe == probe &&
      other.plan == plan &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(probe, plan, progress);
}

/// Adoption finished; [summary] is what it did.
final class RestoreDone extends RestoreFlow {
  const RestoreDone(this.probe, this.summary);

  final ImportProbe probe;
  final ImportSummary summary;

  @override
  bool get underWay => false;

  @override
  bool get held => true;

  @override
  bool operator ==(Object other) =>
      other is RestoreDone && other.probe == probe && other.summary == summary;

  @override
  int get hashCode => Object.hash(probe, summary);
}

/// Adoption broke midway, so the journal holds [restored] of the archive.
/// The staged data is kept for [BackupCubit.adoptRestore] to run again.
final class RestorePartial extends RestoreFlow {
  const RestorePartial(this.probe, this.plan, this.restored, {this.reflectionsLeft = false});

  final ImportProbe probe;
  final ImportPlan plan;
  final ImportSummary restored;

  /// Every entry had been through adoption when it broke: only the
  /// reflections are left.
  final bool reflectionsLeft;

  @override
  bool operator ==(Object other) =>
      other is RestorePartial &&
      other.probe == probe &&
      other.plan == plan &&
      other.restored == restored &&
      other.reflectionsLeft == reflectionsLeft;

  @override
  int get hashCode => Object.hash(probe, plan, restored, reflectionsLeft);
}

/// The restore stopped before adoption wrote anything. [probe] is null when
/// the picked file could not even be probed.
final class RestoreFailed extends RestoreFlow {
  const RestoreFailed(this.failure, {this.probe});

  final RestoreFailure failure;
  final ImportProbe? probe;

  @override
  bool get underWay => false;

  @override
  bool get held => true;

  @override
  bool operator ==(Object other) =>
      other is RestoreFailed && other.failure == failure && other.probe == probe;

  @override
  int get hashCode => Object.hash(failure, probe);
}

/// Why a restore stopped before adoption wrote anything.
enum RestoreFailure { damaged, newerVersion, rezipped, noSpace }

RestoreFailure restoreFailureOf(ArchiveError error) => switch (error) {
  ArchiveError.unsupportedVersion => RestoreFailure.newerVersion,
  ArchiveError.unsupportedZip => RestoreFailure.rezipped,
  ArchiveError.cannotDecrypt || ArchiveError.malformed => RestoreFailure.damaged,
};

/// The one reading of what stopped a restore before adoption: an archive's
/// own error by [restoreFailureOf], a full disk as its own failure since the
/// way out is freeing space, anything else as damaged.
RestoreFailure restoreFailureOfError(Object error) => switch (error) {
  ArchiveException(:final error) => restoreFailureOf(error),
  FileSystemException(osError: OSError(errorCode: _enospc)) => RestoreFailure.noSpace,
  _ => RestoreFailure.damaged,
};

@immutable
final class BackupState {
  const BackupState({
    this.measure,
    this.seal = true,
    this.lastArchiveAt,
    this.busy = BackupBusy.none,
    this.progress,
    this.phase,
    this.exportingId,
    this.restore = const RestoreIdle(),
  });

  /// Null until the first measure lands; the card reads its counts as
  /// unknown until then.
  final JournalMeasure? measure;
  final bool seal;
  final DateTime? lastArchiveAt;
  final BackupBusy busy;

  /// How far the running share's pack has come, 0..1; null through the grace
  /// and once [phase] leaves packing, which is also when there is nothing
  /// left to cancel.
  final double? progress;

  /// The running backup's or export's step; null while neither runs.
  final BackupPhase? phase;

  /// The exporter a running journal export writes; null while none runs.
  final String? exportingId;

  final RestoreFlow restore;

  bool get isBusy => busy != BackupBusy.none;

  /// How many entries were created after the last backup; null when there
  /// never was one, and until a measure against that backup lands.
  int? get newSinceBackup => switch ((lastArchiveAt, measure)) {
    (final at?, JournalMeasure(:final since?, :final newSince)) when since.isAtSameMomentAs(at) =>
      newSince,
    _ => null,
  };

  BackupState copyWith({
    JournalMeasure? measure,
    bool? seal,
    DateTime? lastArchiveAt,
    BackupBusy? busy,
    double? progress,
    BackupPhase? phase,
    String? exportingId,
    RestoreFlow? restore,
  }) => BackupState(
    measure: measure ?? this.measure,
    seal: seal ?? this.seal,
    lastArchiveAt: lastArchiveAt ?? this.lastArchiveAt,
    busy: busy ?? this.busy,
    progress: progress ?? this.progress,
    phase: phase ?? this.phase,
    exportingId: exportingId ?? this.exportingId,
    restore: restore ?? this.restore,
  );

  /// Back to rest: busy released, progress, phase and the export dropped,
  /// everything else kept.
  BackupState settled() =>
      BackupState(measure: measure, seal: seal, lastArchiveAt: lastArchiveAt, restore: restore);

  /// The pack finished but the operation runs on into [next] (sealing, the
  /// share sheet): progress leaves, and the cancel affordance with it.
  BackupState packDone(BackupPhase next) => BackupState(
    measure: measure,
    seal: seal,
    lastArchiveAt: lastArchiveAt,
    busy: busy,
    phase: next,
    exportingId: exportingId,
    restore: restore,
  );

  @override
  bool operator ==(Object other) =>
      other is BackupState &&
      other.measure == measure &&
      other.seal == seal &&
      other.lastArchiveAt == lastArchiveAt &&
      other.busy == busy &&
      other.progress == progress &&
      other.phase == phase &&
      other.exportingId == exportingId &&
      other.restore == restore;

  @override
  int get hashCode =>
      Object.hash(measure, seal, lastArchiveAt, busy, progress, phase, exportingId, restore);
}

/// Drives the Backup screen: measures the entry count, holds the persisted
/// choices, and runs the one-at-a-time export, archive and restore actions.
/// Export methods return one-shot outcomes while [BackupState.busy] gates the
/// rows. A restore runs as [BackupState.restore]: the cubit holds the picked
/// copy and the staged archive, and releases both on dismiss and on close.
/// Never rethrows: an export answers an outcome, a restore lands its failure
/// in [BackupState.restore].
class BackupCubit extends Cubit<BackupState> {
  BackupCubit({
    required this._service,
    required this._export,
    required this._import,
    required this._settings,
    required this._descriptors,
    DateTime Function()? clock,
    this._remeasureQuiet = const Duration(milliseconds: 300),
    this._progressGrace = const Duration(milliseconds: 600),
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

  /// How long a pack must run before its percent and cancel appear, and a
  /// restore before it reads 0%: one that finishes inside it never flashes a
  /// control nobody could have used. A restore's first whole percent above 0
  /// shows at once, inside it, there being something to read.
  final Duration _progressGrace;
  late final _Grace _grace = _Grace(_progressGrace);

  /// Bumped by every measure, so a slow file walk started earlier can never
  /// land its stale numbers over a fresher emit.
  int _measureGeneration = 0;

  /// The picked copy the restore flow holds, deleted once the flow lets go.
  String? _pickedPath;
  StagedImport? _staged;

  /// The one restore step running; [close] waits for it before releasing.
  Future<void>? _restoreOp;
  bool _closing = false;

  /// The formats this build ships, in the order every export surface lists
  /// them.
  List<ExporterDescriptor> get descriptors => _descriptors;

  Future<void> load() async {
    emit(state.copyWith(seal: _settings.seal, lastArchiveAt: _settings.lastArchiveAt));
    await _measure();
  }

  Future<void> _measure() async {
    if (isClosed) return;
    final generation = ++_measureGeneration;
    try {
      final measure = await _export.measure(since: state.lastArchiveAt);
      if (isClosed || generation != _measureGeneration) return;
      emit(state.copyWith(measure: measure));
    } catch (e) {
      // Best effort: the counts stay as they were; a later change signal
      // retries.
      if (kDebugMode) debugPrint('BackupCubit.measure failed: $e');
    }
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
    exportingId: exporterId,
    () => _export.shareJournal(
      exporterId: exporterId,
      includeAudio: includeAudio,
      strings: strings,
      onProgress: _onProgress,
      onPackDone: () => _onPackDone(BackupPhase.sharing),
      onSharing: _onSharing,
    ),
  );

  /// Calls off the pack phase of the running backup or export; once the
  /// share sheet is up there is nothing left to cancel and this is quiet.
  void cancelShare() => _export.cancelShare();

  void _onPackDone(BackupPhase next) {
    _grace.close();
    if (isClosed) return;
    emit(state.packDone(next));
  }

  void _onSharing() {
    // A plain pack already moved to sharing when it landed; a second emit
    // of the same state would only rebuild.
    if (isClosed || state.phase == BackupPhase.sharing) return;
    emit(state.copyWith(phase: BackupPhase.sharing));
  }

  void _onProgress(double fraction) => _grace.report(fraction);

  void _showPackProgress(double whole) {
    if (!isClosed) emit(state.copyWith(progress: whole));
  }

  Future<BackupActionResult> exportArchive({String? passphrase}) =>
      _run(BackupBusy.archiving, () async {
        // The pack's snapshot time: an entry recorded while the pack or the
        // share sheet runs is not in this backup.
        final startedAt = _clock();
        final shared = await _export.shareArchive(
          passphrase: passphrase,
          onProgress: _onProgress,
          onPackDone: () =>
              _onPackDone(passphrase == null ? BackupPhase.sharing : BackupPhase.sealing),
          onSharing: _onSharing,
        );
        if (shared) {
          // Persisted even after close: the share sheet outlives the screen,
          // and a backup that finished is a backup that happened.
          try {
            await _settings.setLastArchiveAt(startedAt);
            if (!isClosed) {
              emit(state.copyWith(lastArchiveAt: startedAt));
              unawaited(_measure());
            }
          } catch (e) {
            // The share DID happen: losing the bookkeeping must not be
            // reported as an export that failed.
            if (kDebugMode) debugPrint('BackupCubit.archive date: $e');
          }
        }
        return shared;
      });

  Future<String?> _pickArchive() async {
    try {
      return await _import.pickArchive();
    } catch (e) {
      // A picker that broke is a pick that did not happen: the flow lands at
      // rest rather than holding busy on a picker that is gone.
      if (kDebugMode) debugPrint('BackupCubit.pick failed: $e');
      return null;
    }
  }

  /// Null for a file that could not even be read.
  Future<ImportProbe?> _probeArchive(String path) async {
    try {
      return await _import.probe(path);
    } catch (e) {
      if (kDebugMode) debugPrint('BackupCubit.probe failed: $e');
      return null;
    }
  }

  Future<void> _restoreStep(Future<void> Function() step) async {
    if (_restoreOp != null || _closing || isClosed) return;
    final op = step();
    _restoreOp = op;
    try {
      await op;
    } finally {
      _restoreOp = null;
    }
  }

  /// Picks a file and walks it as far as it can go without the user: a
  /// sealed archive stops at [RestoreProbed], a plain one is staged and
  /// planned, anything else fails without staging. Starts only from rest; a
  /// held result counts as rest and goes, so a cancelled picker lands idle.
  Future<void> pickForRestore() => _restoreStep(() async {
    if (state.isBusy || state.restore.underWay) return;
    emit(state.copyWith(restore: const RestorePicking()));
    final path = await _pickArchive();
    if (_closing) {
      if (path != null) await _import.discardPicked(path);
      return;
    }
    if (path == null) {
      emit(state.copyWith(restore: const RestoreIdle()));
      return;
    }
    _pickedPath = path;
    final probe = await _probeArchive(path);
    switch (probe) {
      case ImportProbe(kind: ArchiveKind.sealed):
        emit(state.copyWith(restore: RestoreProbed(probe)));
      // A zip with no manifest is no backup: it fails here, unstaged.
      case ImportProbe(kind: ArchiveKind.plainZip, contents: ZipContents.export) ||
          ImportProbe(kind: ArchiveKind.plainZip, contents: ZipContents.foreign):
        return _fail(RestoreFailure.damaged, probe);
      case ImportProbe(kind: ArchiveKind.plainZip):
        return _stage(probe, null);
      case _:
        return _fail(RestoreFailure.damaged, probe);
    }
  });

  /// Opens the sealed archive [pickForRestore] stopped at. A passphrase that
  /// does not open it returns to [RestoreProbed] with one more attempt.
  Future<void> unlockRestore(String passphrase) => _restoreStep(() async {
    if (state.restore case RestoreProbed(:final probe, :final attempt)) {
      await _stage(probe, passphrase, attempt: attempt);
    }
  });

  Future<void> _stage(ImportProbe probe, String? passphrase, {int attempt = 0}) async {
    if (_closing) return;
    final path = _pickedPath!;
    emit(state.copyWith(restore: RestoreChecking(probe)));
    final StagedImport staged;
    try {
      staged = await _import.stage(path, passphrase: passphrase);
    } catch (e) {
      if (e is ArchiveException && e.error == ArchiveError.cannotDecrypt && passphrase != null) {
        emit(state.copyWith(restore: RestoreProbed(probe, attempt: attempt + 1)));
        return;
      }
      if (kDebugMode && e is! ArchiveException) debugPrint('BackupCubit.stage failed: $e');
      return _fail(restoreFailureOfError(e), probe);
    }
    _staged = staged;
    // Everything the restore needs is now in staging; a journal-sized copy
    // must not sit in tmp while the user reads the plan.
    await _discardPickedCopy();
    emit(state.copyWith(restore: RestorePlanned(probe, staged.plan)));
  }

  /// Merges the staged archive into the journal: the plan the user agreed
  /// to, or again after a midway failure, with no re-pick and no passphrase.
  Future<void> adoptRestore() => _restoreStep(() async {
    final staged = _staged;
    if (staged == null) return;
    switch (state.restore) {
      case RestorePlanned(:final probe, :final plan) || RestorePartial(:final probe, :final plan):
        emit(state.copyWith(restore: RestoreRunning(probe, plan)));
        // Nothing has landed yet: once the grace passes that reads as 0%, and
        // a whole percent above it shows at once, there being something to
        // read.
        _grace
          ..start((whole) => _emitRestoreProgress(probe, plan, whole), eager: true)
          ..report(0);
        final next = await _runAdoption(staged, probe, plan);
        _grace.close();
        if (next is RestoreDone) await _releaseRestore();
        emit(state.copyWith(restore: next));
      case _:
        return;
    }
  });

  Future<RestoreFlow> _runAdoption(StagedImport staged, ImportProbe probe, ImportPlan plan) async {
    try {
      final summary = await _import.adopt(
        staged,
        onProgress: (done, total) => _grace.report(done / total),
      );
      return RestoreDone(probe, summary);
    } catch (e) {
      if (kDebugMode) debugPrint('BackupCubit.adopt failed: $e');
      return RestorePartial(
        probe,
        plan,
        staged.adoptedSoFar,
        reflectionsLeft: staged.entriesFinished,
      );
    }
  }

  void _emitRestoreProgress(ImportProbe probe, ImportPlan plan, double progress) {
    if (isClosed || state.restore is! RestoreRunning) return;
    final running = RestoreRunning(probe, plan, progress: progress);
    if (state.restore != running) emit(state.copyWith(restore: running));
  }

  /// Lets go of whatever the restore holds and returns to idle. Ignored
  /// while a step is in flight.
  Future<void> dismissRestore() => _restoreStep(() async {
    await _releaseRestore();
    emit(state.copyWith(restore: const RestoreIdle()));
  });

  Future<void> _fail(RestoreFailure failure, ImportProbe? probe) async {
    await _releaseRestore();
    emit(state.copyWith(restore: RestoreFailed(failure, probe: probe)));
  }

  Future<void> _discardPickedCopy() async {
    final path = _pickedPath;
    _pickedPath = null;
    if (path != null) await _import.discardPicked(path);
  }

  Future<void> _releaseRestore() async {
    await _discardPickedCopy();
    final staged = _staged;
    _staged = null;
    if (staged != null) await _import.discard(staged);
  }

  Future<BackupActionResult> _run(
    BackupBusy busy,
    Future<bool> Function() op, {
    String? exportingId,
  }) async {
    if (state.isBusy || state.restore.underWay) return BackupActionResult.cancelled;
    _grace.start(_showPackProgress);
    // A held restore result is told until the next operation, which this is.
    emit(
      state.copyWith(
        busy: busy,
        phase: BackupPhase.packing,
        exportingId: exportingId,
        restore: state.restore.held ? const RestoreIdle() : null,
      ),
    );
    try {
      return await op() ? BackupActionResult.shared : BackupActionResult.cancelled;
    } catch (e) {
      final result = shareFailureResult(e);
      if (kDebugMode && result != BackupActionResult.cancelled) {
        debugPrint('BackupCubit.${busy.name} failed: $e');
      }
      return result;
    } finally {
      _grace.close();
      if (!isClosed) emit(state.settled());
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    _grace.close();
    _remeasureTimer?.cancel();
    await _entriesSub.cancel();
    await _restoreOp;
    await super.close();
    await _releaseRestore();
  }
}

/// One running operation's progress grace. A pack and a restore share it, as
/// they never run at once. What is reported inside the grace is held back,
/// so an operation that finishes inside it never flashes a measure; past it,
/// or with `eager` at the first whole percent above 0, each new whole
/// percent goes to `show`, and only a new one.
final class _Grace {
  _Grace(this._period);

  final Duration _period;
  Timer? _timer;
  void Function(double whole)? _show;
  double? _latest;
  bool _open = false;
  bool _eager = false;

  void start(void Function(double whole) show, {bool eager = false}) {
    close();
    _show = show;
    _eager = eager;
    _timer = Timer(_period, () {
      if (_open) return;
      _open = true;
      final latest = _latest;
      if (latest != null) show(latest);
    });
  }

  void report(double fraction) {
    final whole = shownFraction(fraction);
    if (whole == _latest) return;
    _latest = whole;
    if (!_open && !(_eager && whole > 0)) return;
    _open = true;
    _show?.call(whole);
  }

  void close() {
    _timer?.cancel();
    _timer = null;
    _show = null;
    _latest = null;
    _open = false;
    _eager = false;
  }
}
