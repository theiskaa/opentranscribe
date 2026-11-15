import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/export/archive_manifest.dart';
import 'package:opentranscribe/core/export/default_exporter.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/obsidian_exporter.dart';
import 'package:opentranscribe/core/export/staging_registry.dart';
import 'package:opentranscribe/core/export/stored_zip.dart';
import 'package:opentranscribe/core/export/zip_pack.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_merge.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:reflections/reflections.dart';
import 'package:reflections/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

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
    temp = await Directory.systemTemp.createTemp('export_import_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  ({int added, int replaced, int recordings, int reflections}) countsOf(ImportSummary s) => (
    added: s.entriesAdded,
    replaced: s.entriesReplaced,
    recordings: s.recordingsBroughtBack,
    reflections: s.reflectionsUpdated,
  );

  ({int added, int replaced, int recordings, int reflections}) planned(ImportPlan p) =>
      (added: p.added, replaced: p.replaced, recordings: p.recordings, reflections: p.reflections);

  Future<_World> world(
    String name, {
    Duration? Function(String name)? probe,
    Future<void> Function(File file)? deleter,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: key);
    final store = FailingEntryStore(storage);
    final recordings = Directory('${temp.path}/$name-recordings');
    await recordings.create(recursive: true);
    final transcription = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(recordingsDir: recordings.path, probe: probe),
      engine: FakeBatchEngine(),
      store: store,
      clock: () => fixedClock,
      fileDeleter: deleter ?? (f) async => f.deleteSync(),
    );
    final reflectionSettings = ReflectionSettings(storage: storage);
    final reflectionStore = FailingReflectionStore(storage);
    final reflections = ReflectionService(
      engine: FakeReflectionEngine(),
      store: reflectionStore,
      settings: reflectionSettings,
      entries: store.all,
      language: () => 'en-US',
      clock: () => fixedClock,
      weekOf: (d) {
        final day = DateTime(d.year, d.month, d.day);
        return day.subtract(Duration(days: day.weekday - 1));
      },
    );
    final share = FakeShareExport(captureTo: temp);
    final staging = TrackingStagingRegistry();
    final export = ExportService(
      transcription: transcription,
      reflections: reflections,
      exporters: {
        for (final e in const <JournalExporter>[DefaultExporter(), ObsidianExporter()]) e.id: e,
      },
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
    return _World(
      store: store,
      recordings: recordings,
      transcription: transcription,
      reflectionSettings: reflectionSettings,
      reflectionStore: reflectionStore,
      reflections: reflections,
      share: share,
      staging: staging,
      export: export,
      import: import,
    );
  }

  Entry entry(String id, {String? audioPath, String? title, String? text = 'spoken words'}) =>
      Entry(
        id: id,
        createdAt: DateTime.utc(2026, 8, 5, 9),
        audioPath: audioPath,
        duration: const Duration(seconds: 30),
        title: title,
        recordedLocaleId: 'en-US',
        transcript: text == null
            ? null
            : Transcript(
                fullText: text,
                segments: const [],
                localeId: 'en-US',
                engineId: 'fake',
                createdAt: DateTime.utc(2026, 8, 5, 10),
              ),
      );

  Future<void> writeAudio(_World w, String name, List<int> bytes) =>
      File('${w.recordings.path}/$name').writeAsBytes(bytes);

  Future<_World> seededWorld() async {
    final w = await world('a');
    await writeAudio(w, 'otr-1.m4a', List<int>.generate(5000, (i) => i % 251));
    await w.store.save(entry('e1', audioPath: 'otr-1.m4a', title: 'With audio'));
    await w.store.save(entry('e2', title: 'Text only'));
    await w.reflectionStore.save(
      Reflection(
        periodStart: DateTime(2026, 8, 3),
        generatedAt: fixedClock,
        text: 'A steady week.',
      ),
    );
    await w.reflectionStore.delete(DateTime(2026, 7, 27));
    await w.reflectionSettings.setFloorFor(ReflectionPeriod.weekly, DateTime(2026, 7, 6));
    return w;
  }

  Future<String> archiveOf(_World w, {String? passphrase}) async {
    expect(await w.export.shareArchive(passphrase: passphrase), isTrue);
    return w.share.captured.last;
  }

  var twins = 0;

  Future<String> withTwinOfE1(String archive) async {
    final twin = editJson(await archiveEntry(archive, 'entries/e1.json'), (j) => j..['id'] = 'e3');
    final rebuilt = await rewriteArchive(
      archive,
      '${temp.path}/twin-${twins++}.zip',
      add: {'entries/e3.json': twin},
    );
    return rebuilt.path;
  }

  group('shareArchive, then stage and adopt', () {
    test(
      'a plain archive round-trips entries, audio, reflections, tombstones and floors',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a);
        expect(archive, endsWith('.zip'));

        final b = await world('b');
        final summary = await restoreAll(b.import, archive);
        expect(summary.entriesAdded, 2);
        expect(summary.entriesReplaced, 0);

        final restored = {for (final e in b.store.all()) e.id: e};
        expect(restored.keys, containsAll(['e1', 'e2']));
        expect(restored['e1']!.audioPath, 'otr-1.m4a');
        expect(File('${b.recordings.path}/otr-1.m4a').existsSync(), isTrue);
        expect(restored['e2']!.hasAudio, isFalse);
        expect(b.reflectionStore.read(DateTime(2026, 8, 3))?.text, 'A steady week.');
        expect(
          b.reflectionStore.deletedRefs(),
          contains((period: ReflectionPeriod.weekly, start: DateTime(2026, 7, 27))),
        );
        expect(b.reflectionSettings.floorFor(ReflectionPeriod.weekly), DateTime(2026, 7, 6));
      },
    );

    test('an edited entry round-trips through the archive with both texts', () async {
      final a = await world('a');
      await a.store.save(
        entry('e1', title: 'Edited').withRevisions([Revision(text: 'fixed words', at: fixedClock)]),
      );
      final archive = await archiveOf(a);

      final b = await world('b');
      await restoreAll(b.import, archive);

      final restored = b.store.read('e1')!;
      expect(restored.readableText, 'fixed words');
      expect(restored.revisions, [Revision(text: 'fixed words', at: fixedClock)]);
      expect(restored.transcript?.fullText, 'spoken words');
    });

    test('re-importing the same archive changes nothing and stays silent', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await restoreAll(b.import, archive);

      var notified = 0;
      final sub = b.transcription.entriesChanged.listen((_) => notified++);
      final summary = await restoreAll(b.import, archive);
      await pumpEventQueue();
      await sub.cancel();

      expect(summary.entriesAdded, 0);
      expect(summary.entriesReplaced, 0);
      expect(notified, 0);
    });

    test('a sealed archive round-trips under its passphrase', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a, passphrase: 'open sesame');
      expect(archive, endsWith('.otarchive'));

      final b = await world('b');
      final summary = await restoreAll(b.import, archive, passphrase: 'open sesame');
      expect(summary.entriesAdded, 2);
      expect(File('${b.recordings.path}/otr-1.m4a').existsSync(), isTrue);
    });

    test('a wrong passphrase imports nothing', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a, passphrase: 'right');
      final b = await world('b');
      await expectLater(
        restoreAll(b.import, archive, passphrase: 'wrong'),
        throwsA(
          isA<ArchiveException>().having((e) => e.error, 'error', ArchiveError.cannotDecrypt),
        ),
      );
      expect(b.store.all(), isEmpty);
      expect(b.recordings.listSync(), isEmpty);
    });

    test('a sealed archive without a passphrase is refused before any work', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a, passphrase: 'p');
      final b = await world('b');
      await expectLater(restoreAll(b.import, archive), throwsArgumentError);
      expect(b.store.all(), isEmpty);
    });

    test('an archive entry overwrites a differing local entry with the same id', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await b.store.save(entry('e2', title: 'Edited locally'));
      final summary = await restoreAll(b.import, archive);
      expect(summary.entriesReplaced, 1);
      expect(b.store.read('e2')!.title, 'Text only');
    });

    test('an audio basename owned by another entry is restored under a fresh name', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await writeAudio(b, 'otr-1.m4a', [9, 9, 9]);
      await b.store.save(entry('other', audioPath: 'otr-1.m4a', title: 'Owns the name'));

      final summary = await restoreAll(b.import, archive);
      expect(summary.entriesAdded, 2);
      final imported = b.store.read('e1')!;
      expect(imported.audioPath, isNot('otr-1.m4a'));
      expect(File('${b.recordings.path}/${imported.audioPath}').existsSync(), isTrue);
      expect(await File('${b.recordings.path}/otr-1.m4a').readAsBytes(), [9, 9, 9]);
    });

    test('re-importing a renamed-audio archive keeps the name it already got', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await writeAudio(b, 'otr-1.m4a', [9, 9, 9]);
      await b.store.save(entry('other', audioPath: 'otr-1.m4a', title: 'Owns the name'));

      await restoreAll(b.import, archive);
      final firstName = b.store.read('e1')!.audioPath;
      final second = await restoreAll(b.import, archive);

      expect(second.entriesReplaced, 0);
      expect(b.store.read('e1')!.audioPath, firstName);
      expect(b.recordings.listSync().map((f) => f.path.split('/').last).toSet(), {
        'otr-1.m4a',
        firstName,
      });
    });

    test(
      'damage inside an entry, its directory intact, fails on the read and changes nothing',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a);
        final bytes = await File(archive).readAsBytes();
        bytes[bytes.length ~/ 2] ^= 0xFF;
        await File(archive).writeAsBytes(bytes);
        final b = await world('b');

        await expectLater(restoreAll(b.import, archive), throwsA(isA<ArchiveException>()));
        expect(b.store.all(), isEmpty);
      },
    );

    test('the audio file replaced by an import is deleted once unreferenced', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await writeAudio(b, 'otr-old.m4a', [1, 2, 3]);
      await b.store.save(entry('e1', audioPath: 'otr-old.m4a', title: 'Old shape'));

      await restoreAll(b.import, archive);
      expect(b.store.read('e1')!.audioPath, 'otr-1.m4a');
      expect(File('${b.recordings.path}/otr-old.m4a').existsSync(), isFalse);
    });

    test('the archive save and import round-trip', () async {
      final a = await world('a');
      await a.store.save(entry('e1'));
      final archive = await archiveOf(a);

      final b = await world('b');
      final summary = await restoreAll(b.import, archive);
      expect(summary.entriesAdded, 1);
      expect(b.store.read('e1'), isNotNull);
    });

    test('a garbage file imports nothing', () async {
      final b = await world('b');
      final noise = File('${temp.path}/noise.bin');
      await noise.writeAsBytes(List<int>.generate(64, (i) => i * 3 % 256));
      await expectLater(
        restoreAll(b.import, noise.path),
        throwsA(isA<ArchiveException>().having((e) => e.error, 'error', ArchiveError.malformed)),
      );
      expect(b.store.all(), isEmpty);
    });

    test('a source that cannot be read fails before anything in the journal changes', () async {
      final b = await world('b');
      await b.store.save(entry('kept'));
      await expectLater(
        restoreAll(b.import, '${temp.path}/missing.zip'),
        throwsA(isA<FileSystemException>()),
      );
      expect(b.store.all().map((e) => e.id), ['kept']);
    });

    test('a failure once adoption is writing escapes as the disk error it was', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await b.recordings.delete(recursive: true);
      await expectLater(restoreAll(b.import, archive), throwsA(isA<FileSystemException>()));
    });

    test('a compressed zip is refused as re-zipped, not corrupt', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final bytes = await File(archive).readAsBytes();
      final end = ByteData.sublistView(bytes, bytes.length - 22);
      final directoryOffset = end.getUint32(16, Endian.little);
      bytes[8] = 8;
      bytes[directoryOffset + 10] = 8;
      final rezipped = File('${temp.path}/rezipped.zip');
      await rezipped.writeAsBytes(bytes);

      final b = await world('b');
      await expectLater(
        restoreAll(b.import, rezipped.path),
        throwsA(
          isA<ArchiveException>().having((e) => e.error, 'error', ArchiveError.unsupportedZip),
        ),
      );
    });

    test('a damaged entry record aborts the whole import', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = await rewriteArchive(
        archive,
        '${temp.path}/damaged.zip',
        edit: (path, bytes) => path == 'entries/e2.json' ? utf8.encode('{"id": 42}') : bytes,
      );

      final b = await world('b');
      await expectLater(
        restoreAll(b.import, rebuilt.path),
        throwsA(isA<ArchiveException>().having((e) => e.error, 'error', ArchiveError.malformed)),
      );
      expect(b.store.all(), isEmpty);
      expect(b.recordings.listSync(), isEmpty);
    });

    test('an entry whose audio the archive lacks lands transcript-only', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = await rewriteArchive(
        archive,
        '${temp.path}/no-audio.zip',
        edit: (path, bytes) => path.startsWith('audio/') ? null : bytes,
      );

      final b = await world('b');
      await restoreAll(b.import, rebuilt.path);
      expect(b.store.read('e1')!.hasAudio, isFalse);
    });

    test('a local floor never moves later', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await b.reflectionSettings.setFloorFor(ReflectionPeriod.weekly, DateTime(2026, 6));
      await restoreAll(b.import, archive);
      expect(b.reflectionSettings.floorFor(ReflectionPeriod.weekly), DateTime(2026, 6));
    });

    test('the import staging directory is cleaned up on success and failure', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a, passphrase: 'p');
      final b = await world('b');
      await restoreAll(b.import, archive, passphrase: 'p');
      await expectLater(
        restoreAll(b.import, archive, passphrase: 'nope'),
        throwsA(isA<ArchiveException>()),
      );
      final imports = b.staging.imports;
      expect(imports, hasLength(2));
      expect(imports.where((p) => Directory(p).existsSync() || b.staging.owns(p)), isEmpty);
    });

    test('an import protects its staging directory before parsing', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await restoreAll(b.import, archive);
      expect(b.share.protectedPaths, isNotEmpty);
    });

    test('an import releases its staging registration even on failure', () async {
      final b = await world('b');
      final tracking = TrackingStagingRegistry();
      final trackedImport = ImportService(
        transcription: b.transcription,
        reflections: b.reflections,
        share: b.share,
        staging: tracking,
      );
      final noise = File('${temp.path}/noise-tracked.bin');
      await noise.writeAsBytes(List<int>.generate(64, (i) => i * 3 % 256));
      await expectLater(restoreAll(trackedImport, noise.path), throwsA(isA<ArchiveException>()));
      expect(tracking.registered, isNotEmpty);
      expect(tracking.owns(tracking.registered.last), isFalse);
    });

    test('an archive row beats a tombstone for the same period start', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = await rewriteArchive(
        archive,
        '${temp.path}/row-and-tombstone.zip',
        edit: (path, bytes) => path == 'manifest.json'
            ? editJson(
                bytes,
                (json) => json..['tombstones'].add({'period': 'weekly', 'start': '2026-08-03'}),
              )
            : bytes,
      );

      final b = await world('b');
      await restoreAll(b.import, rebuilt.path);
      expect(b.reflectionStore.read(DateTime(2026, 8, 3))?.text, 'A steady week.');
    });

    test('a transcript-only archive record never deletes the local recording', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = await rewriteArchive(
        archive,
        '${temp.path}/stripped.zip',
        edit: (path, bytes) => path.startsWith('audio/')
            ? null
            : path == 'entries/e1.json'
            ? editJson(bytes, (json) => json..remove('audioPath'))
            : bytes,
      );

      final b = await world('b');
      await writeAudio(b, 'otr-1.m4a', [7, 7, 7]);
      await b.store.save(entry('e1', audioPath: 'otr-1.m4a', title: 'Local with audio'));
      await restoreAll(b.import, rebuilt.path);
      expect(b.store.read('e1')!.hasAudio, isFalse);
      expect(File('${b.recordings.path}/otr-1.m4a').existsSync(), isTrue);
    });

    test('two records referencing one archived recording both restore', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = await withTwinOfE1(archive);

      final b = await world('b');
      final summary = await restoreAll(b.import, rebuilt);
      expect(summary.entriesAdded, 3);
      final one = b.store.read('e1')!;
      final other = b.store.read('e3')!;
      expect(one.hasAudio, isTrue);
      expect(other.hasAudio, isTrue);
      expect(File('${b.recordings.path}/${one.audioPath}').existsSync(), isTrue);
      expect(File('${b.recordings.path}/${other.audioPath}').existsSync(), isTrue);
    });

    test('an entry whose audio file vanished exports transcript-only with honest counts', () async {
      final a = await seededWorld();
      await a.store.save(entry('e9', audioPath: 'otr-gone.m4a', title: 'Ghost audio'));
      final archive = await archiveOf(a);
      final reader = await StoredZipReader.open(File(archive));
      final manifest = ArchiveManifest.fromJson(
        jsonDecode(utf8.decode(await reader.readBytes('manifest.json'))) as Map<String, dynamic>,
      );
      expect(manifest.counts.audio, 1);
      final ghost =
          jsonDecode(utf8.decode(await reader.readBytes('entries/e9.json')))
              as Map<String, dynamic>;
      expect(ghost.containsKey('audioPath'), isFalse);
      await reader.close();
    });

    test('a legacy absolute audio path archives under its basename', () async {
      final a = await seededWorld();
      final legacy = File('${temp.path}/legacy-take.m4a');
      await legacy.writeAsBytes([1, 2, 3, 4]);
      await a.store.save(entry('e8', audioPath: legacy.path, title: 'Old container'));
      final archive = await archiveOf(a);
      final b = await world('b');
      await restoreAll(b.import, archive);
      final restored = b.store.read('e8')!;
      expect(restored.audioPath, 'legacy-take.m4a');
      expect(File('${b.recordings.path}/legacy-take.m4a').existsSync(), isTrue);
    });
  });

  group('stage, adopt and discard', () {
    Set<String> recordingNames(_World w) =>
        w.recordings.listSync().map((f) => f.path.split('/').last).toSet();

    test(
      'staging writes nothing outside its own directory, which it owns until discarded',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a, passphrase: 'p');
        final b = await world('b');

        final staged = await b.import.stage(archive, passphrase: 'p');
        final staging = b.staging.imports.last;
        expect(b.store.all(), isEmpty);
        expect(b.recordings.listSync(), isEmpty);
        expect(b.reflectionStore.read(DateTime(2026, 8, 3)), isNull);
        expect(Directory(staging).existsSync(), isTrue);
        expect(
          Directory(staging).listSync(recursive: true).where((f) => f.path.endsWith('.zip')),
          isEmpty,
        );
        expect(b.staging.owns(staging), isTrue);

        await b.import.discard(staged);
        expect(Directory(staging).existsSync(), isFalse);
        expect(b.staging.owns(staging), isFalse);
        expect(b.store.all(), isEmpty);
      },
    );

    test('a failed stage leaves no staging behind and nothing owned', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a, passphrase: 'right');
      final b = await world('b');
      await expectLater(
        b.import.stage(archive, passphrase: 'wrong'),
        throwsA(isA<ArchiveException>()),
      );
      final staging = b.staging.imports.last;
      expect(Directory(staging).existsSync(), isFalse);
      expect(b.staging.owns(staging), isFalse);
    });

    test('a journal that holds every entry but lost a reflection plans to bring it back', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await restoreAll(b.import, archive);
      await b.reflectionStore.delete(DateTime(2026, 8, 3));

      final staged = await b.import.stage(archive);
      expect(staged.plan, const ImportPlan(added: 0, replaced: 0, unchanged: 2, reflections: 1));
      expect(staged.plan.isEmpty, isFalse);
      await b.import.adopt(staged);
      await b.import.discard(staged);
      expect(b.reflectionStore.read(DateTime(2026, 8, 3))?.text, 'A steady week.');

      final again = await b.import.stage(archive);
      expect(again.plan.isEmpty, isTrue);
      await b.import.discard(again);
    });

    test('a recording missing here plans to come back, lands, and then plans nothing', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await restoreAll(b.import, archive);
      await File('${b.recordings.path}/otr-1.m4a').delete();

      final staged = await b.import.stage(archive);
      expect(staged.plan, const ImportPlan(added: 0, replaced: 0, unchanged: 1, recordings: 1));
      expect(staged.plan.changesNothingSeen, isFalse);
      final summary = await b.import.adopt(staged);
      await b.import.discard(staged);
      expect(countsOf(summary), planned(staged.plan));
      expect(File('${b.recordings.path}/otr-1.m4a').existsSync(), isTrue);
      expect(b.store.read('e1')!.audioPath, 'otr-1.m4a');

      final again = await b.import.stage(archive);
      expect(again.plan.isEmpty, isTrue);
      await b.import.discard(again);
    });

    test(
      'a reflection the backup erased but this journal still holds is erased and counted',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a);
        final b = await world('b');
        await restoreAll(b.import, archive);
        await b.reflectionStore.save(
          Reflection(
            periodStart: DateTime(2026, 7, 27),
            generatedAt: fixedClock,
            text: 'Kept here.',
          ),
        );

        final staged = await b.import.stage(archive);
        expect(staged.plan.reflections, 1);
        final summary = await b.import.adopt(staged);
        await b.import.discard(staged);
        expect(summary.reflectionsUpdated, 1);
        expect(b.reflectionStore.read(DateTime(2026, 7, 27)), isNull);

        final again = await b.import.stage(archive);
        expect(again.plan.isEmpty, isTrue);
        await b.import.discard(again);
      },
    );

    test('a tombstone the archive carries twice counts once', () async {
      final b = await world('b');
      await b.reflectionStore.save(
        Reflection(periodStart: DateTime(2026, 7, 27), generatedAt: fixedClock, text: 'Here.'),
      );
      final twice = ReflectionArchive(
        rows: const [],
        tombstones: [
          (period: ReflectionPeriod.weekly, start: DateTime(2026, 7, 27)),
          (period: ReflectionPeriod.weekly, start: DateTime(2026, 7, 27)),
        ],
        floors: const {},
      );
      expect(b.reflections.planImportedReflections(twice), (visible: 1, state: 0));
    });

    test(
      'reflections that break partway keep their count, and the resume reports the whole',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a);
        final b = await world('b');
        await b.reflectionStore.save(
          Reflection(
            periodStart: DateTime(2026, 7, 27),
            generatedAt: fixedClock,
            text: 'Kept here.',
          ),
        );
        b.reflectionStore.failNextDelete = true;
        var signals = 0;
        final sub = b.reflections.reflectionsChanged.listen((_) => signals++);

        final staged = await b.import.stage(archive);
        expect(staged.plan.reflections, 2);
        await expectLater(b.import.adopt(staged), throwsA(isA<FileSystemException>()));
        await pumpEventQueue();
        expect(signals, 1);
        expect(staged.adoptedSoFar.reflectionsUpdated, 1);
        expect(staged.entriesFinished, isTrue);
        final summary = await b.import.adopt(staged);
        await b.import.discard(staged);
        await sub.cancel();
        expect(summary.reflectionsUpdated, 2);
        expect(summary.entriesAdded, 2);
        expect(b.reflectionStore.read(DateTime(2026, 7, 27)), isNull);

        final again = await b.import.stage(archive);
        expect(again.plan.isEmpty, isTrue);
        await b.import.discard(again);
      },
    );

    test('a row that saved before its save threw still counts as updated', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      b.reflectionStore.failNextSaveAfterRow = true;

      final staged = await b.import.stage(archive);
      await expectLater(b.import.adopt(staged), throwsA(isA<FileSystemException>()));
      expect(staged.adoptedSoFar.reflectionsUpdated, 1);
      expect(b.reflectionStore.read(DateTime(2026, 8, 3))?.text, 'A steady week.');
      final summary = await b.import.adopt(staged);
      await b.import.discard(staged);
      expect(summary.reflectionsUpdated, 1);
    });

    for (final firstLater in [true, false]) {
      test('two records sharing a missing recording bring it back once, '
          '${firstLater ? 'the first' : 'the second'} newer in the store', () async {
        final a = await world('a');
        await writeAudio(a, 'otr-1.m4a', List<int>.generate(256, (i) => i % 200));
        Entry sharer(String id, int hour) => Entry(
          id: id,
          createdAt: DateTime.utc(2026, 8, 5, hour),
          audioPath: 'otr-1.m4a',
          duration: const Duration(seconds: 30),
        );
        await a.store.save(sharer('e1', firstLater ? 10 : 9));
        await a.store.save(sharer('e3', firstLater ? 9 : 10));
        final archive = await archiveOf(a);
        await File('${a.recordings.path}/otr-1.m4a').delete();

        final staged = await a.import.stage(archive);
        expect(staged.plan, const ImportPlan(added: 0, replaced: 0, unchanged: 1, recordings: 1));
        final summary = await a.import.adopt(staged);
        await a.import.discard(staged);
        expect(countsOf(summary), planned(staged.plan));
        expect(recordingNames(a), {'otr-1.m4a'});
        expect(a.store.read('e1')!.audioPath, 'otr-1.m4a');
        expect(a.store.read('e3')!.audioPath, 'otr-1.m4a');
      });
    }

    test(
      'two records sharing one recording travel with one file and restore as unchanged',
      () async {
        final a = await world('a');
        await writeAudio(a, 'otr-1.m4a', List<int>.generate(512, (i) => i % 200));
        await a.store.save(entry('e1', audioPath: 'otr-1.m4a', title: 'First'));
        await a.store.save(entry('e3', audioPath: 'otr-1.m4a', title: 'Shares it'));
        final archive = await archiveOf(a);

        final reader = await StoredZipReader.open(File(archive));
        expect(reader.paths.where((p) => p.startsWith('audio/')), ['audio/otr-1.m4a']);
        await reader.close();
        for (final id in ['e1', 'e3']) {
          final record = jsonDecode(utf8.decode(await archiveEntry(archive, 'entries/$id.json')));
          expect((record as Map<String, dynamic>)['audioPath'], 'otr-1.m4a');
        }

        final staged = await a.import.stage(archive);
        expect(staged.plan.isEmpty, isTrue);
        await a.import.discard(staged);
      },
    );

    test('the plan of an archive into an empty journal adds every entry', () async {
      final a = await seededWorld();
      final b = await world('b');
      final staged = await b.import.stage(await archiveOf(a));
      expect(
        staged.plan,
        const ImportPlan(added: 2, replaced: 0, unchanged: 0, reflections: 1, reflectionState: 2),
      );
      await b.import.discard(staged);
    });

    test(
      'the plan counts what adoption reports for new, identical, edited and renamed records',
      () async {
        final a = await seededWorld();
        await a.store.save(entry('e3', title: 'Third'));
        final archive = await archiveOf(a);
        final b = await world('b');
        await writeAudio(b, 'otr-1.m4a', [9, 9, 9]);
        await b.store.save(entry('other', audioPath: 'otr-1.m4a', title: 'Owns the name'));
        await b.store.save(entry('e2', title: 'Text only'));
        await b.store.save(entry('e3', title: 'Edited here'));

        final first = await b.import.stage(archive);
        expect(
          first.plan,
          const ImportPlan(added: 1, replaced: 1, unchanged: 1, reflections: 1, reflectionState: 2),
        );
        final summary = await b.import.adopt(first);
        await b.import.discard(first);
        expect(countsOf(summary), planned(first.plan));

        final again = await b.import.stage(archive);
        expect(again.plan, const ImportPlan(added: 0, replaced: 0, unchanged: 3));
        final repeat = await b.import.adopt(again);
        await b.import.discard(again);
        expect(countsOf(repeat), planned(again.plan));
      },
    );

    test('a re-import stays a no-op once the stray that forced a rename has gone', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await writeAudio(b, 'otr-1.m4a', [7, 7, 7]);
      await restoreAll(b.import, archive);
      final renamed = b.store.read('e1')!.audioPath!;
      expect(renamed, startsWith(importAudioPrefix));
      await File('${b.recordings.path}/otr-1.m4a').delete();

      final again = await b.import.stage(archive);
      expect(again.plan.isEmpty, isTrue);
      await b.import.discard(again);
      expect(b.store.read('e1')!.audioPath, renamed);
    });

    test(
      'a record at a legacy absolute path restores once onto its bare name, keeping its file',
      () async {
        final a = await world('a');
        await writeAudio(a, 'otr-1.m4a', List<int>.generate(256, (i) => i % 200));
        await a.store.save(
          entry('e3', audioPath: '${a.recordings.path}/otr-1.m4a', title: 'Legacy'),
        );
        final archive = await archiveOf(a);

        final first = await a.import.stage(archive);
        expect(first.plan.replaced, 1);
        expect(first.plan.recordings, 0);
        await a.import.adopt(first);
        await a.import.discard(first);
        expect(a.store.read('e3')!.audioPath, 'otr-1.m4a');
        expect(File('${a.recordings.path}/otr-1.m4a').existsSync(), isTrue);

        final again = await a.import.stage(archive);
        expect(again.plan.isEmpty, isTrue);
        await a.import.discard(again);
      },
    );

    test('a record whose only difference is its kept audio reads as replaced', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await writeAudio(b, 'otr-old.m4a', [1, 2, 3]);
      await b.store.save(entry('e1', audioPath: 'otr-old.m4a', title: 'With audio'));

      final staged = await b.import.stage(archive);
      expect(
        staged.plan,
        const ImportPlan(added: 1, replaced: 1, unchanged: 0, reflections: 1, reflectionState: 2),
      );
      final summary = await b.import.adopt(staged);
      await b.import.discard(staged);
      expect(countsOf(summary), planned(staged.plan));
    });

    test(
      'the plan of two records sharing one recording matches adoption, then reads unchanged',
      () async {
        final a = await seededWorld();
        final archive = await withTwinOfE1(await archiveOf(a));
        final b = await world('b');

        final first = await b.import.stage(archive);
        expect(
          first.plan,
          const ImportPlan(added: 3, replaced: 0, unchanged: 0, reflections: 1, reflectionState: 2),
        );
        final summary = await b.import.adopt(first);
        await b.import.discard(first);
        expect(countsOf(summary), planned(first.plan));
        expect(recordingNames(b), hasLength(2));

        final again = await b.import.stage(archive);
        expect(again.plan, const ImportPlan(added: 0, replaced: 0, unchanged: 3));
        final repeat = await b.import.adopt(again);
        await b.import.discard(again);
        expect(countsOf(repeat), planned(again.plan));
      },
    );

    test(
      'a stray file at the archive name sends the audio to a fresh name a re-import keeps',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a);
        final b = await world('b');
        await writeAudio(b, 'otr-1.m4a', [9, 9, 9]);

        final staged = await b.import.stage(archive);
        final summary = await b.import.adopt(staged);
        await b.import.discard(staged);
        expect(countsOf(summary), planned(staged.plan));
        final restored = b.store.read('e1')!.audioPath!;
        expect(restored, isNot('otr-1.m4a'));
        expect(File('${b.recordings.path}/$restored').lengthSync(), 5000);
        expect(await File('${b.recordings.path}/otr-1.m4a').readAsBytes(), [9, 9, 9]);

        final again = await b.import.stage(archive);
        expect(again.plan, const ImportPlan(added: 0, replaced: 0, unchanged: 2));
        final repeat = await b.import.adopt(again);
        await b.import.discard(again);
        expect(countsOf(repeat), planned(again.plan));
        expect(b.store.read('e1')!.audioPath, restored);
      },
    );

    test(
      'an entry continued onto a newer recording since the backup gets the archive audio anew',
      () async {
        final a = await world('a');
        await writeAudio(a, 'o.m4a', [1, 1, 1]);
        await a.store.save(entry('e1', audioPath: 'o.m4a', title: 'Before'));
        final archive = await archiveOf(a);
        final b = await world('b');
        await writeAudio(b, 'o.m4a', [3, 3]);
        await writeAudio(b, 'y.m4a', [2, 2]);
        await b.store.save(entry('e1', audioPath: 'y.m4a', title: 'Continued'));

        final staged = await b.import.stage(archive);
        expect(staged.plan, const ImportPlan(added: 0, replaced: 1, unchanged: 0));
        final summary = await b.import.adopt(staged);
        await b.import.discard(staged);
        expect(countsOf(summary), planned(staged.plan));
        final restored = b.store.read('e1')!;
        expect(restored.title, 'Before');
        expect(restored.audioPath, isNot(anyOf('o.m4a', 'y.m4a')));
        expect(await File('${b.recordings.path}/${restored.audioPath}').readAsBytes(), [1, 1, 1]);
        expect(await File('${b.recordings.path}/o.m4a').readAsBytes(), [3, 3]);
      },
    );

    test('a replaced recording whose delete fails is never adopted by a later record', () async {
      final a = await world('a');
      await writeAudio(a, 'z.m4a', [1]);
      await writeAudio(a, 'y.m4a', [2]);
      await a.store.save(entry('b', audioPath: 'z.m4a', title: 'B'));
      await a.store.save(entry('c', audioPath: 'y.m4a', title: 'C'));
      final archive = await archiveOf(a);
      final b = await world(
        'b',
        deleter: (f) async {
          if (f.path.endsWith('/y.m4a')) throw const FileSystemException('busy');
          f.deleteSync();
        },
      );
      await writeAudio(b, 'y.m4a', [3]);
      await writeAudio(b, '${importAudioPrefix}k.m4a', [4]);
      await b.store.save(entry('b', audioPath: 'y.m4a', title: 'B'));
      await b.store.save(entry('c', audioPath: '${importAudioPrefix}k.m4a', title: 'C'));

      await restoreAll(b.import, archive);
      expect(b.store.read('b')!.audioPath, 'z.m4a');
      expect(b.store.read('c')!.audioPath, '${importAudioPrefix}k.m4a');
      expect(await File('${b.recordings.path}/y.m4a').readAsBytes(), [3]);
    });

    test('adoption reports its progress after every entry', () async {
      final a = await seededWorld();
      final b = await world('b');
      final staged = await b.import.stage(await archiveOf(a));
      final progress = <(int, int)>[];
      await b.import.adopt(staged, onProgress: (done, total) => progress.add((done, total)));
      await b.import.discard(staged);
      expect(progress, [(1, 2), (2, 2)]);
    });

    test(
      'adopting again after a midway failure lands the same journal a clean restore does',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a);
        final clean = await world('clean');
        final expected = await restoreAll(clean.import, archive);

        final b = await world('b');
        b.store.failOnce.add('e1');
        final staged = await b.import.stage(archive);
        await expectLater(b.import.adopt(staged), throwsA(isA<FileSystemException>()));
        final summary = await b.import.adopt(staged);
        await b.import.discard(staged);

        expect(summary, expected);
        expect(b.store.all(), clean.store.all());
        expect(recordingNames(b), recordingNames(clean));
      },
    );

    test(
      'adopting again after a midway failure keeps the fresh name its audio already landed under',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a);
        final b = await world('b');
        await writeAudio(b, 'otr-1.m4a', [9, 9, 9]);
        await b.store.save(entry('other', audioPath: 'otr-1.m4a', title: 'Owns the name'));
        b.store.failOnce.add('e1');

        final staged = await b.import.stage(archive);
        await expectLater(b.import.adopt(staged), throwsA(isA<FileSystemException>()));
        final summary = await b.import.adopt(staged);
        await b.import.discard(staged);

        expect(summary.entriesAdded, 2);
        final renamed = b.store.read('e1')!.audioPath!;
        expect(renamed, isNot('otr-1.m4a'));
        expect(recordingNames(b), {'otr-1.m4a', renamed});
        expect(await File('${b.recordings.path}/otr-1.m4a').readAsBytes(), [9, 9, 9]);
      },
    );

    test(
      'an entry settled before a midway failure keeps an edit made before the restore runs again',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a);
        final b = await world('b');
        b.store.failOnce.add('e2');

        final staged = await b.import.stage(archive);
        await expectLater(b.import.adopt(staged), throwsA(isA<FileSystemException>()));
        final settled = b.store.read('e1')!;
        expect(staged.adoptedSoFar.entriesAdded, 1);
        expect(File('${b.recordings.path}/otr-1.m4a').existsSync(), isTrue);
        await b.store.save(settled.withTitle('Edited between passes'));

        final summary = await b.import.adopt(staged);
        await b.import.discard(staged);
        expect(b.store.read('e1')!.title, 'Edited between passes');
        expect(b.store.read('e2'), isNotNull);
        expect(summary.entriesAdded, 2);
      },
    );

    test('a recording that vanished between passes leaves the stored record as it was', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await writeAudio(b, 'otr-old.m4a', [1, 2, 3]);
      final local = entry('e1', audioPath: 'otr-old.m4a', title: 'Local take');
      await b.store.save(local);
      b.store.failOnce.add('e1');

      final staged = await b.import.stage(archive);
      await expectLater(b.import.adopt(staged), throwsA(isA<FileSystemException>()));
      await File('${b.recordings.path}/otr-1.m4a').delete();
      final summary = await b.import.adopt(staged);
      await b.import.discard(staged);

      expect(b.store.read('e1'), local);
      expect(File('${b.recordings.path}/otr-old.m4a').existsSync(), isTrue);
      expect(countsOf(summary), (added: 1, replaced: 0, recordings: 0, reflections: 1));
    });

    test('the orphan sweep stands down from the first adoption until the discard', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b', probe: (_) => const Duration(seconds: 30));
      b.store.failOnce.add('e1');

      final staged = await b.import.stage(archive);
      expect(await b.transcription.reconcileOrphans(), 0);
      await expectLater(b.import.adopt(staged), throwsA(isA<FileSystemException>()));
      expect(await b.transcription.reconcileOrphans(), isNull);
      expect(b.store.all().every((e) => e.id == 'e1' || e.id == 'e2'), isTrue);

      final summary = await b.import.adopt(staged);
      expect(summary.entriesAdded, 2);
      expect(await b.transcription.reconcileOrphans(), isNull);
      await b.import.discard(staged);
      expect(await b.transcription.reconcileOrphans(), 0);
      expect(b.store.all().map((e) => e.id).toSet(), {'e1', 'e2'});
      expect(b.store.read('e1')!.audioPath, 'otr-1.m4a');
    });

    test('an orphan sweep that sees a sweep hold taken during its probe saves nothing', () async {
      late _World b;
      SweepHold? hold;
      b = await world(
        'b',
        probe: (_) {
          hold ??= b.transcription.holdSweeps();
          return const Duration(seconds: 30);
        },
      );
      await writeAudio(b, 'otr-orphan.m4a', [4, 5, 6]);

      expect(await b.transcription.reconcileOrphans(), isNull);
      expect(b.store.all(), isEmpty);
      expect(File('${b.recordings.path}/otr-orphan.m4a').existsSync(), isTrue);
      hold!.release();
    });

    test(
      'an orphan sweep that sees a sweep hold taken and released during its probe saves nothing',
      () async {
        late _World b;
        b = await world(
          'b',
          probe: (_) {
            b.transcription.holdSweeps().release();
            return const Duration(seconds: 30);
          },
        );
        await writeAudio(b, 'otr-orphan.m4a', [4, 5, 6]);

        expect(await b.transcription.reconcileOrphans(), isNull);
        expect(b.store.all(), isEmpty);
      },
    );

    test('discarding an abandoned restore deletes what it moved in without a record', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b', probe: (_) => const Duration(seconds: 30));
      b.store.failOnce.add('e1');

      final staged = await b.import.stage(archive);
      await expectLater(b.import.adopt(staged), throwsA(isA<FileSystemException>()));
      expect(recordingNames(b), contains('otr-1.m4a'));
      await b.import.discard(staged);

      expect(recordingNames(b), isNot(contains('otr-1.m4a')));
      expect(await b.transcription.reconcileOrphans(), 0);
      expect(b.store.read('e1'), isNull);
    });

    test('a discard while an adoption runs on the same handle waits for it to land', () async {
      final a = await seededWorld();
      final b = await world('b');
      final staged = await b.import.stage(await archiveOf(a));
      final staging = b.staging.imports.last;

      final adopting = b.import.adopt(staged);
      await b.import.discard(staged);
      final summary = await adopting;
      expect(summary.entriesAdded, 2);
      expect(b.store.read('e1')!.audioPath, 'otr-1.m4a');
      expect(File('${b.recordings.path}/otr-1.m4a').existsSync(), isTrue);
      expect(Directory(staging).existsSync(), isFalse);
      expect(b.staging.owns(staging), isFalse);
    });

    test('a discarded import refuses adoption and discards again quietly', () async {
      final a = await seededWorld();
      final b = await world('b');
      final staged = await b.import.stage(await archiveOf(a));
      await b.import.discard(staged);
      await b.import.discard(staged);
      await expectLater(b.import.adopt(staged), throwsStateError);
      expect(b.store.all(), isEmpty);
    });
  });

  group('shareEntry and shareJournal', () {
    test('a single-note export shares one bare file', () async {
      final a = await seededWorld();
      final done = await a.export.shareEntry(
        'e2',
        exporterId: 'obsidian',
        includeAudio: false,
        strings: strings,
      );
      expect(done, isTrue);
      expect(a.share.sharedPaths.single.single, endsWith('Text only.md'));
    });

    test('an entry export says its files are built only as the share sheet takes them', () async {
      final a = await seededWorld();
      var sharesAtSignal = -1;
      await a.export.shareEntry(
        'e1',
        exporterId: 'obsidian',
        includeAudio: true,
        strings: strings,
        onSharing: () => sharesAtSignal = a.share.sharedPaths.length,
      );
      expect(sharesAtSignal, 0);
      expect(a.share.sharedPaths, hasLength(1));
    });

    test('include audio on a transcript-only entry still shares bare', () async {
      final a = await seededWorld();
      await a.export.shareEntry('e2', exporterId: 'obsidian', includeAudio: true, strings: strings);
      expect(a.share.sharedPaths.single.single, endsWith('Text only.md'));
    });

    test('a multi-file export without audio still zips', () async {
      final a = await seededWorld();
      await a.export.shareEntry(
        'e2',
        exporterId: 'markdown',
        includeAudio: false,
        strings: strings,
      );
      final shared = a.share.captured.last;
      expect(shared, endsWith('2026-08-05-Text only.zip'));
      final reader = await StoredZipReader.open(File(shared));
      expect(reader.paths.toSet(), {'2026-08-05-Text only.md', '2026-08-05-Text only.json'});
      await reader.close();
    });

    test('an entry with audio shares a zip holding the note and the recording', () async {
      final a = await seededWorld();
      await a.export.shareEntry('e1', exporterId: 'obsidian', includeAudio: true, strings: strings);
      final shared = a.share.captured.last;
      expect(shared, endsWith('.zip'));
      final reader = await StoredZipReader.open(File(shared));
      expect(reader.paths, containsAll(['2026-08-05 With audio.md', 'otr-1.m4a']));
      await reader.close();
    });

    test('a journal export zips every entry, audio and reflections', () async {
      final a = await seededWorld();
      await a.export.shareJournal(exporterId: 'markdown', includeAudio: true, strings: strings);
      final reader = await StoredZipReader.open(File(a.share.captured.last));
      expect(
        reader.paths,
        containsAll([
          'entries/2026-08-05-With audio.md',
          'entries/2026-08-05-Text only.md',
          'journal.json',
          'audio/otr-1.m4a',
          'reflections/weekly-2026-08-03.md',
          'reflections.json',
        ]),
      );
      await reader.close();
    });

    test(
      'a journal export reports its pack, then its landing, then the share, the last two once',
      () async {
        final a = await seededWorld();
        final events = <String>[];
        await a.export.shareJournal(
          exporterId: 'markdown',
          includeAudio: true,
          strings: strings,
          onProgress: (_) => events.add('progress'),
          onPackDone: () => events.add('packed'),
          onSharing: () =>
              events.add(a.share.calls.contains('shareFiles') ? 'after the sheet' : 'sharing'),
        );
        expect(events.first, 'progress');
        expect(events.skipWhile((e) => e == 'progress').toList(), ['packed', 'sharing']);
      },
    );

    test('staging is deleted after a completed and a cancelled share', () async {
      final a = await seededWorld();
      await a.export.shareJournal(exporterId: 'markdown', includeAudio: true, strings: strings);
      a.share.shareCompletes = false;
      expect(
        await a.export.shareJournal(exporterId: 'markdown', includeAudio: true, strings: strings),
        isFalse,
      );
      final exports = a.staging.exports;
      expect(exports, hasLength(2));
      expect(exports.where((p) => Directory(p).existsSync() || a.staging.owns(p)), isEmpty);
    });

    test('an unknown exporter id is refused', () async {
      final a = await seededWorld();
      await expectLater(
        a.export.shareJournal(exporterId: 'notion', includeAudio: true, strings: strings),
        throwsArgumentError,
      );
    });

    test('a journal export protects its staging directory before sharing', () async {
      final a = await seededWorld();
      await a.export.shareJournal(exporterId: 'markdown', includeAudio: true, strings: strings);
      expect(a.share.protectedPaths, isNotEmpty);
    });

    test('a journal export without audio stages no recordings', () async {
      final a = await seededWorld();
      await a.export.shareJournal(exporterId: 'markdown', includeAudio: false, strings: strings);
      final reader = await StoredZipReader.open(File(a.share.captured.last));
      try {
        expect(reader.paths.where((p) => p.startsWith('audio/')), isEmpty);
        expect(reader.paths, isNotEmpty);
        for (final path in reader.paths) {
          expect(utf8.decode(await reader.readBytes(path)), isNot(contains('otr-1')));
        }
      } finally {
        await reader.close();
      }
    });

    test(
      'the journal measure counts entries, kept recordings, and their approximate weight',
      () async {
        final a = await seededWorld();
        final measure = await a.export.measure();
        expect(measure.entries, 2);
        expect(measure.recordings, 1);
        expect(measure.approxBytes, greaterThanOrEqualTo(5000));
      },
    );

    test('the measure counts how many entries were created after a given moment', () async {
      final a = await seededWorld();
      await a.store.save(
        Entry(
          id: 'later',
          createdAt: DateTime.utc(2026, 8, 6),
          audioPath: null,
          duration: Duration.zero,
        ),
      );
      final measure = await a.export.measure(since: DateTime.utc(2026, 8, 5, 12));
      expect(measure.newSince, 1);
      expect(measure.since, DateTime.utc(2026, 8, 5, 12));
      expect((await a.export.measure()).since, isNull);
    });

    test(
      'a recording two records share, one by a legacy absolute path, is counted and packed once',
      () async {
        final a = await world('a');
        await writeAudio(a, 'otr-1.m4a', List<int>.generate(4000, (i) => i % 200));
        await a.store.save(entry('e1', audioPath: 'otr-1.m4a', text: null));
        await a.store.save(entry('e3', audioPath: '${a.recordings.path}/otr-1.m4a', text: null));

        final measure = await a.export.measure();
        expect(measure.recordings, 1);
        expect(measure.approxBytes, lessThan(8000));

        final archive = await archiveOf(a);
        final reader = await StoredZipReader.open(File(archive));
        expect(reader.paths.where((p) => p.startsWith('audio/')), ['audio/otr-1.m4a']);
        await reader.close();
        for (final id in ['e1', 'e3']) {
          final record = jsonDecode(utf8.decode(await archiveEntry(archive, 'entries/$id.json')));
          expect((record as Map<String, dynamic>)['audioPath'], 'otr-1.m4a');
        }
      },
    );

    test('a vanished recording leaves the measure, not just the archive', () async {
      final a = await seededWorld();
      await File('${a.recordings.path}/otr-1.m4a').delete();
      final measure = await a.export.measure();
      expect(measure.entries, 2);
      expect(measure.recordings, 0);
    });

    test('a cancelled pack surfaces as aborted and cleans its staging', () async {
      final a = await world('a');
      for (var i = 0; i < 6; i++) {
        await writeAudio(a, 'otr-$i.m4a', List<int>.generate(1 << 15, (b) => b % 200));
        await a.store.save(entry('e$i', audioPath: 'otr-$i.m4a'));
      }
      await expectLater(
        a.export.shareJournal(
          exporterId: 'markdown',
          includeAudio: true,
          strings: strings,
          onProgress: (_) => a.export.cancelShare(),
        ),
        throwsA(isA<ZipPackAborted>()),
      );
      final exports = a.staging.exports;
      expect(exports, isNotEmpty);
      expect(exports.where((p) => Directory(p).existsSync() || a.staging.owns(p)), isEmpty);
      expect(a.share.captured, isEmpty);
    });
  });

  group('probing a picked file', () {
    test('a plain backup probes as a backup, a sealed one goes unpeeked', () async {
      final a = await seededWorld();
      expect((await a.import.probe(await archiveOf(a))).contents, ZipContents.backup);
      final sealedProbe = await a.import.probe(await archiveOf(a, passphrase: 'open sesame'));
      expect(sealedProbe.contents, isNull);
    });

    test('a copy for other apps probes as an export, not a backup', () async {
      final a = await seededWorld();
      await a.export.shareJournal(exporterId: 'markdown', includeAudio: false, strings: strings);
      final probe = await a.import.probe(a.share.captured.last);
      expect(probe.kind, ArchiveKind.plainZip);
      expect(probe.contents, ZipContents.export);
    });

    test('a zip of something else probes as foreign', () async {
      final a = await world('a');
      final zip = File('${temp.path}/photos.zip');
      final writer = await StoredZipWriter.create(zip);
      await writer.addBytes('holiday.jpg', [1, 2, 3]);
      await writer.close();
      expect((await a.import.probe(zip.path)).contents, ZipContents.foreign);
    });

    test('a truncated zip probes as unreadable, never as a copy for other apps', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final bytes = await File(archive).readAsBytes();
      final truncated = File('${temp.path}/truncated.zip');
      await truncated.writeAsBytes(bytes.sublist(0, bytes.length - 64));
      expect((await a.import.probe(truncated.path)).contents, ZipContents.unreadable);
    });

    test('a garbled manifest still marks a backup, which then fails as one when staged', () async {
      final a = await seededWorld();
      final garbled = await rewriteArchive(
        await archiveOf(a),
        '${temp.path}/garbled.zip',
        edit: (path, bytes) => path == 'manifest.json' ? utf8.encode('{not json') : bytes,
      );
      expect((await a.import.probe(garbled.path)).contents, ZipContents.backup);
    });

    test('a zip64 zip, which this app never writes, probes as foreign', () async {
      final a = await world('a');
      final zip = File('${temp.path}/big.zip');
      final writer = await StoredZipWriter.create(zip);
      await writer.addBytes('manifest.json', utf8.encode('{}'));
      await writer.close();
      final bytes = await zip.readAsBytes();
      ByteData.sublistView(bytes).setUint32(bytes.length - 6, 0xffffffff, Endian.little);
      await zip.writeAsBytes(bytes);
      expect((await a.import.probe(zip.path)).contents, ZipContents.foreign);
    });

    test('a compressed zip lists its names, so its manifest decides what it is', () async {
      final a = await world('a');
      final photos = await writeDeflatedZip('${temp.path}/photos.zip', {
        'holiday.jpg': [1, 2, 3],
      });
      expect((await a.import.probe(photos.path)).contents, ZipContents.foreign);
      final notes = await writeDeflatedZip('${temp.path}/notes.zip', {
        'entries/walk.md': utf8.encode('# Walk'),
      });
      expect((await a.import.probe(notes.path)).contents, ZipContents.export);
      final backup = await writeDeflatedZip('${temp.path}/rezipped.zip', {
        'manifest.json': utf8.encode('{}'),
      });
      expect((await a.import.probe(backup.path)).contents, ZipContents.backup);
    });

    test(
      'notes at the top or under entries, or a page at the top, are laid out like an export',
      () {
        expect(looksLikeExport(['2026-08-05 Walk.md']), isTrue);
        expect(looksLikeExport(['Walk after the rain.html', 'audio/otr-1.m4a']), isTrue);
        expect(looksLikeExport(['entries/2026-08-05-Walk.md', 'journal.json']), isTrue);
        expect(looksLikeExport(['index.html', 'style.css']), isTrue);
        expect(looksLikeExport(['docs/readme.md']), isFalse);
        expect(looksLikeExport(['holiday.jpg']), isFalse);
      },
    );
  });

  group('the staging sweep', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('sweep-root-');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('removes an orphaned import directory', () async {
      final registry = StagingRegistry();
      final orphan = await root.createTemp('import-orphan');
      await registry.sweep(root);
      expect(orphan.existsSync(), isFalse);
    });

    test('removes an orphaned export directory', () async {
      final registry = StagingRegistry();
      final orphan = await root.createTemp('export-orphan');
      await registry.sweep(root);
      expect(orphan.existsSync(), isFalse);
    });

    test('leaves a registered staging directory alone, until it is released', () async {
      final registry = StagingRegistry();
      final owned = await root.createTemp('import-');
      registry.register(owned.path);
      await registry.sweep(root);
      expect(owned.existsSync(), isTrue);

      registry.release(owned.path);
      await registry.sweep(root);
      expect(owned.existsSync(), isFalse);
    });

    test('leaves a directory with an unrelated name alone', () async {
      final registry = StagingRegistry();
      final unrelated = await root.createTemp('unrelated-');
      await registry.sweep(root);
      expect(unrelated.existsSync(), isTrue);
    });

    test('the sweep stands down while an operation is open', () async {
      final registry = StagingRegistry();
      registry.begin();
      final orphan = await root.createTemp('import-orphan');
      await registry.sweep(root);
      expect(orphan.existsSync(), isTrue);

      registry.end();
      await registry.sweep(root);
      expect(orphan.existsSync(), isFalse);
    });
  });
}

final class _World {
  const _World({
    required this.store,
    required this.recordings,
    required this.transcription,
    required this.reflectionSettings,
    required this.reflectionStore,
    required this.reflections,
    required this.share,
    required this.staging,
    required this.export,
    required this.import,
  });

  final FailingEntryStore store;
  final Directory recordings;
  final TranscriptionService transcription;
  final ReflectionSettings reflectionSettings;
  final FailingReflectionStore reflectionStore;
  final ReflectionService reflections;
  final FakeShareExport share;
  final TrackingStagingRegistry staging;
  final ExportService export;
  final ImportService import;
}

Future<ImportSummary> restoreAll(ImportService import, String path, {String? passphrase}) async {
  final staged = await import.stage(path, passphrase: passphrase);
  try {
    return await import.adopt(staged);
  } finally {
    await import.discard(staged);
  }
}
