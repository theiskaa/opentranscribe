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
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:reflections/reflections.dart';
import 'package:reflections/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

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
    temp = await Directory.systemTemp.createTemp('export_import_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  Future<_World> world(String name) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: key);
    final store = EntryStore(storage);
    final recordings = Directory('${temp.path}/$name-recordings');
    await recordings.create(recursive: true);
    final transcription = TranscriptionService(
      recorder: FakeAudioRecorder(recordingsDir: recordings.path),
      engine: FakeBatchEngine(),
      store: store,
      clock: () => fixedClock,
      fileDeleter: (f) async => f.deleteSync(),
    );
    final reflectionSettings = ReflectionSettings(storage: storage);
    final reflections = ReflectionService(
      engine: FakeReflectionEngine(),
      store: ReflectionStore(storage),
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
    final staging = StagingRegistry();
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
      reflectionStore: ReflectionStore(storage),
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

  group('shareArchive and importArchive', () {
    test(
      'a plain archive round-trips entries, audio, reflections, tombstones and floors',
      () async {
        final a = await seededWorld();
        final archive = await archiveOf(a);
        expect(archive, endsWith('.zip'));

        final b = await world('b');
        final summary = await b.import.importArchive(archive);
        expect(summary.entriesAdded, 2);
        expect(summary.entriesUpdated, 0);
        expect(summary.audioRestored, 1);
        expect(summary.reflectionChanges, 3);

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
      await b.import.importArchive(archive);

      final restored = b.store.read('e1')!;
      expect(restored.readableText, 'fixed words');
      expect(restored.revisions, [Revision(text: 'fixed words', at: fixedClock)]);
      expect(restored.transcript?.fullText, 'spoken words');
    });

    test('re-importing the same archive changes nothing and stays silent', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await b.import.importArchive(archive);

      var notified = 0;
      final sub = b.transcription.entriesChanged.listen((_) => notified++);
      final summary = await b.import.importArchive(archive);
      await pumpEventQueue();
      await sub.cancel();

      expect(summary.entriesAdded, 0);
      expect(summary.entriesUpdated, 0);
      expect(summary.entriesUnchanged, 2);
      expect(summary.reflectionChanges, 0);
      expect(notified, 0);
    });

    test('a sealed archive round-trips under its passphrase', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a, passphrase: 'open sesame');
      expect(archive, endsWith('.otarchive'));

      final b = await world('b');
      final summary = await b.import.importArchive(archive, passphrase: 'open sesame');
      expect(summary.entriesAdded, 2);
      expect(File('${b.recordings.path}/otr-1.m4a').existsSync(), isTrue);
    });

    test('a wrong passphrase imports nothing', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a, passphrase: 'right');
      final b = await world('b');
      await expectLater(
        b.import.importArchive(archive, passphrase: 'wrong'),
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
      await expectLater(b.import.importArchive(archive), throwsArgumentError);
      expect(b.store.all(), isEmpty);
    });

    test('an archive entry overwrites a differing local entry with the same id', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await b.store.save(entry('e2', title: 'Edited locally'));
      final summary = await b.import.importArchive(archive);
      expect(summary.entriesUpdated, 1);
      expect(b.store.read('e2')!.title, 'Text only');
    });

    test('an audio basename owned by another entry is restored under a fresh name', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await writeAudio(b, 'otr-1.m4a', [9, 9, 9]);
      await b.store.save(entry('other', audioPath: 'otr-1.m4a', title: 'Owns the name'));

      final summary = await b.import.importArchive(archive);
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

      await b.import.importArchive(archive);
      final firstName = b.store.read('e1')!.audioPath;
      final second = await b.import.importArchive(archive);

      expect(second.entriesUpdated, 0);
      expect(second.entriesUnchanged, 2);
      expect(b.store.read('e1')!.audioPath, firstName);
      expect(b.recordings.listSync().map((f) => f.path.split('/').last).toSet(), {
        'otr-1.m4a',
        firstName,
      });
    });

    test('a damaged archive fails as unreadable, never as a partial restore', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final bytes = await File(archive).readAsBytes();
      // Inside an entry's data, so the central directory and EOCD still parse
      // and the damage only surfaces on the CRC of a read.
      bytes[bytes.length ~/ 2] ^= 0xFF;
      await File(archive).writeAsBytes(bytes);
      final b = await world('b');

      await expectLater(b.import.importArchive(archive), throwsA(isA<ArchiveException>()));
      expect(b.store.all(), isEmpty);
    });

    test('the audio file replaced by an import is deleted once unreferenced', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await writeAudio(b, 'otr-old.m4a', [1, 2, 3]);
      await b.store.save(entry('e1', audioPath: 'otr-old.m4a', title: 'Old shape'));

      await b.import.importArchive(archive);
      expect(b.store.read('e1')!.audioPath, 'otr-1.m4a');
      expect(File('${b.recordings.path}/otr-old.m4a').existsSync(), isFalse);
    });

    test('a garbage file imports nothing', () async {
      final b = await world('b');
      final noise = File('${temp.path}/noise.bin');
      await noise.writeAsBytes(List<int>.generate(64, (i) => i * 3 % 256));
      await expectLater(
        b.import.importArchive(noise.path),
        throwsA(isA<ArchiveException>().having((e) => e.error, 'error', ArchiveError.malformed)),
      );
      expect(b.store.all(), isEmpty);
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
        b.import.importArchive(rezipped.path),
        throwsA(
          isA<ArchiveException>().having((e) => e.error, 'error', ArchiveError.unsupportedZip),
        ),
      );
    });

    test('a damaged entry record aborts the whole import', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = File('${temp.path}/damaged.zip');
      final reader = await StoredZipReader.open(File(archive));
      final writer = await StoredZipWriter.create(rebuilt);
      for (final path in reader.paths) {
        if (path == 'entries/e2.json') {
          await writer.addBytes(path, utf8.encode('{"id": 42}'));
        } else {
          await writer.addBytes(path, await reader.readBytes(path));
        }
      }
      await writer.close();
      await reader.close();

      final b = await world('b');
      await expectLater(
        b.import.importArchive(rebuilt.path),
        throwsA(isA<ArchiveException>().having((e) => e.error, 'error', ArchiveError.malformed)),
      );
      expect(b.store.all(), isEmpty);
      expect(b.recordings.listSync(), isEmpty);
    });

    test('an entry whose audio the archive lacks lands transcript-only', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = File('${temp.path}/no-audio.zip');
      final reader = await StoredZipReader.open(File(archive));
      final writer = await StoredZipWriter.create(rebuilt);
      for (final path in reader.paths) {
        if (path.startsWith('audio/')) continue;
        await writer.addBytes(path, await reader.readBytes(path));
      }
      await writer.close();
      await reader.close();

      final b = await world('b');
      await b.import.importArchive(rebuilt.path);
      expect(b.store.read('e1')!.hasAudio, isFalse);
    });

    test('a local floor never moves later', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await b.reflectionSettings.setFloorFor(ReflectionPeriod.weekly, DateTime(2026, 6));
      await b.import.importArchive(archive);
      expect(b.reflectionSettings.floorFor(ReflectionPeriod.weekly), DateTime(2026, 6));
    });

    test('the import staging directory is cleaned up on success and failure', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a, passphrase: 'p');
      final b = await world('b');
      await b.import.importArchive(archive, passphrase: 'p');
      await expectLater(
        b.import.importArchive(archive, passphrase: 'nope'),
        throwsA(isA<ArchiveException>()),
      );
      final leftovers = Directory.systemTemp.listSync().whereType<Directory>().where(
        (d) => d.path.split('/').last.startsWith('import-'),
      );
      expect(leftovers, isEmpty);
    });

    test('an import protects its staging directory before parsing', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final b = await world('b');
      await b.import.importArchive(archive);
      expect(b.share.protectedPaths, isNotEmpty);
    });

    test('an import releases its staging registration even on failure', () async {
      final b = await world('b');
      final tracking = _TrackingStagingRegistry();
      final trackedImport = ImportService(
        transcription: b.transcription,
        reflections: b.reflections,
        share: b.share,
        staging: tracking,
      );
      final noise = File('${temp.path}/noise-tracked.bin');
      await noise.writeAsBytes(List<int>.generate(64, (i) => i * 3 % 256));
      await expectLater(trackedImport.importArchive(noise.path), throwsA(isA<ArchiveException>()));
      expect(tracking.registered, isNotEmpty);
      expect(tracking.owns(tracking.registered.last), isFalse);
    });

    test('an archive row beats a tombstone for the same period start', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = File('${temp.path}/row-and-tombstone.zip');
      final reader = await StoredZipReader.open(File(archive));
      final writer = await StoredZipWriter.create(rebuilt);
      for (final path in reader.paths) {
        var bytes = await reader.readBytes(path);
        if (path == 'manifest.json') {
          final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          (json['tombstones'] as List).add({'period': 'weekly', 'start': '2026-08-03'});
          bytes = utf8.encode(jsonEncode(json));
        }
        await writer.addBytes(path, bytes);
      }
      await writer.close();
      await reader.close();

      final b = await world('b');
      await b.import.importArchive(rebuilt.path);
      expect(b.reflectionStore.read(DateTime(2026, 8, 3))?.text, 'A steady week.');
    });

    test('a transcript-only archive record never deletes the local recording', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = File('${temp.path}/stripped.zip');
      final reader = await StoredZipReader.open(File(archive));
      final writer = await StoredZipWriter.create(rebuilt);
      for (final path in reader.paths) {
        if (path.startsWith('audio/')) continue;
        var bytes = await reader.readBytes(path);
        if (path == 'entries/e1.json') {
          final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>..remove('audioPath');
          bytes = utf8.encode(jsonEncode(json));
        }
        await writer.addBytes(path, bytes);
      }
      await writer.close();
      await reader.close();

      final b = await world('b');
      await writeAudio(b, 'otr-1.m4a', [7, 7, 7]);
      await b.store.save(entry('e1', audioPath: 'otr-1.m4a', title: 'Local with audio'));
      await b.import.importArchive(rebuilt.path);
      expect(b.store.read('e1')!.hasAudio, isFalse);
      expect(File('${b.recordings.path}/otr-1.m4a').existsSync(), isTrue);
    });

    test('two records referencing one archived recording both restore', () async {
      final a = await seededWorld();
      final archive = await archiveOf(a);
      final rebuilt = File('${temp.path}/shared-audio.zip');
      final reader = await StoredZipReader.open(File(archive));
      final writer = await StoredZipWriter.create(rebuilt);
      for (final path in reader.paths) {
        await writer.addBytes(path, await reader.readBytes(path));
      }
      final twin =
          jsonDecode(utf8.decode(await reader.readBytes('entries/e1.json'))) as Map<String, dynamic>
            ..['id'] = 'e3';
      await writer.addBytes('entries/e3.json', utf8.encode(jsonEncode(twin)));
      await writer.close();
      await reader.close();

      final b = await world('b');
      final summary = await b.import.importArchive(rebuilt.path);
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
      await b.import.importArchive(archive);
      final restored = b.store.read('e8')!;
      expect(restored.audioPath, 'legacy-take.m4a');
      expect(File('${b.recordings.path}/legacy-take.m4a').existsSync(), isTrue);
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
      await a.export.shareJournal(exporterId: 'markdown', strings: strings);
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

    test('staging is deleted after a completed and a cancelled share', () async {
      final a = await seededWorld();
      await a.export.shareJournal(exporterId: 'markdown', strings: strings);
      a.share.shareCompletes = false;
      expect(await a.export.shareJournal(exporterId: 'markdown', strings: strings), isFalse);
      final leftovers = Directory.systemTemp.listSync().whereType<Directory>().where(
        (d) => d.path.split('/').last.startsWith('export-'),
      );
      expect(leftovers, isEmpty);
    });

    test('an unknown exporter id is refused', () async {
      final a = await seededWorld();
      await expectLater(
        a.export.shareJournal(exporterId: 'notion', strings: strings),
        throwsArgumentError,
      );
    });

    test('a journal export protects its staging directory before sharing', () async {
      final a = await seededWorld();
      await a.export.shareJournal(exporterId: 'markdown', strings: strings);
      expect(a.share.protectedPaths, isNotEmpty);
    });
  });

  group('the staging sweep', () {
    test('removes an orphaned import directory', () async {
      final registry = StagingRegistry();
      final orphan = await Directory.systemTemp.createTemp('import-orphan');
      await registry.sweep(Directory.systemTemp);
      expect(orphan.existsSync(), isFalse);
    });

    test('removes an orphaned export directory', () async {
      final registry = StagingRegistry();
      final orphan = await Directory.systemTemp.createTemp('export-orphan');
      await registry.sweep(Directory.systemTemp);
      expect(orphan.existsSync(), isFalse);
    });

    test('leaves a registered staging directory alone, until it is released', () async {
      final registry = StagingRegistry();
      final owned = await Directory.systemTemp.createTemp('import-');
      registry.register(owned.path);
      await registry.sweep(Directory.systemTemp);
      expect(owned.existsSync(), isTrue);

      registry.release(owned.path);
      await registry.sweep(Directory.systemTemp);
      expect(owned.existsSync(), isFalse);
    });

    test('leaves a directory with an unrelated name alone', () async {
      final registry = StagingRegistry();
      final unrelated = await Directory.systemTemp.createTemp('unrelated-');
      try {
        await registry.sweep(Directory.systemTemp);
        expect(unrelated.existsSync(), isTrue);
      } finally {
        await unrelated.delete(recursive: true);
      }
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

  final EntryStore store;
  final Directory recordings;
  final TranscriptionService transcription;
  final ReflectionSettings reflectionSettings;
  final ReflectionStore reflectionStore;
  final ReflectionService reflections;
  final FakeShareExport share;
  final StagingRegistry staging;
  final ExportService export;
  final ImportService import;
}

final class _TrackingStagingRegistry extends StagingRegistry {
  final List<String> registered = [];

  @override
  void register(String path) {
    registered.add(path);
    super.register(path);
  }
}
