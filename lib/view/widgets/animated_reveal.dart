import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// Expands [child] into view when [visible] turns true and collapses it when
/// false: height and opacity animate together on the theme's indicator clock,
/// its curve opening and its flip folding, so a reveal moves with the control
/// that opened it. The child stays mounted while any of it shows, so a
/// collapse plays the entrance in reverse and a mid-flight flip is picked up
/// from the current frame rather than snapping; it unmounts once fully
/// collapsed and mounts afresh on the next reveal. Height is driven by a
/// top-anchored [Align.heightFactor], so the content slides down out of its
/// own top edge instead of scaling. Under Reduce Motion the change is instant.
///
/// The [child] owns anything that should collapse with it (a leading divider,
/// its own padding): whatever is passed is what folds away.
class AnimatedReveal extends StatefulWidget {
  const AnimatedReveal({required this.visible, required this.child, super.key});

  final bool visible;
  final Widget child;

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  late final CurvedAnimation _reveal = CurvedAnimation(
    parent: _controller,
    curve: context.motionNow.indicatorCurve,
    reverseCurve: context.motionNow.indicatorCurve.flipped,
  );

  @override
  void didUpdateWidget(covariant AnimatedReveal old) {
    super.didUpdateWidget(old);
    final motion = context.motionNow;
    _reveal
      ..curve = motion.indicatorCurve
      ..reverseCurve = motion.indicatorCurve.flipped;
    if (widget.visible == old.visible) return;
    if (context.reduceMotion) {
      _controller.value = widget.visible ? 1 : 0;
      return;
    }
    _controller.duration = motion.indicator;
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, child) {
        final t = _reveal.value;
        if (t == 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
