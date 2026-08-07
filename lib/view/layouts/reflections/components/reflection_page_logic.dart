import 'dart:math' as math;

import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';

/// The ink phase for a reflected page. Pure, so the replay policy is a tested
/// rule, not widget state: the write-on plays once per page per screen visit
/// (a browse back and forth must not replay the arrival), while a
/// regenerate always goes through pending and re-arrives (new words earn it).
/// A hold (the scrubber's finger) renders pages settled: pages flown through
/// under it must not start captures, write-ons, or ledger spends, and the
/// landed page re-earns its write once the hold releases.
InkPhase inkPhaseFor({
  required ReflectionPage page,
  required bool regenerating,
  required bool held,
  required Set<String> revealed,
}) {
  if (regenerating) return InkPhase.pending;
  if (held) return InkPhase.settled;
  if (revealed.contains(revealKeyFor(page))) return InkPhase.settled;
  return InkPhase.write;
}

/// The replay ledger's key: page AND generation instant, so a regenerated
/// page (same periodStart, new generatedAt) reads as unrevealed and its new
/// words arrive again. The ledger marks a write once its page is (or
/// becomes) the pager's current page: an arrival interrupted mid-read does
/// not replay, but a neighbor peeked and abandoned keeps its write unspent.
String revealKeyFor(ReflectionPage page) {
  final at = page.reflection?.generatedAt.toIso8601String() ?? '';
  return '${page.periodStart.toIso8601String()}|$at';
}

/// Placeholder cloud height for a page being written, from the user's length
/// knob: the forming ink should look like the reflection it becomes.
int placeholderLinesFor(ReflectionLength length) => switch (length) {
  ReflectionLength.oneLine => 3,
  ReflectionLength.sentences => 5,
  ReflectionLength.paragraph => 8,
};

/// Where an eager pager settles after a release: any flick commits in its
/// direction, and a plain drag commits once it clears [threshold] of a page -
/// far short of the framework's half-page midpoint, so turning a page feels
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

/// Where a scrub drag puts the pager: the page under the finger, one page per
/// [pitch] of travel from the [anchorPage] grabbed at pointer-down - so
/// touching the capsule never teleports, and dx > 0 moves toward newer pages
/// (the dots slide under the finger 1:1). Clamped to the timeline; a
/// timeline of one (or none) pins to 0. Pure, so the mapping is a tested rule.
double scrubPage({
  required double anchorPage,
  required double dx,
  required double pitch,
  required int count,
}) {
  if (count <= 1) return 0;
  return (anchorPage + dx / pitch).clamp(0, count - 1).toDouble();
}

/// Where a capsule TAP sends the pager: the tapped half picks the direction,
/// right of [width]'s middle toward newer pages and left toward older
/// (matching the scrub's dx), one page per tap, clamped to the timeline.
/// Pure, so the tap rule is tested.
int scrubTapTarget({
  required int page,
  required double dx,
  required double width,
  required int count,
}) {
  if (count <= 1) return 0;
  final target = dx >= width / 2 ? page + 1 : page - 1;
  return target.clamp(0, count - 1);
}

/// The page a capsule tap builds from: the still-in-flight previous tap's
/// [pending] target, so rapid taps chain one page EACH instead of re-rounding
/// the same unfinished transfer back to its start. A pending target more than
/// a hair over a page away is stale (something else moved the pager) and the
/// live rounding wins; the caller also drops [pending] once the pager rests
/// or a drag takes the position over. Pure, so the chaining rule is tested.
int tapChainBase({required double page, required int? pending}) {
  if (pending == null || (page - pending).abs() > 1.2) return page.round();
  return pending;
}

/// Whether the scrubber capsule shows. Never for a single page (nothing to
/// scrub); always under a finger or while the pager itself moves (position is
/// the question being asked); otherwise it follows the reading fold's verdict
/// ([scrubberScrollFold]). Pure, so the visibility rule is tested.
bool scrubberVisible({
  required int count,
  required bool readingShown,
  required bool pagerActive,
  required bool scrubbing,
}) {
  if (count <= 1) return false;
  if (scrubbing || pagerActive) return true;
  return readingShown;
}

