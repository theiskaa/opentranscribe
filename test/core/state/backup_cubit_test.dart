import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/export/default_exporter.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/share_export.dart';
import 'package:opentranscribe/core/export/staging_registry.dart';
import 'package:opentranscribe/core/export/stored_zip.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/services/backup_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:reflections/reflections.dart';
import 'package:reflections/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';

import '../../support/fake_audio_recorder.dart';
import '../../support/fake_share_export.dart';

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

  Future<({BackupCubit cubit, FakeShareExport share, BackupSettings settings, EntryStore store})>
  build({BackupSettings Function(BackupSettings)? wrapSettings}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: key);
    final store = EntryStore(storage);
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
    final reflections = ReflectionService(
      engine: FakeReflectionEngine(),
      store: ReflectionStore(storage),
      settings: ReflectionSettings(storage: storage),
      entries: store.all,
      language: () => 'en-US',
      clock: () => fixedClock,
      weekOf: (d) => DateTime(d.year, d.month, d.day),
    );
    final share = FakeShareExport(captureTo: temp);
    final staging = StagingRegistry();
    var settings = BackupSettings(storage: storage, fallbackFormatId: 'markdown');
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
      clock: () => fixedClock,
    );
    addTearDown(cubit.close);
    return (cubit: cubit, share: share, settings: settings, store: store);
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

  test('importResolutionOf maps every archive error to its next step', () {
    expect(importResolutionOf(ArchiveError.cannotDecrypt), ImportResolution.retryPassphrase);
    expect(
      importResolutionOf(ArchiveError.unsupportedVersion),
      ImportResolution.failedNewerVersion,
    );
    expect(importResolutionOf(ArchiveError.unsupportedZip), ImportResolution.failedRezipped);
    expect(importResolutionOf(ArchiveError.malformed), ImportResolution.failed);
  });

  test('load reads the settings and measures the journal, sealing by default', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    expect(world.cubit.state.formatId, 'markdown');
    expect(world.cubit.state.seal, isTrue);
    expect(world.cubit.state.entryCount, 1);
  });

  test('format and seal choices persist through the settings', () async {
    final world = await build();
    await world.cubit.load();
    await world.cubit.setFormat('obsidian');
    await world.cubit.setSeal(false);
    expect(world.settings.formatId, 'obsidian');
    expect(world.settings.seal, isFalse);
    expect(world.cubit.state.formatId, 'obsidian');
    expect(world.cubit.state.seal, isFalse);
  });

  test('a completed journal export answers shared', () async {
    final world = await build();
    await world.cubit.load();
    expect(await world.cubit.exportJournal(strings), BackupActionResult.shared);
    expect(world.share.calls, contains('shareFiles'));
    expect(world.cubit.state.busy, BackupBusy.none);
  });

  test('a dismissed share sheet answers cancelled, not failed', () async {
    final world = await build();
    await world.cubit.load();
    world.share.shareCompletes = false;
    expect(await world.cubit.exportJournal(strings), BackupActionResult.cancelled);
  });

  test('a share sheet that never presented answers cancelled, not failed', () async {
    final world = await build();
    await world.cubit.load();
    world.share.throwOnShare = true;
    expect(await world.cubit.exportJournal(strings), BackupActionResult.cancelled);
    expect(world.cubit.state.busy, BackupBusy.none);
  });

  test('a stale stored format resolves at load and still exports', () async {
    final world = await build();
    await world.settings.setFormatId('gone');
    await world.cubit.load();
    expect(world.cubit.state.formatId, 'markdown');
    expect(await world.cubit.exportJournal(strings), BackupActionResult.shared);
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

  test('probe answers the kind, name and size of the picked file', () async {
    final world = await build();
    await world.cubit.load();
    await world.cubit.exportArchive();
    final archive = world.share.captured.last;
    final probe = await world.cubit.probeArchive(archive);
    expect(probe!.kind, ArchiveKind.plainZip);
    expect(probe.fileName, archive.split('/').last);
    expect(probe.sizeBytes, greaterThan(0));
  });

  test('probe answers null for a vanished file instead of throwing', () async {
    final world = await build();
    expect(await world.cubit.probeArchive('${temp.path}/gone.zip'), isNull);
  });

  test('an import round-trips and answers its summary', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    await world.cubit.exportArchive();
    final archive = world.share.captured.last;

    final outcome = await world.cubit.importArchive(archive);
    expect(outcome!.resolution, ImportResolution.success);
    expect(outcome.summary!.entriesUnchanged, 1);
    expect(world.cubit.state.busy, BackupBusy.none);
  });

  test('a wrong passphrase asks for a retry', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    await world.cubit.exportArchive(passphrase: 'right');
    final archive = world.share.captured.last;

    final outcome = await world.cubit.importArchive(archive, passphrase: 'wrong');
    expect(outcome!.resolution, ImportResolution.retryPassphrase);
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
    await world.cubit.exportJournal(strings);
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
    final first = world.cubit.exportJournal(strings);
    expect(await world.cubit.exportArchive(), BackupActionResult.cancelled);
    expect(await first, BackupActionResult.shared);
  });

  test('an import that adds entries re-measures the entry count', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    await world.cubit.exportArchive();
    final archive = world.share.captured.last;
    await world.store.delete('e1');
    await world.cubit.load();
    expect(world.cubit.state.entryCount, 0);
    await world.cubit.importArchive(archive);
    await pumpEventQueue();
    expect(world.cubit.state.entryCount, 1);
  });

  test('a sealed archive imports under its passphrase at the cubit level', () async {
    final world = await build();
    await world.store.save(entry('e1'));
    await world.cubit.load();
    await world.cubit.exportArchive(passphrase: 'open sesame');
    final archive = world.share.captured.last;
    expect((await world.cubit.probeArchive(archive))!.kind, ArchiveKind.sealed);
    final outcome = await world.cubit.importArchive(archive, passphrase: 'open sesame');
    expect(outcome!.resolution, ImportResolution.success);
  });

  test('an unreadable source fails plainly, never as stopped partway', () async {
    final world = await build();
    await world.cubit.load();
    final outcome = await world.cubit.importArchive('${temp.path}/vanished.zip');
    expect(outcome!.resolution, ImportResolution.failed);
    expect(world.cubit.state.busy, BackupBusy.none);
  });

  test('a failure once adoption is writing resolves stopped partway', () async {
    final world = await build();
    final recordings = Directory('${temp.path}/recordings');
    await File('${recordings.path}/otr-1.m4a').writeAsBytes(List<int>.generate(64, (i) => i));
    await world.store.save(
      Entry(
        id: 'e1',
        createdAt: fixedClock,
        audioPath: 'otr-1.m4a',
        duration: const Duration(seconds: 5),
      ),
    );
    await world.cubit.load();
    await world.cubit.exportArchive();
    final archive = world.share.captured.last;
    await recordings.delete(recursive: true);
    final outcome = await world.cubit.importArchive(archive);
    expect(outcome!.resolution, ImportResolution.failedMidway);
    expect(world.cubit.state.busy, BackupBusy.none);
  });

  test('a garbage file fails without touching the journal', () async {
    final world = await build();
    await world.cubit.load();
    final noise = File('${temp.path}/noise.bin');
    await noise.writeAsBytes(List<int>.generate(50, (i) => i));
    final outcome = await world.cubit.importArchive(noise.path);
    expect(outcome!.resolution, ImportResolution.failed);
    expect(world.store.all(), isEmpty);
  });

  test('a bookkeeping failure after a completed share still answers shared', () async {
    final world = await build(wrapSettings: _DateRefusingSettings.new);
    await world.store.save(entry('e1'));
    await world.cubit.load();
    expect(await world.cubit.exportArchive(), BackupActionResult.shared);
    expect(world.cubit.state.busy, BackupBusy.none);
  });
}

class _DateRefusingSettings implements BackupSettings {
  _DateRefusingSettings(this._inner);

  final BackupSettings _inner;

  @override
  String get fallbackFormatId => _inner.fallbackFormatId;

  @override
  String get formatId => _inner.formatId;

  @override
  bool get seal => _inner.seal;

  @override
  DateTime? get lastArchiveAt => _inner.lastArchiveAt;

  @override
  Future<void> setFormatId(String id) => _inner.setFormatId(id);

  @override
  Future<void> setSeal(bool seal) => _inner.setSeal(seal);

  @override
  Future<void> setLastArchiveAt(DateTime at) =>
      throw const FileSystemException('write failed', 'k', OSError('no space', 28));
}
