import 'package:opentranscribe/core/models/entry.dart';
import 'package:transcriber/transcriber.dart';

/// A stretch of a take, in its own time.
typedef TakeWindow = ({Duration start, Duration end});

/// How far back from a pick a switch may reach: where the middle of the quiet
/// the pick sits in may land, and past which nothing is read.
const Duration _lookBack = Duration(seconds: 8);

/// How far past a pick the old language may run on: the end of a sentence
/// finished after the tap.
const Duration _lookAhead = Duration(seconds: 3);

/// A pick sitting in quiet this long sits in the switch itself: the time it
/// takes to open the menu and find a language.
const Duration _menuPause = Duration(seconds: 1);

/// The quiet between sentences, as against the gap between two words.
const Duration _pause = Duration(milliseconds: 300);

/// How far from the pick a pause may be and still take the cut. Past it,
/// which side the words between belong to is a question for their language,
/// not their pauses.
const Duration _pauseReach = Duration(seconds: 3);

/// A pause loses a second of its length for every this many seconds it sits
/// from the pick.
const int _distanceDivisor = 4;

/// The gap between two words, where a cut at least splits no word.
const Duration _wordBreak = Duration(milliseconds: 120);

/// How far a word break may sit from the pick and still take the cut.
const Duration _wordBreakReach = Duration(seconds: 1);

/// Where a switch picked at [pick] may move to: [_lookBack] before it to
/// [_lookAhead] after, never past halfway to the [previous] or [next] pick
/// (so cuts keep their order) nor out of a take of [length]. The first
/// switch has no [previous].
TakeWindow seamWindow({
  required Duration pick,
  required Duration? previous,
  required Duration? next,
  required Duration length,
}) {
  var start = pick - _lookBack;
  if (previous != null) {
    final afterPrevious = previous + (pick - previous) ~/ 2;
    if (afterPrevious > start) start = afterPrevious;
  }
  var end = pick + _lookAhead;
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
/// - the quiet the pick sits in, when it is [_menuPause] or longer;
/// - else the best of that quiet and the pauses of [_pause] or more within
///   [_pauseReach] of the pick still worth something once scored, each by its
///   length less its distance over [_distanceDivisor], ties to the nearer;
///   the take's lead-in and its tail (voice on one side only) count only when
///   nothing else does, unless the pick sits in one;
/// - else the nearest word break within [_wordBreakReach];
/// - else the pick.
Duration seamCut({
  required Duration pick,
  required List<VoicedRange>? voiced,
  required TakeWindow window,
  required Duration length,
}) {
  if (voiced == null || window.end <= window.start) return pick;
  final (:gaps, end: spokenEnd) = _gapsIn(voiced);
  final lead = voiced.firstOrNull?.start ?? length;
  final quiet = <({TakeWindow gap, bool oneSided})>[
    if (lead > Duration.zero) (gap: (start: Duration.zero, end: lead), oneSided: true),
    for (final gap in gaps) (gap: gap, oneSided: false),
    if (voiced.isNotEmpty && length > spokenEnd)
      (gap: (start: spokenEnd, end: length), oneSided: true),
  ];
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
      extent(gap).inMicroseconds - away(gap).inMicroseconds ~/ _distanceDivisor;
  bool holdsPick(TakeWindow gap) => gap.start <= pick && pick <= gap.end;
  bool isPause(TakeWindow gap) =>
      extent(gap) >= _pause && away(gap) <= _pauseReach && score(gap) > 0;

  TakeWindow? best(Iterable<TakeWindow> gaps) {
    final ranked = gaps.toList()
      ..sort((a, b) {
        final higher = score(b).compareTo(score(a));
        return higher != 0 ? higher : away(a).compareTo(away(b));
      });
    return ranked.firstOrNull;
  }

  final own = inWindow.map((q) => q.gap).where(holdsPick).firstOrNull;
  if (own != null && extent(own) >= _menuPause) return middle(own);
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
      if (extent(q.gap) >= _wordBreak && away(q.gap) <= _wordBreakReach) q.gap,
  ]..sort((a, b) => away(a).compareTo(away(b)));
  return breaks.isEmpty ? pick : middle(breaks.first);
}

/// Past this much of the new language's odds, a stretch is heard as the new
/// language; under its complement, as the old.
const double _walkSure = 0.85;

/// A stretch shorter than this is too little to tell two languages apart.
const Duration _walkShortest = Duration(milliseconds: 1500);

