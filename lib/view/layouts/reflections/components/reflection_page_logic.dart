import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';

/// The ink phase for a reflected page. Pure, so the replay policy is a tested
/// rule, not widget state: the write-on plays once per week per screen visit
/// (a browse back and forth must not replay a 1.3s arrival), while a
/// regenerate always goes through pending and re-arrives (new words earn it).
InkPhase inkPhaseFor({
  required ReflectionWeek week,
  required bool regenerating,
  required Set<String> revealed,
}) {
  if (regenerating) return InkPhase.pending;
  if (revealed.contains(revealKeyFor(week))) return InkPhase.settled;
  return InkPhase.write;
}

/// The replay ledger's key: week AND generation instant, so a regenerated
/// week (same weekStart, new generatedAt) reads as unrevealed and its new
/// words arrive again. The ledger marks a write once its page is (or
/// becomes) the pager's current page: an arrival interrupted mid-read does
/// not replay, but a neighbor peeked and abandoned keeps its write unspent.
String revealKeyFor(ReflectionWeek week) {
  final at = week.reflection?.generatedAt.toIso8601String() ?? '';
  return '${week.weekStart.toIso8601String()}|$at';
}

/// Placeholder cloud height for a week being written, from the user's length
/// knob: the forming ink should look like the reflection it becomes.
int placeholderLinesFor(ReflectionLength length) => switch (length) {
  ReflectionLength.oneLine => 3,
  ReflectionLength.sentences => 5,
  ReflectionLength.paragraph => 8,
};

/// Where an eager pager settles after a release: any flick commits in its
/// direction, and a plain drag commits once it clears [threshold] of a page -
/// far short of the framework's half-page midpoint, so turning a week feels
/// immediate. [from] is the page the gesture STARTED from (the last settled
/// page, not the live rounding, which would recreate the 50% rule); a stale
/// anchor more than a page away re-anchors to the nearest page. The caller
/// clamps the result to the pager's range. Pure, so the commit rule is
/// tested.
int eagerPageTarget({
  required double page,
  required int from,
  required int flick,
  double threshold = 0.2,
}) {
  var anchor = from;
  if ((page - anchor).abs() > 1) anchor = page.round();
  if (flick > 0) return anchor + 1;
  if (flick < 0) return anchor - 1;
  final delta = page - anchor;
  if (delta > threshold) return anchor + 1;
  if (delta < -threshold) return anchor - 1;
  return anchor;
}

/// The pending cloud's height for [week] at the page's text [width]: shaped
/// like the text it replaces, falling back to the [length] knob when the week
/// holds none (a first write, an erased or silent week).
int pendingLinesFor({
  required ReflectionWeek week,
  required double width,
  required ReflectionLength length,
}) {
  final text = week.reflection?.text;
  if (text == null || text.isEmpty) return placeholderLinesFor(length);
  return estimateTextInkLines(
    characters: text.length,
    width: width,
    fontSize: AppType.body.fontSize!,
  );
}
