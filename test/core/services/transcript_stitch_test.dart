import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/transcript_stitch.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  final now = DateTime.utc(2026, 3, 4, 12);
  const offset = Duration(seconds: 10);

  Transcript transcript(
    String text, {
    String localeId = 'en-US',
    String engineId = 'apple.speech',
    bool timed = true,
  }) => Transcript(
    fullText: text,
    segments: timed && text.isNotEmpty
        ? [TranscriptSegment(text: text, start: Duration.zero, end: const Duration(seconds: 1))]
        : const [],
    localeId: localeId,
    engineId: engineId,
    createdAt: DateTime.utc(2026, 3, 4),
  );

  Entry entry({Transcript? transcript, List<Revision>? revisions}) => Entry(
    id: 'e',
    createdAt: now,
    audioPath: 'otr-e.m4a',
    duration: offset,
    transcript: transcript,
    revisions: revisions,
  );

  group('stitchTranscript', () {
    test('a same-language tail joins with a space and no marker', () {
      final stitched = stitchTranscript(
        base: transcript('hello there'),
        tail: transcript('and more'),
        offset: offset,
        marker: false,
        now: now,
      );

      expect(stitched.fullText, 'hello there and more');
      expect(stitched.segments.map((s) => s.text), ['hello there', 'and more']);
      expect(stitched.localeId, 'en-US');
      expect(stitched.createdAt, now);
    });

    test('a marked tail earns the marker in text and as a zero-length segment', () {
      final stitched = stitchTranscript(
        base: transcript('hello'),
        tail: transcript('bonjour', localeId: 'fr-FR'),
        offset: offset,
        marker: true,
        now: now,
      );

      expect(stitched.fullText, 'hello [fr] bonjour');
      expect(
        stitched.segments[1],
        const TranscriptSegment(text: '[fr]', start: offset, end: offset),
      );
      expect(stitched.localeId, 'en-US');
    });

    test('tail segments shift by the offset', () {
      final stitched = stitchTranscript(
        base: transcript('a'),
        tail: transcript('b'),
        offset: offset,
        marker: false,
        now: now,
      );

      expect(stitched.segments.last.start, offset);
      expect(stitched.segments.last.end, offset + const Duration(seconds: 1));
    });

    test('a blank tail returns the base itself', () {
      final base = transcript('kept');

      final stitched = stitchTranscript(
        base: base,
        tail: transcript('  '),
        offset: offset,
        marker: false,
        now: now,
      );

      expect(stitched, same(base));
    });

    test('a blank base returns the tail shifted and marker-free', () {
      final stitched = stitchTranscript(
        base: transcript(''),
        tail: transcript('bonjour', localeId: 'fr-FR'),
        offset: offset,
        marker: true,
        now: now,
      );

      expect(stitched.fullText, 'bonjour');
      expect(stitched.segments.single.start, offset);
      expect(stitched.localeId, 'fr-FR');
      expect(stitched.engineId, 'apple.speech');
    });

    test('an untimed half yields an untimed result', () {
      final untimedBase = stitchTranscript(
        base: transcript('salvaged', timed: false),
        tail: transcript('timed'),
        offset: offset,
        marker: false,
        now: now,
      );
      final untimedTail = stitchTranscript(
        base: transcript('timed'),
        tail: transcript('salvaged', timed: false),
        offset: offset,
        marker: false,
        now: now,
      );

      expect(untimedBase.fullText, 'salvaged timed');
      expect(untimedBase.segments, isEmpty);
      expect(untimedTail.segments, isEmpty);
    });

    test("the engine stamp stays the base's whatever the tail's engine", () {
      Transcript stitchWith(String tailEngine) => stitchTranscript(
        base: transcript('a', engineId: 'apple.dictation'),
        tail: transcript('b', engineId: tailEngine),
        offset: offset,
        marker: false,
        now: now,
      );

      expect(stitchWith('apple.speech').engineId, 'apple.dictation');
      expect(stitchWith('apple.dictation').engineId, 'apple.dictation');
    });
  });

  group('seamMarker', () {
    test("a take in another language than the base's end earns a marker", () {
      final stored = entry(transcript: transcript('a'));

      expect(seamMarker(stored: stored, tailLocaleId: 'fr-FR'), isTrue);
      expect(seamMarker(stored: stored, tailLocaleId: 'en-GB'), isFalse);
    });

    test('a mixed base is judged by its last span, not its first language', () {
      final mixed = entry(transcript: transcript('hello [fr] bonjour')).withLanguageSpans(const [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 4000, localeId: 'fr-FR'),
      ]);

      expect(seamMarker(stored: mixed, tailLocaleId: 'fr-FR'), isFalse);
      expect(seamMarker(stored: mixed, tailLocaleId: 'en-US'), isTrue);
    });

    test('an entry of unknown language earns no marker', () {
      expect(seamMarker(stored: entry(), tailLocaleId: 'fr-FR'), isFalse);
    });
  });

  group('extendSpans', () {
    test('a single-language base continued in the same language stays flat', () {
      final spans = extendSpans(
        base: null,
        baseLocaleId: 'en-US',
        offset: offset,
        tail: const [LanguageSpan(startMs: 0, localeId: 'en-US')],
      );

      expect(spans, isNull);
    });

    test('a tail in another language starts a span at the offset', () {
      final spans = extendSpans(
        base: null,
        baseLocaleId: 'en-US',
        offset: offset,
        tail: const [LanguageSpan(startMs: 0, localeId: 'fr-FR')],
      );

      expect(spans, const [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 10000, localeId: 'fr-FR'),
      ]);
    });

    test('tail spans shift by the offset and adjacent same-language spans coalesce', () {
      final spans = extendSpans(
        base: const [
          LanguageSpan(startMs: 0, localeId: 'en-US'),
          LanguageSpan(startMs: 4000, localeId: 'fr-FR'),
        ],
        baseLocaleId: 'en-US',
        offset: offset,
        tail: const [
          LanguageSpan(startMs: 0, localeId: 'fr-FR'),
          LanguageSpan(startMs: 2500, localeId: 'de-DE'),
        ],
      );

      expect(spans, const [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 4000, localeId: 'fr-FR'),
        LanguageSpan(startMs: 12500, localeId: 'de-DE'),
      ]);
    });
  });

  group('continuedRevisions', () {
    test('a pristine entry pushes no revision', () {
      final pushed = continuedRevisions(
        stored: entry(transcript: transcript('a')),
        tail: transcript('b'),
        marker: false,
        now: now,
      );

      expect(pushed, isNull);
    });

    test('a hand head pushes a hand revision carrying its words plus the take', () {
      final stored = entry(
        transcript: transcript('heard'),
        revisions: [
          Revision.ofTranscript(transcript('heard')),
          Revision(text: 'typed', at: now),
        ],
      );

      final pushed = continuedRevisions(
        stored: stored,
        tail: transcript('more'),
        marker: false,
        now: now,
      )!;

      expect(pushed, hasLength(3));
      expect(pushed.last.text, 'typed more');
      expect(pushed.last.isHand, isTrue);
      expect(pushed.last.localeId, isNull);
      expect(pushed.last.at, now);
    });

    test('an engine head pushes an engine revision stamped by the take', () {
      final stored = entry(
        transcript: transcript('heard', engineId: 'apple.dictation'),
        revisions: [Revision.ofTranscript(transcript('heard', engineId: 'apple.dictation'))],
      );

      final pushed = continuedRevisions(
        stored: stored,
        tail: transcript('encore', localeId: 'fr-FR'),
        marker: true,
        now: now,
      )!;

      expect(pushed.last.text, 'heard [fr] encore');
      expect(pushed.last.engineId, 'apple.speech');
      expect(pushed.last.localeId, 'en-US');
    });

    test('the head and the transcript agree on the seam when given the same marker', () {
      final base = transcript('heard');
      final stored = entry(transcript: base, revisions: [Revision.ofTranscript(base)]);
      final tail = transcript('encore', localeId: 'fr-FR');
      final marker = seamMarker(stored: stored, tailLocaleId: tail.localeId);

      final stitched = stitchTranscript(
        base: base,
        tail: tail,
        offset: offset,
        marker: marker,
        now: now,
      );
      final pushed = continuedRevisions(stored: stored, tail: tail, marker: marker, now: now)!;

      expect(pushed.last.text, stitched.fullText);
    });

    test('a blank take pushes nothing', () {
      final stored = entry(
        transcript: transcript('heard'),
        revisions: [Revision.ofTranscript(transcript('heard'))],
      );

      final pushed = continuedRevisions(
        stored: stored,
        tail: transcript(' '),
        marker: false,
        now: now,
      );

      expect(pushed, isNull);
    });
  });

  test('the marker keeps one spelling with the span join', () {
    expect(languageMarker('pt-BR'), '[pt]');
    expect(languageDiffers('en-US', 'en-GB'), isFalse);
    expect(languageDiffers('en-US', 'fr-FR'), isTrue);
  });

  test('appendText trims both sides and a blank side yields the other', () {
    expect(appendText('a', 'b', marker: true, tag: 'ja-JP'), 'a [ja] b');
    expect(appendText(' a ', ' b ', marker: false, tag: 'ja-JP'), 'a b');
    expect(appendText('a', '', marker: true, tag: 'ja-JP'), 'a');
    expect(appendText('', ' b ', marker: true, tag: 'ja-JP'), 'b');
  });
}
