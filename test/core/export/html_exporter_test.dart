import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/export/html_exporter.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
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
    generatedAt: DateTime.utc(2026, 8, 9, 12),
    appVersion: '0.2.0',
  );
  const exporter = HtmlExporter();

  Entry entry({
    String id = 'e1',
    DateTime? createdAt,
    String? title = 'Morning walk',
    String? text = 'went for a walk. it was quiet.',
    String locale = 'en-US',
  }) => Entry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 8, 7, 9, 30),
    audioPath: 'otr-1.m4a',
    duration: const Duration(minutes: 3, seconds: 24),
    title: title,
    recordedLocaleId: locale,
    transcript: text == null
        ? null
        : Transcript(
            fullText: text,
            segments: const [],
            localeId: locale,
            engineId: 'fake',
            createdAt: DateTime.utc(2026, 8, 7, 10),
          ),
  );

  String textOf(List<ExportFile> files, String path) =>
      utf8.decode(files.firstWhere((f) => f.path == path).bytes);

  test('a single entry is one self-contained page, styles and all', () {
    final files = exporter.exportEntry(
      ExportEntry(entry: entry(), audioRelativePath: 'otr-1.m4a'),
      context,
    );
    expect(files.map((f) => f.path), ['2026-08-07-Morning walk.html']);
    final html = utf8.decode(files.single.bytes);
    expect(html, startsWith('<!doctype html>'));
    expect(html, contains('<style>'));
    expect(html, isNot(contains('<link rel="stylesheet"')));
    expect(html, contains('<h1>Morning walk</h1>'));
    expect(html, contains('<audio controls preload="none" src="otr-1.m4a">'));
    expect(html, contains('<p>went for a walk. it was quiet.</p>'));
    expect(html, isNot(contains('<script src')));
  });

  test('a journal shares one stylesheet and one script rather than repeating them', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    expect(files.map((f) => f.path), ['index.html', 'style.css', 'script.js']);
    final html = textOf(files, 'index.html');
    expect(html, contains('<link rel="stylesheet" href="style.css">'));
    expect(html, contains('<script src="script.js"></script>'));
    expect(html, isNot(contains('<style>')));
    expect(textOf(files, 'style.css'), contains('prefers-color-scheme: dark'));
  });

  test('the page loads nothing from a network on its own', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    for (final file in files) {
      final text = utf8.decode(file.bytes);
      for (final reach in [
        '@import',
        'url(http',
        'src="http',
        'fetch(',
        'XMLHttpRequest',
        'WebSocket',
        'sendBeacon',
      ]) {
        expect(text, isNot(contains(reach)), reason: '$reach in ${file.path}');
      }
    }
  });

  test('the one address in the whole export is the site the mark links to', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    final urls = <String>{};
    for (final file in files) {
      urls.addAll(
        RegExp(
          r'https?://[^"\s)]+',
        ).allMatches(utf8.decode(file.bytes)).map((match) => match.group(0)!),
      );
    }
    expect(urls, {'https://opentranscribe.xyz'});
  });

  test('the link out cannot tell the site where it was clicked from', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    expect(textOf(files, 'index.html'), contains('rel="noopener noreferrer"'));
  });

  test('the wave rides beside the title, inline so it needs no second file', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    final html = textOf(files, 'index.html');
    expect(html, contains('<svg class="wave" viewBox="0 0 492 481"'));
    expect(html.indexOf('class="wave"'), lessThan(html.indexOf('<h1>')));
  });

  test('the journal names itself in the tab and at the top', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    final html = textOf(files, 'index.html');
    expect(html, contains('<title>OpenTranscribe Export</title>'));
    expect(html, contains('<h1>OpenTranscribe Export</h1>'));
  });

  test('an entry page titles itself after the entry, not after the app', () {
    final files = exporter.exportEntry(ExportEntry(entry: entry()), context);
    expect(utf8.decode(files.single.bytes), contains('<title>Morning walk</title>'));
  });

  test('the player is an upgrade over a working native one, not a replacement', () {
    final files = exporter.exportEntry(
      ExportEntry(entry: entry(), audioRelativePath: 'otr-1.m4a'),
      context,
    );
    final html = utf8.decode(files.single.bytes);
    expect(html, contains('<div class="player" data-duration="204">'));
  });

  test('the tools stay hidden for a reader whose browser runs no script', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    expect(textOf(files, 'index.html'), contains('<div class="tools" hidden>'));
  });

  test('the stylesheet lets the hidden attribute win over its own display rules', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    expect(textOf(files, 'style.css'), matches(RegExp(r'\[hidden\][^}]*!important')));
  });

  test('a hostile title or transcript renders as text, never as markup', () {
    final files = exporter.exportEntry(
      ExportEntry(
        entry: entry(title: '<script>x</script>', text: 'a <b>bold</b> & "quoted" claim'),
      ),
      context,
    );
    final html = utf8.decode(files.single.bytes);
    expect(html, isNot(contains('<script>x</script>')));
    expect(html, contains('&lt;script&gt;'));
    expect(html, contains('&lt;b&gt;bold&lt;/b&gt;'));
    expect(html, contains('&amp;'));
  });

  test('an audio name carrying a space or hash survives into its src', () {
    final files = exporter.exportEntry(
      ExportEntry(entry: entry(), audioRelativePath: 'audio/a walk #2.m4a'),
      context,
    );
    final html = utf8.decode(files.single.bytes);
    expect(html, contains('src="audio/a%20walk%20%232.m4a"'));
  });

  test('months run newest first and each carries its own anchor', () {
    final files = exporter.exportJournal(
      ExportSnapshot(
        entries: [
          ExportEntry(
            entry: entry(id: 'old', createdAt: DateTime(2026, 6, 2, 9)),
          ),
          ExportEntry(
            entry: entry(id: 'new', createdAt: DateTime(2026, 8, 2, 9)),
          ),
        ],
      ),
      context,
    );
    final html = textOf(files, 'index.html');
    expect(html.indexOf('id="m-2026-08"'), lessThan(html.indexOf('id="m-2026-06"')));
    expect(html, contains('<a href="#m-2026-08">'));
  });

  test('a reflection heads the month it covers', () {
    final files = exporter.exportJournal(
      ExportSnapshot(
        entries: [ExportEntry(entry: entry(createdAt: DateTime(2026, 8, 5, 9)))],
        reflections: [
          Reflection(
            periodStart: DateTime(2026, 8, 3),
            generatedAt: DateTime.utc(2026, 8, 9),
            text: 'A week of walking.',
          ),
        ],
      ),
      context,
    );
    final html = textOf(files, 'index.html');
    expect(html, contains('<h3>Week 2026-08-03</h3>'));
    expect(html.indexOf('class="reflection"'), lessThan(html.indexOf('class="entry"')));
  });

  test('a silent reflection reads as the quiet line, not as a blank', () {
    final files = exporter.exportJournal(
      ExportSnapshot(
        entries: [ExportEntry(entry: entry(createdAt: DateTime(2026, 8, 5, 9)))],
        reflections: [
          Reflection(periodStart: DateTime(2026, 8, 3), generatedAt: DateTime.utc(2026, 8, 9)),
        ],
      ),
      context,
    );
    expect(textOf(files, 'index.html'), contains('<p>A quiet stretch.</p>'));
  });

  test('an untranscribed entry gets no transcript block', () {
    final files = exporter.exportEntry(ExportEntry(entry: entry(text: null)), context);
    expect(utf8.decode(files.single.bytes), isNot(contains('class="transcript"')));
  });

  test('an untitled entry falls back to the untitled string', () {
    final files = exporter.exportEntry(ExportEntry(entry: entry(title: null)), context);
    expect(utf8.decode(files.single.bytes), contains('<h1>Untitled</h1>'));
  });

  test('a hostile locale in the meta line renders as text, never as markup', () {
    final files = exporter.exportEntry(
      ExportEntry(entry: entry(locale: '<img src=x onerror=alert(1)>')),
      context,
    );
    final html = utf8.decode(files.single.bytes);
    expect(html, isNot(contains('<img src=x')));
    expect(html, contains('&middot; &lt;img src=x onerror=alert(1)&gt;'));
  });

  test('a reflection whose month holds no entry is still written', () {
    final files = exporter.exportJournal(
      ExportSnapshot(
        entries: [ExportEntry(entry: entry(createdAt: DateTime(2026, 8, 5, 9)))],
        reflections: [
          Reflection(
            periodStart: DateTime(2026, 7, 27),
            generatedAt: DateTime.utc(2026, 8, 3),
            text: 'A week of walking.',
          ),
        ],
      ),
      context,
    );
    final html = textOf(files, 'index.html');
    expect(html, contains('id="m-2026-07"'));
    expect(html, contains('<p>A week of walking.</p>'));
  });

  test('an empty journal still names itself and says so rather than going blank', () {
    final files = exporter.exportJournal(ExportSnapshot(entries: const []), context);
    final html = textOf(files, 'index.html');
    expect(html, contains('<h1>OpenTranscribe Export</h1>'));
    expect(html, contains('<div class="empty">'));
    expect(html, contains('This journal has no entries.'));
    expect(html, isNot(contains('No entry matches')));
  });

  test('an entry without audio gets no player', () {
    final files = exporter.exportEntry(ExportEntry(entry: entry()), context);
    final html = utf8.decode(files.single.bytes);
    expect(html, isNot(contains('class="player"')));
    expect(html, isNot(contains('<audio')));
  });

  test('an entry heads its own page but sits under the month on the journal page', () {
    final standalone = utf8.decode(
      exporter.exportEntry(ExportEntry(entry: entry()), context).single.bytes,
    );
    final journal = textOf(
      exporter.exportJournal(ExportSnapshot(entries: [ExportEntry(entry: entry())]), context),
      'index.html',
    );
    expect(standalone, contains('<h1>Morning walk</h1>'));
    expect(journal, contains('<h3>Morning walk</h3>'));
  });

  test('a blank line in a transcript opens a new paragraph', () {
    final files = exporter.exportEntry(
      ExportEntry(entry: entry(text: 'first thought.\n\nsecond thought.')),
      context,
    );
    final html = utf8.decode(files.single.bytes);
    expect(html, contains('<p>first thought.</p>'));
    expect(html, contains('<p>second thought.</p>'));
  });

  test('a journal with entries still carries the miss state, waiting on a search', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    expect(textOf(files, 'index.html'), contains('<div class="empty" hidden>'));
  });

  test('a title of nothing but spaces falls back rather than heading nothing', () {
    final files = exporter.exportEntry(ExportEntry(entry: entry(title: '   ')), context);
    final html = utf8.decode(files.single.bytes);
    expect(html, contains('<h1>Untitled</h1>'));
    expect(html, contains('<title>Untitled</title>'));
  });

  test('a transcript of nothing but whitespace leaves no empty block behind', () {
    final files = exporter.exportEntry(ExportEntry(entry: entry(text: '   \n  ')), context);
    expect(utf8.decode(files.single.bytes), isNot(contains('class="transcript"')));
  });

  test('the timestamp attribute names the same day its own text does', () {
    final at = DateTime(2026, 8, 7, 1);
    final files = exporter.exportEntry(ExportEntry(entry: entry(createdAt: at)), context);
    final html = utf8.decode(files.single.bytes);
    expect(html, contains('<time datetime="${at.toIso8601String()}'));
    expect(html, contains('>2026-08-07 01:00</time>'));
  });

  test('a lone month is not given navigation to itself', () {
    final files = exporter.exportJournal(
      ExportSnapshot(entries: [ExportEntry(entry: entry())]),
      context,
    );
    expect(textOf(files, 'index.html'), isNot(contains('<nav class="months">')));
  });

  test('a journal of reflections alone still offers its colour scheme', () {
    final files = exporter.exportJournal(
      ExportSnapshot(
        entries: const [],
        reflections: [
          Reflection(periodStart: DateTime(2026, 8, 3), generatedAt: DateTime.utc(2026, 8, 9)),
        ],
      ),
      context,
    );
    final html = textOf(files, 'index.html');
    expect(html, contains('<div class="scheme"'));
    expect(html, isNot(contains('class="search"')));
  });
}
