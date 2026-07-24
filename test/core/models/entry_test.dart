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
}
