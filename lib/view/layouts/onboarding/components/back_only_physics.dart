import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// How much of a move from [pixels] to [value] lies past [gate] in the forward
/// direction; zero for any backward or in-page movement. Pixels already past
/// the gate are a ceiling of their own, so a move is only ever shortened,
/// never reversed: ScrollPosition asserts an overscroll no larger than the delta.
double forwardOverscroll({required double value, required double pixels, required double gate}) {
  final beyond = value - math.max(gate, pixels);
  return beyond > 0 ? beyond : 0;
}

/// The page to close the gate on once the pager stops: the one it rests on, or
/// the next one when a touch froze it between two (a hold is not scrolling, so
/// ScrollEnd fires mid-slide). The gate then never sits behind the pixels, and
/// a fling from there settles on a page instead of resting where it was clamped.
int restingReach({required double pixels, required double viewportDimension}) {
  final page = pixels / math.max(1.0, viewportDimension);
  final nearest = page.round();
  return (page - nearest).abs() < precisionErrorTolerance ? nearest : page.ceil();
}

/// Pager physics that let the user swipe back but never forward past the page
/// [reach] names; forward is the button's job. [reach] is a callback because
/// Scrollable only swaps physics whose runtime type changed, so a new instance
/// per page would never be seen. Lower it only while the pager rests, and never
/// behind the pixels (see [restingReach]): a gate behind a moving viewport
/// freezes it where it is.
class BackOnlyPagePhysics extends ScrollPhysics {
  const BackOnlyPagePhysics({required this.reach, super.parent});

  final int Function() reach;

  @override
  BackOnlyPagePhysics applyTo(ScrollPhysics? ancestor) =>
      BackOnlyPagePhysics(reach: reach, parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final gate = reach() * position.viewportDimension;
    final beyond = forwardOverscroll(value: value, pixels: position.pixels, gate: gate);
    return beyond > 0 ? beyond : super.applyBoundaryConditions(position, value);
  }
}
