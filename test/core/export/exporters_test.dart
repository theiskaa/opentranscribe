import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/export/default_exporter.dart';
import 'package:opentranscribe/core/export/export_helpers.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/obsidian_exporter.dart';
import 'package:opentranscribe/core/export/stored_zip.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';

void main() {
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
  final context = ExportContext(
    strings: strings,
    generatedAt: DateTime.utc(2026, 8, 7, 12),
    appVersion: '0.1.0',
  );

  Entry entry({
    String id = 'e1',
    DateTime? createdAt,
    String? title = 'Morning walk',
    String? audioPath = 'otr-1.m4a',
    String? text = 'went for a walk. it was quiet.',
  }) => Entry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 8, 7, 9, 30),
    audioPath: audioPath,
    duration: const Duration(minutes: 3, seconds: 24),
    title: title,
    recordedLocaleId: 'en-US',
    transcript: text == null
        ? null
        : Transcript(
            fullText: text,
            segments: [
              const TranscriptSegment(
                text: 'walk.',
                start: Duration(seconds: 3),
                end: Duration(seconds: 4),
              ),
              const TranscriptSegment(
                text: 'quiet.',
                start: Duration(seconds: 70),
                end: Duration(seconds: 74),
              ),
            ],
            localeId: 'en-US',
            engineId: 'fake',
            createdAt: DateTime.utc(2026, 8, 7, 10),
          ),
  );

  Reflection reflection({String? text = 'You walked and it settled you.'}) => Reflection(
    periodStart: DateTime(2026, 8, 3),
    generatedAt: DateTime.utc(2026, 8, 9, 18),
    text: text,
  );

  String textOf(List<ExportFile> files, String path) =>
      utf8.decode(files.firstWhere((f) => f.path == path).bytes);

  group('exportClock', () {
    test('formats minutes and hours, clamping negatives', () {
      expect(exportClock(Duration.zero), '0:00');
      expect(exportClock(const Duration(seconds: 64)), '1:04');
      expect(exportClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(exportClock(const Duration(seconds: -90)), '0:00');
    });
  });

  group('yamlScalar', () {
    test('wraps a plain value in quotes', () {
      expect(yamlScalar('en-US'), '"en-US"');
      expect(yamlScalar(''), '""');
    });

    test('escapes the characters that would end the scalar', () {
      expect(yamlScalar(r'a"b'), r'"a\"b"');
      expect(yamlScalar(r'a\b'), r'"a\\b"');
      expect(yamlScalar(r'a\"b'), r'"a\\\"b"');
    });

    test('a value carrying a line break cannot open a line of its own', () {
      expect(yamlScalar('a\nb'), r'"a\nb"');
      expect(yamlScalar('a\r\n---\nb'), r'"a\r\n---\nb"');
      expect(yamlScalar('a\u2028b'), r'"a\u2028b"');
      expect(yamlScalar('a\u0085b'), r'"a\u0085b"');
    });

    test('escapes control characters, which a quoted scalar may not carry raw', () {
      expect(yamlScalar('a\u0000b'), r'"a\u0000b"');
      expect(yamlScalar('a\tb'), r'"a\tb"');
      expect(yamlScalar('a\u007fb'), r'"a\u007fb"');
    });

    test('leaves text outside the ascii range alone', () {
      expect(yamlScalar('走った日 cafe'), '"走った日 cafe"');
    });
  });

  group('DefaultExporter', () {
    const exporter = DefaultExporter();

    test('a single entry becomes a markdown file and a json sidecar', () {
      final source = entry();
      final files = exporter.exportEntry(
        ExportEntry(entry: source, audioRelativePath: 'audio/otr-1.m4a'),
        context,
      );
      expect(files.map((f) => f.path), [
        '2026-08-07-Morning walk.md',
        '2026-08-07-Morning walk.json',
      ]);
      expect(
        textOf(files, '2026-08-07-Morning walk.md'),
        startsWith(
          '---\n'
          'created: ${source.createdAt.toUtc().toIso8601String()}\n'
          'duration: "3:24"\n'
          'locale: "en-US"\n'
          'audio: "audio/otr-1.m4a"\n'
          '---\n'
          '\n'
          '# Morning walk\n'
          '\n'
          '## Transcript\n',
        ),
      );
    });

    test('a single entry names its audio as it sits beside the note', () {
      final files = exporter.exportEntry(
        ExportEntry(entry: entry(), audioRelativePath: 'otr-1.m4a'),
        context,
      );
      expect(textOf(files, '2026-08-07-Morning walk.md'), contains('audio: "otr-1.m4a"'));
    });

    test('a journal note names its audio relative to itself, not to the export root', () {
      final files = exporter.exportJournal(
        ExportSnapshot(
          entries: [ExportEntry(entry: entry(), audioRelativePath: 'audio/otr-1.m4a')],
        ),
        context,
      );
      final md = textOf(files, 'entries/2026-08-07-Morning walk.md');
      expect(md, contains('audio: "../audio/otr-1.m4a"'));
    });

    test('the transcript is the text the engine wrote, never rebuilt from its segments', () {
      final files = exporter.exportEntry(ExportEntry(entry: entry()), context);
      final md = textOf(files, '2026-08-07-Morning walk.md');
      expect(md, contains('went for a walk. it was quiet.'));
      expect(md, isNot(contains('[0:03]')));
      expect(md, isNot(contains('[1:10]')));
    });

    test('the json sidecar round-trips through Entry.fromJson with the exported audio path', () {
      final source = entry();
      final files = exporter.exportEntry(
        ExportEntry(entry: source, audioRelativePath: 'audio/otr-1.m4a'),
        context,
      );
      final decoded = Entry.fromJson(
        jsonDecode(textOf(files, '2026-08-07-Morning walk.json')) as Map<String, dynamic>,
      );
      expect(decoded.audioPath, 'audio/otr-1.m4a');
      expect(decoded.id, source.id);
      expect(decoded.transcript, source.transcript);
      expect(decoded.createdAt, source.createdAt);
    });

    test('an export without audio carries no audio link and no audio path', () {
      final files = exporter.exportEntry(ExportEntry(entry: entry()), context);
      expect(textOf(files, '2026-08-07-Morning walk.md'), isNot(contains('audio:')));
      final json = jsonDecode(textOf(files, '2026-08-07-Morning walk.json')) as Map;
      expect(json.containsKey('audioPath'), isFalse);
    });

    test('an untitled entry falls back to the untitled string', () {
      final files = exporter.exportEntry(ExportEntry(entry: entry(title: null)), context);
      expect(files.first.path, '2026-08-07-Untitled.md');
      expect(utf8.decode(files.first.bytes), contains('# Untitled'));
    });

    test('an untranscribed entry gets no transcript section', () {
      final files = exporter.exportEntry(ExportEntry(entry: entry(text: null)), context);
      expect(utf8.decode(files.first.bytes), isNot(contains('## Transcript')));
    });

    test('a journal export writes every entry, journal json and reflections', () {
      final files = exporter.exportJournal(
        ExportSnapshot(
          entries: [ExportEntry(entry: entry(), audioRelativePath: 'audio/otr-1.m4a')],
          reflections: [reflection()],
        ),
        context,
      );
      expect(files.map((f) => f.path), [
        'entries/2026-08-07-Morning walk.md',
        'journal.json',
        'reflections/weekly-2026-08-03.md',
        'reflections.json',
      ]);
      final journal = jsonDecode(textOf(files, 'journal.json')) as Map<String, dynamic>;
      expect(journal['appVersion'], '0.1.0');
      expect(journal['entries'], hasLength(1));
      expect(textOf(files, 'reflections/weekly-2026-08-03.md'), contains('# Week 2026-08-03'));
    });

    test('colliding titles on one day get numbered files', () {
      final files = exporter.exportJournal(
        ExportSnapshot(
          entries: [
            ExportEntry(entry: entry(id: 'a')),
            ExportEntry(entry: entry(id: 'b')),
          ],
        ),
        context,
      );
      expect(
        files.map((f) => f.path),
        containsAll(['entries/2026-08-07-Morning walk.md', 'entries/2026-08-07-Morning walk-2.md']),
      );
    });

    test('a silent reflection reads as the quiet string', () {
      final files = exporter.exportJournal(
        ExportSnapshot(entries: [], reflections: [reflection(text: null)]),
        context,
      );
      expect(textOf(files, 'reflections/weekly-2026-08-03.md'), contains('A quiet stretch.'));
    });

    test('the same input produces identical bytes', () {
      final snapshot = ExportSnapshot(
        entries: [ExportEntry(entry: entry(), audioRelativePath: 'audio/otr-1.m4a')],
        reflections: [reflection()],
      );
      final first = exporter.exportJournal(snapshot, context);
      final second = exporter.exportJournal(snapshot, context);
      for (var i = 0; i < first.length; i++) {
        expect(first[i].bytes, second[i].bytes);
      }
    });

    test('a journal without reflections emits no reflection files', () {
      final files = exporter.exportJournal(
        ExportSnapshot(entries: [ExportEntry(entry: entry())]),
        context,
      );
      expect(files.map((f) => f.path), ['entries/2026-08-07-Morning walk.md', 'journal.json']);
    });

    test('journal json stamps the context moment', () {
      final files = exporter.exportJournal(ExportSnapshot(entries: []), context);
      final journal = jsonDecode(textOf(files, 'journal.json')) as Map<String, dynamic>;
      expect(journal['generatedAt'], '2026-08-07T12:00:00.000Z');
    });

    test('a multi-line title flattens into its heading', () {
      final files = exporter.exportEntry(
        ExportEntry(entry: entry(title: 'first line\nsecond line')),
        context,
      );
      expect(utf8.decode(files.first.bytes), contains('# first line second line'));
    });
  });

  group('ObsidianExporter', () {
    const exporter = ObsidianExporter();

    test('an entry becomes one note with frontmatter and an audio embed', () {
      final source = entry();
      final files = exporter.exportEntry(
        ExportEntry(entry: source, audioRelativePath: 'audio/otr-1.m4a'),
        context,
      );
      expect(files, hasLength(1));
      final note = utf8.decode(files.single.bytes);
      expect(files.single.path, '2026-08-07 Morning walk.md');
      expect(note, startsWith('---\n'));
      expect(note, contains('id: "e1"'));
      expect(note, contains('created: ${source.createdAt.toIso8601String()}'));
      expect(note, contains('locale: "en-US"'));
      expect(note, contains('- opentranscribe'));
      expect(note, contains('![[otr-1.m4a]]'));
      expect(note, contains('went for a walk. it was quiet.'));
    });

    test('an entry note carries no heading, since obsidian titles it by file name', () {
      final files = exporter.exportEntry(ExportEntry(entry: entry()), context);
      expect(utf8.decode(files.single.bytes), isNot(contains('# Morning walk')));
    });

    test('a title the file name cannot hold survives in the frontmatter', () {
      final files = exporter.exportEntry(ExportEntry(entry: entry(title: '###')), context);
      expect(files.single.path, '2026-08-07.md');
      expect(utf8.decode(files.single.bytes), contains(r'title: "###"'));
    });

    test('an untitled entry claims no title of its own', () {
      final files = exporter.exportEntry(ExportEntry(entry: entry(title: null)), context);
      expect(utf8.decode(files.single.bytes), isNot(contains('title:')));
    });

    test('a transcript-only entry embeds nothing', () {
      final files = exporter.exportEntry(ExportEntry(entry: entry(audioPath: null)), context);
      expect(utf8.decode(files.single.bytes), isNot(contains('![[')));
    });

    test('a title with quotes and colons stays inside its yaml scalar', () {
      final files = exporter.exportEntry(
        ExportEntry(
          entry: entry(id: 'q:1"x', title: 'On "rest": a note'),
        ),
        context,
      );
      expect(utf8.decode(files.single.bytes), contains(r'id: "q:1\"x"'));
    });

    test('a reflection note wikilinks the entry notes of its period', () {
      final inWeek = entry(id: 'a', createdAt: DateTime(2026, 8, 4, 9));
      final outsideWeek = entry(id: 'b', createdAt: DateTime(2026, 7, 20, 9));
      final files = exporter.exportJournal(
        ExportSnapshot(
          entries: [
            ExportEntry(entry: inWeek),
            ExportEntry(entry: outsideWeek),
          ],
          reflections: [reflection()],
        ),
        context,
      );
      final note = textOf(files, 'reflections/weekly 2026-08-03.md');
      expect(note, contains('# Week 2026-08-03'));
      expect(note, contains('You walked and it settled you.'));
      expect(note, contains('- [[2026-08-04 Morning walk]]'));
      expect(note, isNot(contains('2026-07-20')));
    });

    test('journal notes live under entries with unique names', () {
      final files = exporter.exportJournal(
        ExportSnapshot(
          entries: [
            ExportEntry(entry: entry(id: 'a')),
            ExportEntry(entry: entry(id: 'b')),
          ],
        ),
        context,
      );
      expect(files.map((f) => f.path), [
        'entries/2026-08-07 Morning walk.md',
        'entries/2026-08-07 Morning walk-2.md',
      ]);
    });

    test('the same input produces identical bytes', () {
      final snapshot = ExportSnapshot(
        entries: [ExportEntry(entry: entry(), audioRelativePath: 'audio/otr-1.m4a')],
        reflections: [reflection()],
      );
      final first = exporter.exportJournal(snapshot, context);
      final second = exporter.exportJournal(snapshot, context);
      for (var i = 0; i < first.length; i++) {
        expect(first[i].bytes, second[i].bytes);
      }
    });

    test('link-reserved characters never reach note names or wikilinks', () {
      final files = exporter.exportJournal(
        ExportSnapshot(
          entries: [
            ExportEntry(
              entry: entry(id: 'a', title: 'Walk #2 [[me]] ^x'),
            ),
          ],
          reflections: [reflection()],
        ),
        context,
      );
      final names = files.map((f) => f.path).toList();
      expect(names.first, 'entries/2026-08-07 Walk 2 me x.md');
      final note = textOf(files, 'reflections/weekly 2026-08-03.md');
      expect(note, contains('- [[2026-08-07 Walk 2 me x]]'));
    });

    test('an untitled entry gets the fallback name and no heading', () {
      final files = exporter.exportEntry(ExportEntry(entry: entry(title: null)), context);
      expect(files.single.path, '2026-08-07 Untitled.md');
      expect(utf8.decode(files.single.bytes), isNot(contains('\n# ')));
    });

    test('daily and monthly reflections link their own ranges', () {
      final daily = Reflection(
        period: ReflectionPeriod.daily,
        periodStart: DateTime(2026, 8, 7),
        generatedAt: DateTime.utc(2026, 8, 8),
        text: 'One day.',
      );
      final monthly = Reflection(
        period: ReflectionPeriod.monthly,
        periodStart: DateTime(2026, 8),
        generatedAt: DateTime.utc(2026, 9),
        text: 'One month.',
      );
      final files = exporter.exportJournal(
        ExportSnapshot(
          entries: [
            ExportEntry(
              entry: entry(id: 'a', createdAt: DateTime(2026, 8, 7, 9)),
            ),
            ExportEntry(
              entry: entry(id: 'b', createdAt: DateTime(2026, 8, 20, 9)),
            ),
          ],
          reflections: [daily, monthly],
        ),
        context,
      );
      final dayNote = textOf(files, 'reflections/daily 2026-08-07.md');
      expect(dayNote, contains('[[2026-08-07 Morning walk]]'));
      expect(dayNote, isNot(contains('2026-08-20')));
      final monthNote = textOf(files, 'reflections/monthly 2026-08-01.md');
      expect(monthNote, contains('[[2026-08-07 Morning walk]]'));
      expect(monthNote, contains('[[2026-08-20 Morning walk]]'));
    });
  });

  group('every exported path satisfies the zip writer', () {
    test('hostile titles stay writable', () async {
      final temp = await Directory.systemTemp.createTemp('exporters_paths');
      addTearDown(() => temp.delete(recursive: true));
      final hostile = [
        entry(id: 'a', title: 'a/b:c\\d*e?'),
        entry(id: 'b', title: '..'),
        entry(id: 'c', title: 'con'),
        entry(id: 'd', title: 'x' * 300),
        entry(id: 'e', title: null),
        entry(id: 'f', title: '[[#^|]]'),
      ];
      for (final exporter in const [DefaultExporter(), ObsidianExporter()]) {
        final files = exporter.exportJournal(
          ExportSnapshot(
            entries: [for (final e in hostile) ExportEntry(entry: e)],
            reflections: [reflection()],
          ),
          context,
        );
        final writer = await StoredZipWriter.create(File('${temp.path}/${exporter.id}.zip'));
        for (final file in files) {
          await writer.addBytes(file.path, file.bytes);
        }
        await writer.close();
      }
    });
  });
}
