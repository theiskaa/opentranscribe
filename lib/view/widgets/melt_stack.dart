import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';

/// The [AnimatedSwitcher.layoutBuilder] for swaps that melt in place: faces
/// stack top-left so old and new content share an origin while they
/// crossfade, where the default center pin would drift both mid-fade.
Widget meltStack(Widget? current, List<Widget> previous) =>
    Stack(alignment: Alignment.topLeft, children: [...previous, ?current]);

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
