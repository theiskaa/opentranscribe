import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/export/archive_crypto.dart';
import 'package:opentranscribe/core/export/default_exporter.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/share_export.dart';
import 'package:opentranscribe/core/export/stored_zip.dart';
import 'package:opentranscribe/core/export/zip_pack.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/services/backup_settings.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_merge.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:reflections/reflections.dart';
import 'package:reflections/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';

import '../../support/archive_rewrite.dart';
import '../../support/failing_entry_store.dart';
import '../../support/failing_reflection_store.dart';
import '../../support/fake_audio_recorder.dart';
import '../../support/fake_share_export.dart';
import '../../support/tracking_staging_registry.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  final fixedClock = DateTime.utc(2026, 8, 7, 12);

  const strings = ExportStrings(
    untitledEntry: 'Untitled',
    transcriptHeading: 'Transcript',
    quietReflection: 'A quiet stretch.',
    periodLabels: {
      ReflectionPeriod.daily: 'Day',
      ReflectionPeriod.weekly: 'Week',
      ReflectionPeriod.monthly: 'Month',
    },
  );

  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('backup_cubit_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  Future<_World> build({
    BackupSettings Function(BackupSettings)? wrapSettings,
    Duration progressGrace = Duration.zero,
    DateTime Function()? clock,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: key);
    final store = FailingEntryStore(storage);
    final recordings = Directory('${temp.path}/recordings');
    await recordings.create(recursive: true);
    final transcription = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(recordingsDir: recordings.path),
      engine: FakeBatchEngine(),
      store: store,
      clock: () => fixedClock,
      fileDeleter: (f) async => f.deleteSync(),
    );
    final reflectionStore = FailingReflectionStore(storage);
    final reflections = ReflectionService(
      engine: FakeReflectionEngine(),
      store: reflectionStore,
      settings: ReflectionSettings(storage: storage),
      entries: store.all,
      language: () => 'en-US',
      clock: () => fixedClock,
      weekOf: (d) => DateTime(d.year, d.month, d.day),
    );
    final share = FakeShareExport(captureTo: temp);
    final staging = TrackingStagingRegistry();
    var settings = BackupSettings(storage: storage);
    if (wrapSettings != null) settings = wrapSettings(settings);
    final export = ExportService(
      transcription: transcription,
      reflections: reflections,
      exporters: {'markdown': const DefaultExporter()},
      share: share,
      appVersion: () async => '0.1.0',
      staging: staging,
      clock: () => fixedClock,
    );
    final import = ImportService(
      transcription: transcription,
      reflections: reflections,
      share: share,
      staging: staging,
    );
    final cubit = BackupCubit(
      service: transcription,
      export: export,
      import: import,
      settings: settings,
      descriptors: const [
        ExporterDescriptor(exporterId: 'markdown', format: ExportFormat.markdown, logo: 'm.svg'),
      ],
      clock: clock ?? () => fixedClock,
      remeasureQuiet: Duration.zero,
      progressGrace: progressGrace,
    );
    addTearDown(cubit.close);
    return (
      cubit: cubit,
      share: share,
      settings: settings,
      store: store,
      staging: staging,
      transcription: transcription,
      reflectionStore: reflectionStore,
    );
  }

  Entry entry(String id) =>
      Entry(id: id, createdAt: fixedClock, audioPath: null, duration: const Duration(seconds: 5));

  test('shareFailureResult reads a share that never presented as a quiet cancel', () {
    expect(
      shareFailureResult(const ShareExportException('sheet up', ShareExportException.busy)),
      BackupActionResult.cancelled,
    );
    expect(
      shareFailureResult(const ShareExportException('no scene', ShareExportException.unavailable)),
      BackupActionResult.cancelled,
    );
  });

  test('shareFailureResult names the size cap and the full disk, all else is generic', () {
    expect(
      shareFailureResult(const StoredZipException(StoredZipError.tooLarge, 'exceeds 4 GB')),
      BackupActionResult.failedTooLarge,
    );
    expect(
      shareFailureResult(const FileSystemException('write failed', 'f', OSError('no space', 28))),
      BackupActionResult.failedNoSpace,
    );
    expect(
      shareFailureResult(const StoredZipException(StoredZipError.unsupported, 'zip64')),
      BackupActionResult.failed,
    );
    expect(shareFailureResult(const ZipPackAborted()), BackupActionResult.cancelled);
    expect(shareFailureResult(const ShareExportException('broke')), BackupActionResult.failed);
    expect(
      shareFailureResult(const FileSystemException('write failed', 'f', OSError('denied', 13))),
      BackupActionResult.failed,
    );
    expect(
      shareFailureResult(const FileSystemException('write failed')),
      BackupActionResult.failed,
    );
    expect(shareFailureResult(StateError('x')), BackupActionResult.failed);
  });

  test(
    'only a newer app and a re-zip get a failure of their own; other errors read as damaged',
    () {
      expect(restoreFailureOf(ArchiveError.unsupportedVersion), RestoreFailure.newerVersion);
      expect(restoreFailureOf(ArchiveError.unsupportedZip), RestoreFailure.rezipped);
      expect(restoreFailureOf(ArchiveError.malformed), RestoreFailure.damaged);
      expect(restoreFailureOf(ArchiveError.cannotDecrypt), RestoreFailure.damaged);
    },
  );

  test(
    'a restore is under way from the pick until done, failed or let go; only those two hold',
    () {
      const probe = ImportProbe(kind: ArchiveKind.plainZip, fileName: 'j.zip', sizeBytes: 9);
      const plan = ImportPlan(added: 1, replaced: 0, unchanged: 0);
      const summary = ImportSummary(entriesAdded: 1, entriesReplaced: 0);
      const underWay = <RestoreFlow>[
        RestorePicking(),
        RestoreProbed(probe),
        RestoreChecking(probe),
        RestorePlanned(probe, plan),
        RestoreRunning(probe, plan),
        RestorePartial(probe, plan, summary),
      ];
      for (final flow in underWay) {
        expect(flow.underWay, isTrue, reason: '$flow');
        expect(flow.held, isFalse, reason: '$flow');
      }
      expect(const RestoreIdle().underWay, isFalse);
      expect(const RestoreIdle().held, isFalse);
      for (final flow in const <RestoreFlow>[
        RestoreDone(probe, summary),
        RestoreFailed(RestoreFailure.damaged),
      ]) {
        expect(flow.underWay, isFalse, reason: '$flow');
        expect(flow.held, isTrue, reason: '$flow');
      }
    },
  );

  test('load reads the settings and measures the journal, sealing by default', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    expect(world.cubit.state.seal, isTrue);
    expect(world.cubit.state.measure?.entries, 1);
  });

  test('the seal choice persists through the settings', () async {
    final world = await build();
    await world.cubit.load();
    await world.cubit.setSeal(false);
    expect(world.settings.seal, isFalse);
    expect(world.cubit.state.seal, isFalse);
  });

  test('a completed journal export answers shared', () async {
    final world = await build();
    await world.cubit.load();
    expect(
      await world.cubit.exportJournal(strings: strings, exporterId: 'markdown', includeAudio: true),
      BackupActionResult.shared,
    );
    expect(world.share.calls, contains('shareFiles'));
    expect(world.cubit.state.busy, BackupBusy.none);
  });

  test('a dismissed share sheet answers cancelled, not failed', () async {
    final world = await build();
    await world.cubit.load();
    world.share.shareCompletes = false;
    expect(
      await world.cubit.exportJournal(strings: strings, exporterId: 'markdown', includeAudio: true),
      BackupActionResult.cancelled,
    );
  });

  test('a share sheet that never presented answers cancelled, not failed', () async {
    final world = await build();
    await world.cubit.load();
    world.share.throwOnShare = true;
    expect(
      await world.cubit.exportJournal(strings: strings, exporterId: 'markdown', includeAudio: true),
      BackupActionResult.cancelled,
    );
    expect(world.cubit.state.busy, BackupBusy.none);
  });

  test('a saved archive stamps the last archive time; a cancelled one does not', () async {
    final world = await build();
    await world.cubit.load();
    world.share.shareCompletes = false;
    await world.cubit.exportArchive();
    expect(world.cubit.state.lastArchiveAt, isNull);
    world.share.shareCompletes = true;
    await world.cubit.exportArchive();
    expect(world.cubit.state.lastArchiveAt, fixedClock);
    expect(world.settings.lastArchiveAt, fixedClock);
  });

  test('load restores the last archive time from the settings', () async {
    final world = await build();
    await world.settings.setLastArchiveAt(fixedClock);
    await world.cubit.load();
    expect(world.cubit.state.lastArchiveAt, fixedClock);
  });

  test('a busy-only emit preserves the last archive time', () async {
    final world = await build();
    await world.cubit.load();
    await world.cubit.exportArchive();
    await world.cubit.exportJournal(strings: strings, exporterId: 'markdown', includeAudio: true);
    expect(world.cubit.state.lastArchiveAt, fixedClock);
  });

  test('a backup finishing after the screen closes still records its time', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    world.share.shareDelay = const Duration(milliseconds: 50);
    final sharing = world.cubit.exportArchive();
    await world.cubit.close();
    expect(await sharing, BackupActionResult.shared);
    expect(world.settings.lastArchiveAt, fixedClock);
  });

  test('a second action while one runs answers cancelled', () async {
    final world = await build();
    await world.cubit.load();
    world.share.shareDelay = const Duration(milliseconds: 50);
    final first = world.cubit.exportJournal(
      strings: strings,
      exporterId: 'markdown',
      includeAudio: true,
    );
    expect(await world.cubit.exportArchive(), BackupActionResult.cancelled);
    expect(await first, BackupActionResult.shared);
  });

  test('settling keeps everything but busy and progress', () {
    const measured = JournalMeasure(entries: 2, recordings: 1, approxBytes: 9000);
    final state = BackupState(
      measure: measured,
      seal: false,
      lastArchiveAt: fixedClock,
      busy: BackupBusy.archiving,
      progress: 0.4,
    ).settled();
    expect(state.busy, BackupBusy.none);
    expect(state.progress, isNull);
    expect(state.measure, measured);
    expect(state.seal, isFalse);
    expect(state.lastArchiveAt, fixedClock);
  });

  test('a finished pack drops progress but keeps the operation busy, on into its next step', () {
    final state = const BackupState(
      busy: BackupBusy.archiving,
      progress: 0.9,
      phase: BackupPhase.packing,
    ).packDone(BackupPhase.sealing);
    expect(state.busy, BackupBusy.archiving);
    expect(state.progress, isNull);
    expect(state.phase, BackupPhase.sealing);
  });

  test('settling drops the step along with busy', () {
    final state = const BackupState(
      busy: BackupBusy.exporting,
      phase: BackupPhase.sharing,
    ).settled();
    expect(state.phase, isNull);
  });

  test('an encrypted backup packs, then seals, then waits on the share sheet', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    final phases = <BackupPhase?>[];
    final sub = world.cubit.stream.listen((s) => phases.add(s.phase));
    expect(
      await world.cubit.exportArchive(passphrase: 'correct horse battery'),
      BackupActionResult.shared,
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(_steps(phases), [BackupPhase.packing, BackupPhase.sealing, BackupPhase.sharing, null]);
  });

  test('a plain backup goes from packing straight to the share sheet', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    final phases = <BackupPhase?>[];
    final sub = world.cubit.stream.listen((s) => phases.add(s.phase));
    expect(await world.cubit.exportArchive(), BackupActionResult.shared);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(_steps(phases), [BackupPhase.packing, BackupPhase.sharing, null]);
  });

  test('a journal export goes from packing straight to the share sheet', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    final phases = <BackupPhase?>[];
    final sub = world.cubit.stream.listen((s) => phases.add(s.phase));
    expect(
      await world.cubit.exportJournal(
        strings: strings,
        exporterId: 'markdown',
        includeAudio: false,
      ),
      BackupActionResult.shared,
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(_steps(phases), [BackupPhase.packing, BackupPhase.sharing, null]);
  });

  test('a running journal export names its exporter until it settles', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    world.share.shareDelay = const Duration(milliseconds: 50);
    final run = world.cubit.exportJournal(
      strings: strings,
      exporterId: 'markdown',
      includeAudio: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(world.cubit.state.exportingId, 'markdown');
    await run;
    expect(world.cubit.state.exportingId, isNull);
  });

  test('a backup names no exporter', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    final ids = <String?>[];
    final sub = world.cubit.stream.listen((s) => ids.add(s.exportingId));
    await world.cubit.exportArchive();
    await sub.cancel();
    expect(ids.whereType<String>(), isEmpty);
  });

  test('a refused second action leaves the running step alone', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    world.share.shareDelay = const Duration(milliseconds: 50);
    final sharing = world.cubit.stream.firstWhere((s) => s.phase == BackupPhase.sharing);
    final first = world.cubit.exportArchive();
    await sharing;
    expect(await world.cubit.exportArchive(), BackupActionResult.cancelled);
    expect(world.cubit.state.phase, BackupPhase.sharing);
    await first;
    expect(world.cubit.state.phase, isNull);
  });

  test('a backup reports pack progress and settles clean', () async {
    final world = await build();
    final recordings = Directory('${temp.path}/recordings');
    await File(
      '${recordings.path}/otr-1.m4a',
    ).writeAsBytes(List<int>.generate(4096, (i) => i % 200));
    await world.store.save(
      Entry(
        id: 'e1',
        createdAt: fixedClock,
        audioPath: 'otr-1.m4a',
        duration: const Duration(seconds: 5),
      ),
    );
    await world.cubit.load();
    final seen = <double?>[];
    final sub = world.cubit.stream.listen((s) => seen.add(s.progress));
    expect(await world.cubit.exportArchive(), BackupActionResult.shared);
    await sub.cancel();
    expect(seen.whereType<double>(), isNotEmpty);
    expect(world.cubit.state.progress, isNull);
    expect(world.cubit.state.busy, BackupBusy.none);
  });

  test('a pack that finishes inside the grace never shows progress', () async {
    final world = await build(progressGrace: const Duration(seconds: 30));
    await world.store.save(entry('e1'));
    await world.cubit.load();
    final seen = <double?>[];
    final sub = world.cubit.stream.listen((s) => seen.add(s.progress));
    expect(await world.cubit.exportArchive(), BackupActionResult.shared);
    await sub.cancel();
    expect(seen.whereType<double>(), isEmpty);
  });

  test('a bookkeeping failure after a completed share still answers shared', () async {
    final world = await build(wrapSettings: _DateRefusingSettings.new);
    await world.store.save(entry('e1'));
    await world.cubit.load();
    expect(await world.cubit.exportArchive(), BackupActionResult.shared);
    expect(world.cubit.state.busy, BackupBusy.none);
  });

  group('the restore flow', () {
    var copies = 0;
    late String recordings;

    setUp(() => recordings = '${temp.path}/recordings');

    Future<String> offer(_World world, String archive) async {
      final picked = '${temp.path}/picked-${copies++}-${archive.split('/').last}';
      await File(archive).copy(picked);
      world.share.pickedPath = picked;
      return picked;
    }

    Future<String> archiveOf(_World world, {String? passphrase}) async {
      await world.cubit.exportArchive(passphrase: passphrase);
      return world.share.captured.last;
    }

    Future<void> seedWithAudio(_World world, int count) async {
      for (var i = 0; i < count; i++) {
        await File('$recordings/otr-$i.m4a').writeAsBytes(List<int>.generate(1 << 16, (b) => b));
        await world.store.save(
          Entry(
            id: 'a$i',
            createdAt: fixedClock,
            audioPath: 'otr-$i.m4a',
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    Future<void> forgetAll(_World world) async {
      for (final e in world.store.all()) {
        await world.store.delete(e.id);
      }
      for (final f in Directory(recordings).listSync()) {
        f.deleteSync();
      }
    }

    test('a backup whose entries are all here still restores the reflections it holds', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      final reflection = Reflection(
        periodStart: DateTime(2026, 8, 3),
        generatedAt: fixedClock,
        text: 'A steady week.',
      );
      await world.reflectionStore.save(reflection);
      await world.cubit.load();
      final archive = await archiveOf(world);
      await world.reflectionStore.delete(DateTime(2026, 8, 3));
      await offer(world, archive);

      await world.cubit.pickForRestore();
      final planned = world.cubit.state.restore as RestorePlanned;
      expect(planned.plan.added + planned.plan.replaced, 0);
      expect(planned.plan.reflections, greaterThan(0));
      expect(planned.plan.isEmpty, isFalse);
      await world.cubit.adoptRestore();
      expect(world.cubit.state.restore, isA<RestoreDone>());
      expect(world.reflectionStore.read(DateTime(2026, 8, 3))?.text, 'A steady week.');
    });

    test('a full disk while staging fails as no space, its own way out', () {
      expect(
        restoreFailureOfError(const FileSystemException('write failed', 'f', OSError('full', 28))),
        RestoreFailure.noSpace,
      );
      expect(
        restoreFailureOfError(const ArchiveException(ArchiveError.unsupportedZip, 'deflate')),
        RestoreFailure.rezipped,
      );
      expect(restoreFailureOfError(StateError('x')), RestoreFailure.damaged);
    });

    test('a zip with no manifest fails at the pick, never staged', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      await world.cubit.exportJournal(
        strings: strings,
        exporterId: 'markdown',
        includeAudio: false,
      );
      final picked = await offer(world, world.share.captured.last);

      await world.cubit.pickForRestore();
      final failed = world.cubit.state.restore as RestoreFailed;
      expect(failed.failure, RestoreFailure.damaged);
      expect(failed.probe?.contents, ZipContents.export);
      expect(world.staging.imports, isEmpty);
      expect(File(picked).existsSync(), isFalse);
    });

    test('reflections that break after every entry landed leave only the reflections', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.reflectionStore.save(
        Reflection(periodStart: DateTime(2026, 8, 3), generatedAt: fixedClock, text: 'A week.'),
      );
      await world.cubit.load();
      final archive = await archiveOf(world);
      await world.store.delete('e1');
      await world.reflectionStore.delete(DateTime(2026, 8, 3));
      await offer(world, archive);
      await world.cubit.pickForRestore();
      world.reflectionStore.failNextSaveAfterRow = true;

      await world.cubit.adoptRestore();
      final partial = world.cubit.state.restore as RestorePartial;
      expect(partial.reflectionsLeft, isTrue);
      expect(partial.restored.entriesAdded, 1);
    });

    test('a full disk once adoption is writing stops partway, keeping what landed', () async {
      final world = await build();
      for (var i = 0; i < 2; i++) {
        await world.store.save(entry('e$i'));
      }
      await world.cubit.load();
      final archive = await archiveOf(world);
      await forgetAll(world);
      await offer(world, archive);
      await world.cubit.pickForRestore();
      world.store.failOnce.add('e1');

      await world.cubit.adoptRestore();
      final partial = world.cubit.state.restore as RestorePartial;
      expect(partial.restored.entriesAdded, 1);
      expect(partial.reflectionsLeft, isFalse);
    });

    test('a picked file that cannot be read fails with no probe and nothing staged', () async {
      final world = await build();
      await world.cubit.load();
      world.share.pickedPath = '${temp.path}/vanished.zip';
      await world.cubit.pickForRestore();
      expect(world.cubit.state.restore, const RestoreFailed(RestoreFailure.damaged));
      expect(world.cubit.state.busy, BackupBusy.none);
      expect(world.staging.imports, isEmpty);
    });

    test('a restore that adds entries re-measures the entry count', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final archive = await archiveOf(world);
      await world.store.delete('e1');
      await world.cubit.load();
      expect(world.cubit.state.measure?.entries, 0);
      await offer(world, archive);
      await world.cubit.pickForRestore();
      await world.cubit.adoptRestore();
      await pumpEventQueue();
      expect(world.cubit.state.measure?.entries, 1);
    });

    test('a plain archive goes straight to its plan, then restores on confirm', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final archive = await archiveOf(world);
      await world.store.delete('e1');
      final picked = await offer(world, archive);
      final seen = <BackupState>[];
      final sub = world.cubit.stream.listen(seen.add);

      await world.cubit.pickForRestore();
      final planned = world.cubit.state.restore;
      expect(planned, isA<RestorePlanned>());
      planned as RestorePlanned;
      expect(planned.plan, const ImportPlan(added: 1, replaced: 0, unchanged: 0));
      expect(planned.probe.fileName, picked.split('/').last);
      expect(planned.probe.sizeBytes, greaterThan(0));
      expect(world.cubit.state.busy, BackupBusy.none);
      expect(world.store.all(), isEmpty);
      final staging = world.staging.imports.last;
      expect(world.staging.owns(staging), isTrue);

      await world.cubit.adoptRestore();
      await pumpEventQueue();
      await sub.cancel();
      expect(world.cubit.state.restore, isA<RestoreDone>());
      final done = world.cubit.state.restore as RestoreDone;
      expect(done.summary.entriesAdded, 1);
      expect(done.probe, planned.probe);
      expect(world.store.read('e1'), isNotNull);
      expect(world.staging.owns(staging), isFalse);
      expect(Directory(staging).existsSync(), isFalse);
      expect(File(picked).existsSync(), isFalse);
      expect(world.cubit.state.busy, BackupBusy.none);
      expect(seen.map((s) => s.busy), everyElement(BackupBusy.none));
      expect(
        seen.map((s) => s.restore.runtimeType),
        containsAllInOrder([RestorePicking, RestoreChecking, RestoreRunning, RestoreDone]),
      );
    });

    test(
      'inside the grace a restore holds back 0% and shows its first whole percent at once',
      () async {
        final world = await build(progressGrace: const Duration(seconds: 30));
        for (var i = 0; i < 201; i++) {
          await world.store.save(entry('e$i'));
        }
        await world.cubit.load();
        final archive = await archiveOf(world);
        await forgetAll(world);
        await offer(world, archive);
        await world.cubit.pickForRestore();
        final progress = <double?>[];
        final sub = world.cubit.stream.listen((s) {
          if (s.restore case RestoreRunning(progress: final p)) {
            if (progress.isEmpty || progress.last != p) progress.add(p);
          }
        });

        await world.cubit.adoptRestore();
        await pumpEventQueue();
        await sub.cancel();
        expect(progress.take(2), [null, 0.01]);
        expect(progress, isNot(contains(0)));
        expect(progress.last, 1);
      },
    );

    test('past the grace a running restore with nothing landed yet reads 0%', () async {
      final world = await build();
      for (var i = 0; i < 3; i++) {
        await world.store.save(entry('e$i'));
      }
      await world.cubit.load();
      final archive = await archiveOf(world);
      await forgetAll(world);
      await offer(world, archive);
      await world.cubit.pickForRestore();
      final progress = <double?>[];
      final sub = world.cubit.stream.listen((s) {
        if (s.restore case RestoreRunning(progress: final p)) {
          if (progress.isEmpty || progress.last != p) progress.add(p);
        }
      });
      final gate = Completer<void>();
      world.store.saveGate = gate;

      final adopting = world.cubit.adoptRestore();
      await pumpEventQueue();
      expect(world.cubit.state.restore, isA<RestoreRunning>());
      expect((world.cubit.state.restore as RestoreRunning).progress, 0);
      gate.complete();
      await adopting;
      await pumpEventQueue();
      await sub.cancel();
      expect(progress, [null, 0, 0.33, 0.67, 1]);
    });

    test('a sealed archive asks for its passphrase and counts each wrong one', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final picked = await offer(world, await archiveOf(world, passphrase: 'right'));

      await world.cubit.pickForRestore();
      final probed = world.cubit.state.restore as RestoreProbed;
      expect(probed.attempt, 0);
      expect(world.staging.imports, isEmpty);

      await world.cubit.unlockRestore('wrong');
      expect(world.cubit.state.restore, RestoreProbed(probed.probe, attempt: 1));
      await world.cubit.unlockRestore('still wrong');
      expect(world.cubit.state.restore, RestoreProbed(probed.probe, attempt: 2));
      expect(world.cubit.state.busy, BackupBusy.none);
      expect(File(picked).existsSync(), isTrue);
    });

    test('a sealed archive opens with the right passphrase after a wrong one', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      await offer(world, await archiveOf(world, passphrase: 'right'));
      await world.cubit.pickForRestore();
      final probe = (world.cubit.state.restore as RestoreProbed).probe;

      await world.cubit.unlockRestore('wrong');
      await world.cubit.unlockRestore('right');
      expect(
        world.cubit.state.restore,
        RestorePlanned(probe, const ImportPlan(added: 0, replaced: 0, unchanged: 1)),
      );
      await world.cubit.adoptRestore();
      expect(world.cubit.state.restore, isA<RestoreDone>());
    });

    test('a file that is not an archive fails without ever staging', () async {
      final world = await build();
      await world.cubit.load();
      final noise = File('${temp.path}/noise.bin');
      await noise.writeAsBytes(List<int>.generate(50, (i) => i));
      final picked = await offer(world, noise.path);

      await world.cubit.pickForRestore();
      final failed = world.cubit.state.restore as RestoreFailed;
      expect(failed.failure, RestoreFailure.damaged);
      expect(failed.probe?.fileName, picked.split('/').last);
      expect(world.staging.imports, isEmpty);
      expect(File(picked).existsSync(), isFalse);
      expect(world.cubit.state.busy, BackupBusy.none);
    });

    test('a cancelled picker leaves an idle restore idle', () async {
      final world = await build();
      await world.cubit.load();
      world.share.pickedPath = null;
      await world.cubit.pickForRestore();
      expect(world.cubit.state.restore, const RestoreIdle());
      expect(world.cubit.state.busy, BackupBusy.none);
    });

    test('a pick from a held result lets it go, and a cancelled picker lands idle', () async {
      final world = await build();
      await world.cubit.load();
      world.share.pickedPath = '${temp.path}/vanished.zip';
      await world.cubit.pickForRestore();
      expect(world.cubit.state.restore, isA<RestoreFailed>());

      world.share.pickedPath = null;
      await world.cubit.pickForRestore();
      expect(world.cubit.state.restore, const RestoreIdle());
      expect(world.cubit.state.busy, BackupBusy.none);
    });

    test('a picker that throws lands at rest, never holding busy on a pick that is gone', () async {
      final world = await build();
      await world.cubit.load();
      world.share.pickError = StateError('picker broke');
      await world.cubit.pickForRestore();
      expect(world.cubit.state.restore, const RestoreIdle());
      expect(world.cubit.state.busy, BackupBusy.none);
    });

    test('a second pick while the first is still picking opens no second picker', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final picked = await offer(world, await archiveOf(world, passphrase: 'p'));

      final first = world.cubit.pickForRestore();
      expect(world.cubit.state.restore, const RestorePicking());
      await world.cubit.pickForRestore();
      await first;
      expect(world.share.calls.where((c) => c == 'pickArchive'), hasLength(1));
      expect(world.cubit.state.restore, isA<RestoreProbed>());
      expect(File(picked).existsSync(), isTrue);
    });

    test('a dismiss while picking is ignored and the passphrase still opens the archive', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      await offer(world, await archiveOf(world, passphrase: 'p'));

      final first = world.cubit.pickForRestore();
      await world.cubit.dismissRestore();
      await first;
      expect(world.cubit.state.restore, isA<RestoreProbed>());
      await world.cubit.unlockRestore('p');
      expect(world.cubit.state.restore, isA<RestorePlanned>());
    });

    test('a damaged plain archive fails plainly and deletes the picked copy', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final archive = await archiveOf(world);
      final bytes = await File(archive).readAsBytes();
      bytes[bytes.length ~/ 2] ^= 0xFF;
      await File(archive).writeAsBytes(bytes);
      final picked = await offer(world, archive);

      await world.cubit.pickForRestore();
      expect((world.cubit.state.restore as RestoreFailed).failure, RestoreFailure.damaged);
      expect(File(picked).existsSync(), isFalse);
      expect(world.staging.imports.where(world.staging.owns), isEmpty);
      expect(world.cubit.state.busy, BackupBusy.none);
    });

    test('a sealed archive from a newer app fails as newer and deletes the picked copy', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final plain = await rewriteArchive(
        await archiveOf(world),
        '${temp.path}/newer.zip',
        edit: (path, bytes) => path == 'manifest.json'
            ? editJson(bytes, (json) => json..['formatVersion'] = 99)
            : bytes,
      );
      final sealed = File('${temp.path}/newer.otarchive');
      await sealArchiveFile(payload: plain, target: sealed, passphrase: 'p');
      final picked = await offer(world, sealed.path);

      await world.cubit.pickForRestore();
      await world.cubit.unlockRestore('p');
      expect((world.cubit.state.restore as RestoreFailed).failure, RestoreFailure.newerVersion);
      expect(File(picked).existsSync(), isFalse);
    });

    test('unlocking or confirming twice at once runs the work once', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final archive = await archiveOf(world, passphrase: 'p');
      await world.store.delete('e1');
      await offer(world, archive);
      await world.cubit.pickForRestore();

      await Future.wait([world.cubit.unlockRestore('p'), world.cubit.unlockRestore('p')]);
      expect(world.staging.imports, hasLength(1));
      await Future.wait([world.cubit.adoptRestore(), world.cubit.adoptRestore()]);
      expect((world.cubit.state.restore as RestoreDone).summary.entriesAdded, 1);
    });

    test('a step asked for from the wrong state changes nothing', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      await world.cubit.adoptRestore();
      await world.cubit.unlockRestore('p');
      expect(world.cubit.state.restore, const RestoreIdle());

      await offer(world, await archiveOf(world));
      await world.cubit.pickForRestore();
      final planned = world.cubit.state.restore;
      await world.cubit.unlockRestore('p');
      expect(world.cubit.state.restore, planned);
      expect(world.staging.imports, hasLength(1));
    });

    test('a restore that breaks midway keeps its staging, and resuming finishes it', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.store.save(entry('e2'));
      await world.cubit.load();
      final archive = await archiveOf(world);
      await forgetAll(world);
      await offer(world, archive);
      await world.cubit.pickForRestore();
      final staging = world.staging.imports.last;
      world.store.failOnce.add('e2');

      await world.cubit.adoptRestore();
      final partial = world.cubit.state.restore as RestorePartial;
      expect(partial.restored.entriesAdded, 1);
      expect(partial.reflectionsLeft, isFalse);
      expect(world.cubit.state.busy, BackupBusy.none);
      expect(world.staging.owns(staging), isTrue);

      await world.cubit.adoptRestore();
      expect((world.cubit.state.restore as RestoreDone).summary.entriesAdded, 2);
      expect(world.store.all().map((e) => e.id).toSet(), {'e1', 'e2'});
      expect(world.staging.owns(staging), isFalse);
    });

    test('dismissing a partial restore releases its staging', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.store.save(entry('e2'));
      await world.cubit.load();
      final archive = await archiveOf(world);
      await forgetAll(world);
      await offer(world, archive);
      await world.cubit.pickForRestore();
      final staging = world.staging.imports.last;
      world.store.failOnce.add('e2');
      await world.cubit.adoptRestore();

      await world.cubit.dismissRestore();
      expect(world.cubit.state.restore, const RestoreIdle());
      expect(world.staging.owns(staging), isFalse);
      expect(Directory(staging).existsSync(), isFalse);
    });

    test('dismissing a planned restore releases its staging and the picked copy', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final picked = await offer(world, await archiveOf(world, passphrase: 'p'));
      await world.cubit.pickForRestore();
      await world.cubit.unlockRestore('p');
      final staging = world.staging.imports.last;

      await world.cubit.dismissRestore();
      expect(world.cubit.state.restore, const RestoreIdle());
      expect(world.staging.owns(staging), isFalse);
      expect(Directory(staging).existsSync(), isFalse);
      expect(File(picked).existsSync(), isFalse);
      await world.cubit.adoptRestore();
      expect(world.cubit.state.restore, const RestoreIdle());
    });

    test('dismissing a passphrase prompt deletes the picked copy', () async {
      final world = await build();
      await world.cubit.load();
      final picked = await offer(world, await archiveOf(world, passphrase: 'p'));
      await world.cubit.pickForRestore();
      await world.cubit.dismissRestore();
      expect(world.cubit.state.restore, const RestoreIdle());
      expect(File(picked).existsSync(), isFalse);
    });

    test('a pick while a plan waits is refused and the plan keeps its staging', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final archive = await archiveOf(world);
      await offer(world, archive);
      await world.cubit.pickForRestore();
      final planned = world.cubit.state.restore;
      final staging = world.staging.imports.last;

      await offer(world, archive);
      await world.cubit.pickForRestore();
      expect(world.share.calls.where((c) => c == 'pickArchive'), hasLength(1));
      expect(world.cubit.state.restore, planned);
      expect(world.staging.owns(staging), isTrue);
    });

    test('a backup or an export waits out a restore under way', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      await offer(world, await archiveOf(world));
      await world.cubit.pickForRestore();
      expect(world.cubit.state.restore, isA<RestorePlanned>());

      expect(await world.cubit.exportArchive(), BackupActionResult.cancelled);
      expect(
        await world.cubit.exportJournal(
          strings: strings,
          exporterId: 'markdown',
          includeAudio: true,
        ),
        BackupActionResult.cancelled,
      );
      expect(world.cubit.state.restore, isA<RestorePlanned>());
    });

    test('the next backup or export lets a held restore result go', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      await offer(world, await archiveOf(world));
      await world.cubit.pickForRestore();
      await world.cubit.adoptRestore();
      expect(world.cubit.state.restore, isA<RestoreDone>());

      await world.cubit.exportJournal(strings: strings, exporterId: 'markdown', includeAudio: true);
      expect(world.cubit.state.restore, const RestoreIdle());

      world.share.pickedPath = '${temp.path}/vanished.zip';
      await world.cubit.pickForRestore();
      expect(world.cubit.state.restore, isA<RestoreFailed>());
      await world.cubit.exportArchive();
      expect(world.cubit.state.restore, const RestoreIdle());
    });

    test('closing while the picker is open stages nothing and deletes the picked copy', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final picked = await offer(world, await archiveOf(world));
      world.share.pickGate = Completer<void>();

      final picking = world.cubit.pickForRestore();
      final closing = world.cubit.close();
      world.share.pickGate!.complete();
      await picking;
      await closing;
      expect(world.staging.imports, isEmpty);
      expect(File(picked).existsSync(), isFalse);
    });

    test('closing the cubit releases a held restore and the picked copy', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      final picked = await offer(world, await archiveOf(world, passphrase: 'p'));
      await world.cubit.pickForRestore();
      await world.cubit.unlockRestore('p');
      final staging = world.staging.imports.last;

      await world.cubit.close();
      expect(world.staging.owns(staging), isFalse);
      expect(Directory(staging).existsSync(), isFalse);
      expect(File(picked).existsSync(), isFalse);
    });

    test('closing while a restore moves recordings in lets every one land first', () async {
      final world = await build();
      await seedWithAudio(world, 6);
      await world.cubit.load();
      final archive = await archiveOf(world);
      await forgetAll(world);
      await offer(world, archive);
      await world.cubit.pickForRestore();
      final staging = world.staging.imports.last;

      final running = world.cubit.adoptRestore();
      expect(world.cubit.state.restore, isA<RestoreRunning>());
      await world.cubit.close();
      await running;
      for (var i = 0; i < 6; i++) {
        final restored = world.store.read('a$i')!;
        expect(restored.audioPath, 'otr-$i.m4a');
        expect(File('$recordings/otr-$i.m4a').existsSync(), isTrue);
      }
      expect(world.staging.owns(staging), isFalse);
      expect(Directory(staging).existsSync(), isFalse);
    });

    test(
      'closing while a sealed archive is checked waits for the check, then releases it',
      () async {
        final world = await build();
        await seedWithAudio(world, 6);
        await world.cubit.load();
        final picked = await offer(world, await archiveOf(world, passphrase: 'p'));
        await forgetAll(world);
        await world.cubit.pickForRestore();

        final checking = world.cubit.unlockRestore('p');
        expect(world.cubit.state.restore, isA<RestoreChecking>());
        await world.cubit.close();
        await checking;
        final staging = world.staging.imports.last;
        expect(world.staging.owns(staging), isFalse);
        expect(Directory(staging).existsSync(), isFalse);
        expect(File(picked).existsSync(), isFalse);
        expect(world.store.all(), isEmpty);
        expect(Directory(recordings).listSync(), isEmpty);
      },
    );
  });

  group('new since the last backup', () {
    Entry entryAt(String id, DateTime at) =>
        Entry(id: id, createdAt: at, audioPath: null, duration: const Duration(seconds: 5));

    test('with no backup ever made there is no count of new entries', () async {
      final world = await build();
      await world.store.save(entry('e1'));
      await world.cubit.load();
      expect(world.cubit.state.newSinceBackup, isNull);
    });

    test('only entries created after the last backup count as new since it', () async {
      final world = await build();
      await world.settings.setLastArchiveAt(fixedClock.subtract(const Duration(days: 2)));
      await world.store.save(entryAt('old', fixedClock.subtract(const Duration(days: 3))));
      await world.store.save(entryAt('new', fixedClock.subtract(const Duration(days: 1))));
      await world.cubit.load();
      expect(world.cubit.state.newSinceBackup, 1);
    });

    test('a change signal re-measures the count of entries new since the backup', () async {
      final world = await build();
      await world.settings.setLastArchiveAt(fixedClock.subtract(const Duration(days: 2)));
      await world.cubit.load();
      expect(world.cubit.state.newSinceBackup, 0);

      await world.transcription.adoptImportedEntries([
        StagedImportEntry(entry: entryAt('arrived', fixedClock.subtract(const Duration(days: 1)))),
      ]);
      await pumpEventQueue();
      expect(world.cubit.state.newSinceBackup, 1);
    });

    test('a backup is stamped with the time its pack began, not when the share closed', () async {
      var now = fixedClock;
      final world = await build(clock: () => now);
      await world.store.save(entry('e1'));
      await world.cubit.load();
      world.share.shareDelay = const Duration(milliseconds: 20);

      final sharing = world.cubit.exportArchive();
      now = fixedClock.add(const Duration(minutes: 5));
      await sharing;
      expect(world.cubit.state.lastArchiveAt, fixedClock);
      expect(world.settings.lastArchiveAt, fixedClock);
    });

    test('a finished backup brings the new count back to zero', () async {
      final world = await build();
      await world.settings.setLastArchiveAt(fixedClock.subtract(const Duration(days: 2)));
      await world.store.save(entryAt('new', fixedClock.subtract(const Duration(days: 1))));
      await world.cubit.load();
      expect(world.cubit.state.newSinceBackup, 1);

      await world.cubit.exportArchive();
      await pumpEventQueue();
      expect(world.cubit.state.newSinceBackup, 0);
    });
  });
}

List<BackupPhase?> _steps(List<BackupPhase?> seen) => [
  for (final (i, phase) in seen.indexed)
    if (i == 0 || seen[i - 1] != phase) phase,
];

typedef _World = ({
  BackupCubit cubit,
  FakeShareExport share,
  BackupSettings settings,
  FailingEntryStore store,
  TrackingStagingRegistry staging,
  TranscriptionService transcription,
  FailingReflectionStore reflectionStore,
});

class _DateRefusingSettings implements BackupSettings {
  _DateRefusingSettings(this._inner);

  final BackupSettings _inner;

  @override
  bool get seal => _inner.seal;

  @override
  DateTime? get lastArchiveAt => _inner.lastArchiveAt;

  @override
  Future<void> setSeal(bool seal) => _inner.setSeal(seal);

  @override
  Future<void> setLastArchiveAt(DateTime at) =>
      throw const FileSystemException('write failed', 'k', OSError('no space', 28));
}
