import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';

/// The [AnimatedSwitcher.layoutBuilder] for swaps that melt in place: faces
/// stack top-left so old and new content share an origin while they
/// crossfade, where the default center pin would drift both mid-fade.
Widget meltStack(Widget? current, List<Widget> previous) =>
    Stack(alignment: Alignment.topLeft, children: [...previous, ?current]);

/// [meltStack] sized by the incoming face alone: the outgoing one fades over
/// it, so a resize around the swap starts with the fade instead of after it.
/// A taller outgoing face spills past the stack, for [MeltSwap]'s clip to wipe.
Widget _meltOver(Widget? current, List<Widget> previous) => Stack(
  clipBehavior: Clip.none,
  children: [
    for (final face in previous) PositionedDirectional(top: 0, start: 0, end: 0, child: face),
    ?current,
  ],
);

/// A section that regrows when what it holds comes and goes rides its own
/// resize instead of snapping the page a frame. Instant under Reduce Motion.
class Melt extends StatelessWidget {
  const Melt({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    return AnimatedSize(
      duration: context.reduceMotion ? AppMotion.instant : motion.indicator,
      curve: motion.indicatorCurve,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// [child] crossfading in place when [id] changes while the box eases to its
/// new height, the old face wiped by the easing edge as it fades. Needs a
/// bounded width: every face fills it, so old and new wrap to one measure.
class MeltSwap extends StatelessWidget {
  const MeltSwap({required this.id, required this.child, super.key});

  final Object id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    return ClipRect(
      child: Melt(
        child: AnimatedSwitcher(
          duration: context.reduceMotion ? Duration.zero : motion.indicator,
          switchInCurve: motion.indicatorCurve,
          switchOutCurve: motion.indicatorCurve.flipped,
          layoutBuilder: _meltOver,
          child: SizedBox(key: ValueKey(id), width: double.infinity, child: child),
        ),
      ),
    );
  }
}
