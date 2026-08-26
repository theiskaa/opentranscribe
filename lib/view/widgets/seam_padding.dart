import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';

/// Padding on a seam of a list of records (the journal timeline, the revision
/// history): the gaps that OPEN when a piece arrives and CLOSE when the piece
/// beside them is deleted. Animated because
/// every one of them flips while something else is already moving - a day
/// departs, its last record dies, a new one arrives - and a gap that snapped
/// would land the whole list a frame after everything else glided.
///
/// [closing] picks the clock, and that choice is the contract: a closing seam
/// runs on the delete exit's own duration and height interval, so the gap and
/// the collapsing slot read as one move; an opening seam rides the arrival
/// unfold. Reduce Motion keeps the same tree at zero duration.
class SeamPadding extends StatelessWidget {
  const SeamPadding({required this.closing, required this.padding, required this.child, super.key});

  final bool closing;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    return AnimatedPadding(
      duration: context.reduceMotion ? Duration.zero : (closing ? motion.swipeExit : motion.expand),
      curve: closing ? AppMotion.swipeExitHeightCurve : Curves.easeOutCubic,
      padding: padding,
      child: child,
    );
  }
}
