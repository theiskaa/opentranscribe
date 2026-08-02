import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// Expands [child] into view when [visible] turns true and collapses it when
/// false: height and opacity animate together over [AppMotion.expand]. The
/// child stays mounted the whole time, so a collapse plays the entrance in
/// reverse and a mid-flight flip is picked up from the current frame rather
/// than snapping. Height is driven by a top-anchored [Align.heightFactor], so
/// the content slides down out of its own top edge instead of scaling. Under
/// Reduce Motion the change is instant.
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
  late final Animation<double> _reveal = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(covariant AnimatedReveal old) {
    super.didUpdateWidget(old);
    if (widget.visible == old.visible) return;
    if (context.reduceMotion) {
      _controller.value = widget.visible ? 1 : 0;
      return;
    }
    _controller.duration = context.motionNow.expand;
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
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