/// Folds one vertical scroll tick into the capsule's reading visibility:
/// inside [topBand] it always shows; deeper, travelling down past [slack]
/// hides it and travelling up past [slack] brings it back - the iOS toolbar
/// rule, so the chrome steps aside while reading and returns on the first
/// deliberate move up. [anchor] is the extremum offset since the last flip,
/// so pixel jitter inside the slack never flickers. Pure, so the fold is
/// tested.
({bool shown, double anchor}) scrubberScrollFold({
  required bool shown,
  required double anchor,
  required double offset,
  required double slack,
  required double topBand,
}) {
  if (offset <= topBand) return (shown: true, anchor: offset);
  if (shown) {
    final low = math.min(anchor, offset);
    if (offset > low + slack) return (shown: false, anchor: offset);
    return (shown: true, anchor: low);
  }
  final high = math.max(anchor, offset);
  if (offset < high - slack) return (shown: true, anchor: offset);
  return (shown: false, anchor: high);
}

/// How far the dot strip has slid, in SLOT units (pitch-agnostic; paint
/// multiplies by the pitch): centers [position] in a [max]-slot viewport,
/// pinned at both ends so the rims only shrink where pages truly lie beyond.
/// [count] is fractional mid-morph (the strip growing or melting between
/// timelines), so the pin glides with it.
double stripShift({required double count, required double position, required int max}) {
  if (count <= max) return 0;
  return (position - (max - 1) / 2).clamp(0, count - max).toDouble();
}

/// A dot's size scale at viewport [slot]: full inside, ramping down to 0.5
/// at a rim that has more pages beyond it, so the shrink reads as an
/// ellipsis and the strip's slide as motion.
double rimScale({
  required double slot,
  required double shift,
  required double count,
  required int max,
}) {
  var scale = 1.0;
  if (shift > 0) scale = math.min(scale, 0.5 + slot * 0.5);
  if (shift < count - max) scale = math.min(scale, 0.5 + (max - 1 - slot) * 0.5);
  return scale.clamp(0.5, 1);
}

/// The ink's transfer between adjacent dots, driven 1:1 by the fractional
/// page ([t] = the fraction toward the next dot), so a half-finished swipe
/// holds the stream mid-flow and backing out reverses it. Three poses of one
/// liquid-bridge motion: the source blob drains ([bridgeDrain]) as a pinched
/// stream reaches across ([bridgeNeck]) and the destination swells full
/// ([bridgeFill]).
///
/// [bridgeDrain] is the ink remaining in the source dot: full at rest,
/// bleeding away as the stream carries it over, empty before the page lands.
double bridgeDrain(double t) => 1 - _smoothstep((t.clamp(0, 1) - 0.08) / 0.84);

/// The destination dot's fill: empty until the stream arrives, then filling
/// with a small swell PAST full before settling back, the follow-through of
/// the landing. Exactly 1 once the page rests.
double bridgeFill(double t) {
  final x = ((t.clamp(0, 1) - 0.08) / 0.92).clamp(0.0, 1.0);
  if (x <= 0) return 0;
  const c = 1.2;
  final u = x - 1;
  return 1 + (c + 1) * u * u * u + c * u * u;
}

/// The connecting stream's presence: nothing at either rest, strongest
/// mid-transfer when the ink is truly in between.
double bridgeNeck(double t) => math.sin(math.pi * t.clamp(0, 1));

double _smoothstep(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The pending cloud's height for [page] at the page's text [width] and the
/// reader's scaled [fontSize]: shaped like the text it replaces, falling back
/// to the [length] knob when the page holds none (a first write, an erased or
/// silent page).
int pendingLinesFor({
  required ReflectionPage page,
  required double width,
  required double fontSize,
  required ReflectionLength length,
}) {
  final text = page.reflection?.text;
  if (text == null || text.isEmpty) return placeholderLinesFor(length);
  return estimateTextInkLines(characters: text.length, width: width, fontSize: fontSize);
}
