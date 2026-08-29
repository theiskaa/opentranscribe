import 'package:opentranscribe/core/models/entry.dart';
import 'package:transcriber/transcriber.dart';

/// The `[fr]` marker that separates languages inside one transcript.
String languageMarker(String tag) => '[${tag.split('-').first}]';

/// Whether two tags name different languages; a regional difference alone
/// (en-US after en-GB) earns no marker.
bool languageDiffers(String a, String b) => a.split('-').first != b.split('-').first;

/// Whether a take in [tailLocaleId] needs a marker after [stored]: judged
/// against the language spoken at the END of the base (its last span), not the
/// transcript's, which names the first spoken language. Unknown base language
/// means no marker. Decided once and handed to both stitches, so the head and
/// the transcript can never disagree on the seam.
bool seamMarker({required Entry stored, required String tailLocaleId}) {
  final atEnd = stored.languageSpans?.last.localeId ?? stored.effectiveLocaleId;
  return atEnd != null && languageDiffers(tailLocaleId, atEnd);
}

/// [base] followed by [addition], single-spaced, with a language marker between
/// them when [marker] is set. Both sides are trimmed; either side blank yields
/// the other, so a silent take adds no whitespace.
String appendText(String base, String addition, {required bool marker, required String tag}) {
  final head = base.trim();
  final tail = addition.trim();
  if (tail.isEmpty) return head;
  if (head.isEmpty) return tail;
  return marker ? '$head ${languageMarker(tag)} $tail' : '$head $tail';
}

/// The transcript of a recording continued by [tail], which starts at [offset]
/// in the merged file. A blank tail returns [base] itself; a blank base yields
/// the tail alone. Otherwise the locale and engine stamp stay the base's (a
/// bulk pass under the tail's engine still re-hears the whole entry), and
/// segments survive only when both halves carry them: the view renders
/// segments alone when present, so an untimed half would lose its words.
Transcript stitchTranscript({
  required Transcript base,
  required Transcript tail,
  required Duration offset,
  required bool marker,
  required DateTime now,
}) {
  final shiftedTail = [for (final s in tail.segments) _shift(s, offset)];
  if (base.fullText.trim().isEmpty) {
    return Transcript(
      fullText: tail.fullText.trim(),
      segments: shiftedTail,
      localeId: tail.localeId,
      engineId: tail.engineId,
      createdAt: now,
    );
  }
  if (tail.fullText.trim().isEmpty) return base;
  final timed = base.segments.isNotEmpty && tail.segments.isNotEmpty;
  return Transcript(
    fullText: appendText(base.fullText, tail.fullText, marker: marker, tag: tail.localeId),
    segments: timed
        ? [
            ...base.segments,
            if (marker)
              TranscriptSegment(text: languageMarker(tail.localeId), start: offset, end: offset),
            ...shiftedTail,
          ]
        : const [],
    localeId: base.localeId,
    engineId: base.engineId,
    createdAt: now,
  );
}

/// [t] with its timings dropped, for words whose audio no longer exists, and
/// stamped with the language and engine of the file that remains.
Transcript untimed(Transcript t, {required String localeId, required String engineId}) =>
    Transcript(
      fullText: t.fullText,
      segments: const [],
      localeId: localeId,
      engineId: engineId,
      createdAt: t.createdAt,
    );

TranscriptSegment _shift(TranscriptSegment s, Duration by) =>
    TranscriptSegment(text: s.text, start: s.start + by, end: s.end + by, confidence: s.confidence);

/// The language mix of a recording continued at [offset] by a take whose own
/// spans are [tail] (from its 0 ms). Adjacent spans in one language coalesce;
/// a single resulting language is null, one spelling with a fresh take. The
/// result is ascending by construction, which the span slicing trusts.
List<LanguageSpan>? extendSpans({
  required List<LanguageSpan>? base,
  required String baseLocaleId,
  required Duration offset,
  required List<LanguageSpan> tail,
}) {
  final merged = <LanguageSpan>[];
  void add(LanguageSpan span) {
    if (merged.isNotEmpty && merged.last.localeId == span.localeId) return;
    merged.add(span);
  }

  for (final span in base ?? [LanguageSpan(startMs: 0, localeId: baseLocaleId)]) {
    add(span);
  }
  for (final span in tail) {
    add(LanguageSpan(startMs: offset.inMilliseconds + span.startMs, localeId: span.localeId));
  }
  return merged.length < 2 ? null : merged;
}

/// The history after a continuation: null when nothing is to be pushed (a
/// pristine entry keeps reading from its transcript; a blank take adds no
/// words). Otherwise the stack grown by one head carrying the old head's words
/// plus the take's, with the same [marker] the transcript got. A hand head
/// pushes a hand head; an engine head pushes one stamped by the take's engine.
List<Revision>? continuedRevisions({
  required Entry stored,
  required Transcript tail,
  required bool marker,
  required DateTime now,
}) {
  final revisions = stored.revisions;
  if (revisions == null || tail.fullText.trim().isEmpty) return null;
  final head = revisions.last;
  return [
    ...revisions,
    Revision(
      text: appendText(head.text, tail.fullText, marker: marker, tag: tail.localeId),
      at: now,
      engineId: head.isHand ? null : tail.engineId,
      localeId: head.isHand ? null : head.localeId ?? tail.localeId,
    ),
  ];
}
