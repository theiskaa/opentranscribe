import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/transcribe/transcript.dart';

void main() {
  group('TranscriptSegment', () {
    test('round-trips through JSON', () {
      const segment = TranscriptSegment(
        text: 'hello',
        start: Duration(milliseconds: 500),
        end: Duration(milliseconds: 1500),
        confidence: 0.87,
      );

      final restored = TranscriptSegment.fromJson(segment.toJson());

      expect(restored, segment);
    });

    test('omits confidence when null', () {
      const segment = TranscriptSegment(
        text: 'hello',
        start: Duration.zero,
        end: Duration(seconds: 1),
      );

      expect(segment.toJson().containsKey('confidence'), isFalse);
      expect(TranscriptSegment.fromJson(segment.toJson()), segment);
    });
  });

  group('Transcript', () {
    final transcript = Transcript(
      fullText: 'the quick brown fox',
      segments: const [
        TranscriptSegment(text: 'the quick', start: Duration.zero, end: Duration(seconds: 1)),
        TranscriptSegment(
          text: 'brown fox',
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
        ),
      ],
      localeId: 'en-US',
      engineId: 'fake',
      createdAt: DateTime.utc(2026, 3, 4, 12),
    );

    test('round-trips through JSON with segments', () {
      expect(Transcript.fromJson(transcript.toJson()), transcript);
    });

    test('normalizes a local createdAt to UTC so round-trip equality holds', () {
      final local = Transcript(
        fullText: 'x',
        segments: const [],
        localeId: 'en-US',
        engineId: 'fake',
        createdAt: DateTime(2026, 3, 4, 12), // local, not UTC
      );

      expect(local.createdAt.isUtc, isTrue);
      expect(Transcript.fromJson(local.toJson()), local);
    });

    test('empty full text reports isEmpty', () {
      final empty = Transcript(
        fullText: '',
        segments: const [],
        localeId: 'en-US',
        engineId: 'fake',
        createdAt: DateTime.utc(2026),
      );

      expect(empty.isEmpty, isTrue);
      expect(transcript.isEmpty, isFalse);
    });
  });
}
