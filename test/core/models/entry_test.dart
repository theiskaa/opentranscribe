import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';

void main() {
  final transcript = Transcript(
    fullText: 'hello world',
    segments: const [
      TranscriptSegment(text: 'hello world', start: Duration.zero, end: Duration(seconds: 1)),
    ],
    localeId: 'en-US',
    engineId: 'fake',
    createdAt: DateTime.utc(2026, 3, 4),
  );

  Entry baseEntry() => Entry(
    id: 'abc',
    createdAt: DateTime.utc(2026, 3, 4, 9),
    audioPath: '/audio/abc.m4a',
    duration: const Duration(seconds: 12),
  );

  test('round-trips through JSON without a transcript', () {
    final entry = baseEntry();

    expect(entry.isTranscribed, isFalse);
    expect(entry.toJson().containsKey('transcript'), isFalse);
    expect(Entry.fromJson(entry.toJson()), entry);
  });

  test('normalizes a local createdAt to UTC so round-trip equality holds', () {
    final entry = Entry(
      id: 'l',
      createdAt: DateTime(2026, 3, 4, 9), // local, not UTC
      audioPath: 'l.m4a',
      duration: Duration.zero,
    );

    expect(entry.createdAt.isUtc, isTrue);
    expect(Entry.fromJson(entry.toJson()), entry);
  });

  test('round-trips through JSON with a transcript', () {
    final entry = baseEntry().withTranscript(transcript);

    expect(entry.isTranscribed, isTrue);
    expect(Entry.fromJson(entry.toJson()), entry);
  });

  test('an entry with an empty transcript is transcribed and round-trips', () {
    // Silence transcribes to an empty (not null) transcript; that is transcribed.
    final empty = Transcript(
      fullText: '',
      segments: const [],
      localeId: 'en-US',
      engineId: 'fake',
      createdAt: DateTime.utc(2026, 3, 4),
    );
    final entry = baseEntry().withTranscript(empty);

    expect(entry.isTranscribed, isTrue);
    expect(Entry.fromJson(entry.toJson()), entry);
  });

  test('withTranscript keeps identity fields and sets the transcript', () {
    final original = baseEntry();
    final updated = original.withTranscript(transcript);

    expect(updated.id, original.id);
    expect(updated.createdAt, original.createdAt);
    expect(updated.audioPath, original.audioPath);
    expect(updated.duration, original.duration);
    expect(updated.transcript, transcript);
  });

  test('title round-trips through JSON and is omitted when null', () {
    final untitled = baseEntry();
    expect(untitled.toJson().containsKey('title'), isFalse);

    final titled = untitled.withTitle('Morning pages');
    expect(titled.title, 'Morning pages');
    expect(Entry.fromJson(titled.toJson()), titled);
  });

  test('a record written before titles existed loads as untitled', () {
    final json = baseEntry().toJson()..remove('title');
    expect(Entry.fromJson(json).title, isNull);
  });

  test('withTranscript preserves the title; withTitle(null) clears it', () {
    final titled = baseEntry().withTitle('Standup thoughts');

    expect(titled.withTranscript(transcript).title, 'Standup thoughts');
    expect(titled.withTitle(null).title, isNull);
  });

  test('equality and hashCode include the title', () {
    final a = baseEntry().withTitle('x');
    final b = baseEntry().withTitle('x');
    final c = baseEntry().withTitle('y');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });

  Entry recordedIn(String tag) => Entry(
    id: 'abc',
    createdAt: DateTime.utc(2026, 3, 4, 9),
    audioPath: '/audio/abc.m4a',
    duration: const Duration(seconds: 12),
    recordedLocaleId: tag,
  );

  test('recordedLocaleId round-trips through JSON and is omitted when null', () {
    expect(baseEntry().toJson().containsKey('recordedLocaleId'), isFalse);

    final recorded = recordedIn('fr-FR');
    expect(Entry.fromJson(recorded.toJson()), recorded);
    expect(Entry.fromJson(recorded.toJson()).recordedLocaleId, 'fr-FR');
  });

  test('a record written before per-entry language loads as unknown', () {
    final json = recordedIn('fr-FR').toJson()..remove('recordedLocaleId');
    expect(Entry.fromJson(json).recordedLocaleId, isNull);
    expect(Entry.fromJson(json).effectiveLocaleId, isNull);
  });

  test('withTranscript and withTitle preserve the recorded locale', () {
    final recorded = recordedIn('fr-FR');

    expect(recorded.withTranscript(transcript).recordedLocaleId, 'fr-FR');
    expect(recorded.withTitle('t').recordedLocaleId, 'fr-FR');
  });

  test('effectiveLocaleId prefers the transcript, falls back to the recording', () {
    // Transcribed: the transcript's language wins (it is what the text IS),
    // even over a differing recording-time locale.
    expect(recordedIn('fr-FR').withTranscript(transcript).effectiveLocaleId, 'en-US');
    // Untranscribed: the recording-time language is the honest answer.
    expect(recordedIn('fr-FR').effectiveLocaleId, 'fr-FR');
    // Neither: unknown, never guessed.
    expect(baseEntry().effectiveLocaleId, isNull);
  });

  test('equality and hashCode include the recorded locale', () {
    expect(recordedIn('fr-FR'), recordedIn('fr-FR'));
    expect(recordedIn('fr-FR') == recordedIn('de-DE'), isFalse);
  });

  test('peaks round-trip through JSON and are preserved by copies', () {
    expect(baseEntry().toJson().containsKey('peaks'), isFalse);

    final shaped = baseEntry().withPeaks(const [0, 128, 255]);
    expect(Entry.fromJson(shaped.toJson()), shaped);
    expect(Entry.fromJson(shaped.toJson()).peaks, [0, 128, 255]);

    expect(shaped.withTranscript(transcript).peaks, [0, 128, 255]);
    expect(shaped.withTitle('t').peaks, [0, 128, 255]);
    expect(shaped == baseEntry().withPeaks(const [0, 128, 255]), isTrue);
    expect(shaped == baseEntry().withPeaks(const [0, 128, 254]), isFalse);
  });

  test('a record written before peaks loads without them', () {
    final json = baseEntry().withPeaks(const [1]).toJson()..remove('peaks');
    expect(Entry.fromJson(json).peaks, isNull);
  });

  test('language spans round-trip through JSON and are preserved by copies', () {
    expect(baseEntry().toJson().containsKey('languageSpans'), isFalse);

    final mixed = Entry(
      id: 'abc',
      createdAt: DateTime.utc(2026, 3, 4, 9),
      audioPath: '/audio/abc.m4a',
      duration: const Duration(seconds: 12),
      languageSpans: const [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 4000, localeId: 'fr-FR'),
      ],
    );
    expect(Entry.fromJson(mixed.toJson()), mixed);
    expect(mixed.withTranscript(transcript).languageSpans, mixed.languageSpans);
    expect(mixed.withTitle('t').languageSpans, mixed.languageSpans);
    expect(mixed.withPeaks(const [1]).languageSpans, mixed.languageSpans);
    expect(mixed == mixed.withTitle(null), isTrue);
  });
}
