import 'package:transcriber/transcriber.dart';

/// A mixed-language take's span as the service keeps it: where it starts in
/// the take, in milliseconds, and the language it is heard in.
typedef TakeSpan = ({int startMs, String tag});

/// A stretch of a take, in its own time.
typedef TakeWindow = ({Duration start, Duration end});

/// How far back from a pick a switch may reach: where the middle of the quiet
/// the pick sits in may land, and past which nothing is read.
const Duration seamLookBack = Duration(seconds: 8);

/// How far past a pick the old language may run on: the end of a sentence
/// finished after the tap.
const Duration seamLookAhead = Duration(seconds: 3);

/// A pick sitting in quiet this long sits in the switch itself: the time it
/// takes to open the menu and find a language.
const Duration seamMenuPause = Duration(seconds: 1);

/// The quiet between sentences, as against the gap between two words.
const Duration seamPause = Duration(milliseconds: 300);

/// How far from the pick a pause may be and still take the cut. Past it,
/// which side the words between belong to is a question for their language,
/// not their pauses.
const Duration seamNear = Duration(seconds: 3);

/// A pause loses a second of its length for every this many seconds it sits
/// from the pick.
const int seamDistanceDivisor = 4;

/// The gap between two words, where a cut at least splits no word.
const Duration seamWordBreak = Duration(milliseconds: 120);

/// How far a word break may sit from the pick and still take the cut.
const Duration seamReach = Duration(seconds: 1);

/// Where a switch picked at [pick] may move to: [seamLookBack] before it to
/// [seamLookAhead] after, never past halfway to the [previous] or [next]
/// pick (so cuts keep their order) nor out of a take of [length]. The first
/// switch has no [previous].
TakeWindow seamWindow({
  required Duration pick,
  required Duration? previous,
  required Duration? next,
  required Duration length,
}) {
  var start = pick - seamLookBack;
  if (previous != null) {
    final afterPrevious = previous + (pick - previous) ~/ 2;
    if (afterPrevious > start) start = afterPrevious;
  }
  var end = pick + seamLookAhead;
  if (next != null) {
    final beforeNext = pick + (next - pick) ~/ 2;
    if (beforeNext < end) end = beforeNext;
  }
  if (length < end) end = length;
  if (start < Duration.zero) start = Duration.zero;
  return (start: start, end: end);
}

/// The instant a switch picked at [pick] cuts a take of [length], from where
/// the whole take holds a voice ([voiced]; null when the probe could not
/// tell), inside [window]. A pick is when a thumb landed, not where the
/// language changed, and a cut inside speech loses or invents the words on
/// both sides, so the cut goes to the middle of a quiet stretch:
/// - the quiet the pick sits in, when it is [seamMenuPause] or longer;
/// - else the best of that quiet and the pauses of [seamPause] or more within
///   [seamNear] of the pick still worth something once scored, each by its
///   length less its distance over [seamDistanceDivisor], ties to the nearer;
///   the take's lead-in and its
///   tail (voice on one side only) count only when nothing else does, unless
///   the pick sits in one;
/// - else the nearest word break within [seamReach];
/// - else the pick.
Duration seamCut({
  required Duration pick,
  required List<VoicedRange>? voiced,
  required TakeWindow window,
  required Duration length,
}) {
  if (voiced == null || window.end <= window.start) return pick;
  final quiet = <({TakeWindow gap, bool oneSided})>[];
  var at = Duration.zero;
  for (final range in voiced) {
    if (range.start > at) {
      quiet.add((gap: (start: at, end: range.start), oneSided: at == Duration.zero));
    }
    if (range.end > at) at = range.end;
  }
  if (length > at) quiet.add((gap: (start: at, end: length), oneSided: true));
  final inWindow = [
    for (final q in quiet)
      if (q.gap.end > window.start && q.gap.start < window.end) q,
  ];

  Duration extent(TakeWindow gap) => gap.end - gap.start;
  Duration away(TakeWindow gap) {
    if (pick < gap.start) return gap.start - pick;
    if (pick > gap.end) return pick - gap.end;
    return Duration.zero;
  }

  Duration middle(TakeWindow gap) {
    final start = gap.start < window.start ? window.start : gap.start;
    final end = gap.end > window.end ? window.end : gap.end;
    return start + (end - start) ~/ 2;
  }

  int score(TakeWindow gap) =>
      extent(gap).inMicroseconds - away(gap).inMicroseconds ~/ seamDistanceDivisor;
  bool holdsPick(TakeWindow gap) => gap.start <= pick && pick <= gap.end;
  bool isPause(TakeWindow gap) =>
      extent(gap) >= seamPause && away(gap) <= seamNear && score(gap) > 0;

  TakeWindow? best(Iterable<TakeWindow> gaps) {
    final ranked = gaps.toList()
      ..sort((a, b) {
        final higher = score(b).compareTo(score(a));
        return higher != 0 ? higher : away(a).compareTo(away(b));
      });
    return ranked.firstOrNull;
  }

  final own = inWindow.map((q) => q.gap).where(holdsPick).firstOrNull;
  if (own != null && extent(own) >= seamMenuPause) return middle(own);
  final chosen =
      best([
        ?own,
        for (final q in inWindow)
          if (!q.oneSided && q.gap != own && isPause(q.gap)) q.gap,
      ]) ??
      best([
        for (final q in inWindow)
          if (q.oneSided && isPause(q.gap)) q.gap,
      ]);
  if (chosen != null) return middle(chosen);
  final breaks = [
    for (final q in inWindow)
      if (extent(q.gap) >= seamWordBreak && away(q.gap) <= seamReach) q.gap,
  ]..sort((a, b) => away(a).compareTo(away(b)));
  return breaks.isEmpty ? pick : middle(breaks.first);
}

/// [spans] without those at [silent] indices (spans found to hold no voice),
/// the first left starting the take and neighbors in one tag merged into the
/// earlier: a re-hear never asks a silence for words again. Every span silent
/// leaves [spans] as they were.
List<TakeSpan> foldSilentSpans(List<TakeSpan> spans, Set<int> silent) {
  final kept = <TakeSpan>[];
  for (final (i, span) in spans.indexed) {
    if (silent.contains(i)) continue;
    if (kept.isEmpty) {
      kept.add((startMs: 0, tag: span.tag));
    } else if (kept.last.tag != span.tag) {
      kept.add(span);
    }
  }
  return kept.isEmpty ? spans : kept;
}