/// How many stretches a cut may walk past, each way.
const int _walkSteps = 3;

/// Where a switch cut at [cut] really belongs, asking [newOdds] how likely a
/// stretch of speech is in the new language (null when it cannot tell). A
/// pause says where a cut may go, not which side the words belong to: a
/// sentence before [cut] heard in the new language moves the cut back past
/// it, and one after [cut] heard in the old language moves it forward (back
/// first; forward only when it stayed), up to [_walkSteps] stretches each
/// way and never out of [window].
///
/// Stretches are the take's voice ([voiced], take-wide) split at pauses of
/// [_pause] or more; one shorter than [_walkShortest], or an answer short of
/// [_walkSure] either way, stops the walk. A cut inside a stretch stays.
Future<Duration> walkSeam({
  required Duration cut,
  required List<VoicedRange> voiced,
  required TakeWindow window,
  required Future<double?> Function(TakeWindow stretch) newOdds,
}) async {
  if (voiced.isEmpty) return cut;
  final (:gaps, end: spokenEnd) = _gapsIn(voiced);
  final stretches = <TakeWindow>[];
  var from = voiced.first.start;
  for (final gap in gaps) {
    if (gap.end - gap.start < _pause) continue;
    stretches.add((start: from, end: gap.start));
    from = gap.end;
  }
  stretches.add((start: from, end: spokenEnd));
  if (stretches.any((s) => s.start < cut && cut < s.end)) return cut;
  var next = stretches.indexWhere((s) => s.start >= cut);
  if (next < 0) next = stretches.length;

  Duration between(Duration from, Duration to) => _middleWithin(from, to, window);

  bool readable(TakeWindow s) =>
      s.end - s.start >= _walkShortest && s.start >= window.start && s.end <= window.end;

  // Null when the first stretch already stops the walk.
  Future<Duration?> walk(
    Iterable<int> order,
    bool Function(double odds) belong,
    Duration Function(int i) past,
  ) async {
    Duration? at;
    for (final i in order.take(_walkSteps)) {
      if (!readable(stretches[i])) break;
      final odds = await newOdds(stretches[i]);
      if (odds == null || !belong(odds)) break;
      at = past(i);
    }
    return at;
  }

  final back = await walk(
    [for (var i = next - 1; i >= 0; i--) i],
    (odds) => odds >= _walkSure,
    (i) => between(i > 0 ? stretches[i - 1].end : window.start, stretches[i].start),
  );
  if (back != null) return back;
  final ahead = await walk(
    [for (var i = next; i < stretches.length; i++) i],
    (odds) => odds <= 1 - _walkSure,
    (i) =>
        between(stretches[i].end, i + 1 < stretches.length ? stretches[i + 1].start : window.end),
  );
  return ahead ?? cut;
}

/// The quiet between the ranges of [voiced] (overlapping ranges read as
/// one), in order, and where its last voice ends.
({List<TakeWindow> gaps, Duration end}) _gapsIn(List<VoicedRange> voiced) {
  final gaps = <TakeWindow>[];
  var end = voiced.isEmpty ? Duration.zero : voiced.first.end;
  for (final range in voiced.skip(1)) {
    if (range.start > end) gaps.add((start: end, end: range.start));
    if (range.end > end) end = range.end;
  }
  return (gaps: gaps, end: end);
}

/// The middle of [from]..[to] as far as it lies inside [window].
Duration _middleWithin(Duration from, Duration to, TakeWindow window) {
  final start = from < window.start ? window.start : from;
  final end = to > window.end ? window.end : to;
  return start + (end - start) ~/ 2;
}

/// [spans] without those at [silent] indices (spans found to hold no voice),
/// the first left starting the take and neighbors in one language merged
/// into the earlier: a re-hear never asks a silence for words again. Every
/// span silent leaves [spans] as they were.
List<LanguageSpan> foldSilentSpans(List<LanguageSpan> spans, Set<int> silent) {
  final kept = <LanguageSpan>[];
  for (final (i, span) in spans.indexed) {
    if (silent.contains(i)) continue;
    if (kept.isEmpty) {
      kept.add(LanguageSpan(startMs: 0, localeId: span.localeId));
    } else if (kept.last.localeId != span.localeId) {
      kept.add(span);
    }
  }
  return kept.isEmpty ? spans : kept;
}
