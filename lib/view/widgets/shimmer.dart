import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// A shimmer sweep for skeleton placeholders. [builder] draws the skeleton
/// shapes in whatever colour it is handed; this paints them once in [base] as
/// the resting bars, then slides a [highlight] band across them on a loop. The
/// base layer carries no shader, so the placeholder is visible even before the
/// sweep paints a single frame.
///
/// One of the app's sanctioned loops, shown only while content is genuinely in
/// flight. Honors Reduce Motion by dropping the sweep and holding the bars.
class Shimmer extends StatefulWidget {
  const Shimmer({required this.builder, required this.base, required this.highlight, super.key});

  /// Builds the skeleton shapes in the given colour. Called twice: once for the
  /// resting bars, once for the travelling sheen.
  final Widget Function(Color color) builder;

  /// The resting bar colour, and the brighter sheen that travels through it.
  final Color base;
  final Color highlight;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Duration is set from the resolved motion in build; seeded here so the
    // controller exists before the first frame.
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.builder(widget.base);

    // Reduce Motion: the resting bars, no travel.
    if (context.reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      return base;
    }

    _controller.duration = context.theme.motion.shimmer;
    if (!_controller.isAnimating) _controller.repeat();

    return Stack(
      children: [
        base,
        // The sheen: the same shapes in [highlight], revealed only inside a
        // soft band that slides left to right. dstIn keeps the highlight bars
        // where the band is opaque, so the sweep rides the bars, not the gaps.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => ShaderMask(
                blendMode: BlendMode.dstIn,
                // Band centred in the gradient, slid from fully off the left
                // edge (value 0) to fully off the right (value 1).
                shaderCallback: (bounds) => LinearGradient(
                  colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                  stops: const [0.35, 0.5, 0.65],
                  transform: _SlidingBand(_controller.value * 2 - 1),
                ).createShader(bounds),
                child: widget.builder(widget.highlight),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Translates a gradient horizontally by [t] of the paint box's width.
class _SlidingBand extends GradientTransform {
  const _SlidingBand(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(t * bounds.width, 0, 0);
}
