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
}
