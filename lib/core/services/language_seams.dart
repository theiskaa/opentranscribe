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

  Duration middle(TakeWindow gap) => _middleWithin(gap.start, gap.end, window);

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

/// Past this much of the new language's odds, a stretch is heard as the new
/// language; under its complement, as the old.
const double walkSure = 0.85;

/// A stretch shorter than this is too little to tell two languages apart.
const Duration walkShortest = Duration(milliseconds: 1500);

/// How many stretches a cut may walk past, each way.
const int walkSteps = 3;

/// Where a switch cut at [cut] really belongs, asking [newOdds] how likely a
/// stretch of speech is in the new language (null when it cannot tell). A
/// pause says where a cut may go, not which side the words belong to: a
/// sentence before [cut] heard in the new language moves the cut back past
/// it, and one after [cut] heard in the old language moves it forward (back
/// first; forward only when it stayed), up to [walkSteps] stretches each way
/// and never out of [window].
///
/// Stretches are the take's voice ([voiced], take-wide) split at pauses of
/// [seamPause] or more; one shorter than [walkShortest], or an answer short
/// of [walkSure], stops the walk. A cut inside a stretch stays.
Future<Duration> walkSeam({
  required Duration cut,
  required List<VoicedRange> voiced,
  required TakeWindow window,
  required Future<double?> Function(TakeWindow stretch) newOdds,
}) async {
  final stretches = <TakeWindow>[];
  for (final range in voiced) {
    final last = stretches.lastOrNull;
    if (last != null && range.start - last.end < seamPause) {
      stretches[stretches.length - 1] = (start: last.start, end: range.end);
    } else {
      stretches.add((start: range.start, end: range.end));
    }
  }
  if (stretches.any((s) => s.start < cut && cut < s.end)) return cut;
  var next = stretches.indexWhere((s) => s.start >= cut);
  if (next < 0) next = stretches.length;

  Duration between(Duration from, Duration to) => _middleWithin(from, to, window);

  bool readable(TakeWindow s) =>
      s.end - s.start >= walkShortest && s.start >= window.start && s.end <= window.end;

  var at = cut;
  for (var i = next - 1, steps = 0; i >= 0 && steps < walkSteps; i--, steps++) {
    final stretch = stretches[i];
    if (!readable(stretch)) break;
    final odds = await newOdds(stretch);
    if (odds == null || odds < walkSure) break;
    at = between(i > 0 ? stretches[i - 1].end : window.start, stretch.start);
  }
  if (at != cut) return at;
  for (var i = next, steps = 0; i < stretches.length && steps < walkSteps; i++, steps++) {
    final stretch = stretches[i];
    if (!readable(stretch)) break;
    final odds = await newOdds(stretch);
    if (odds == null || odds > 1 - walkSure) break;
    at = between(stretch.end, i + 1 < stretches.length ? stretches[i + 1].start : window.end);
  }
  return at;
}

/// The middle of [from]..[to] as far as it lies inside [window].
Duration _middleWithin(Duration from, Duration to, TakeWindow window) {
  final start = from < window.start ? window.start : from;
  final end = to > window.end ? window.end : to;
  return start + (end - start) ~/ 2;
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
