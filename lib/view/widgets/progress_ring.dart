import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// A quiet determinate ring: a hairline track and an accent arc growing
/// clockwise from twelve o'clock. The app's first fraction-true progress
/// control (the spinner stays for waits with no known end). The arc EASES
/// between reported fractions: downloads report in coarse jumps, and a ring
/// that snaps between them reads as broken rather than busy. Interruptible by
/// construction; a new fraction retargets the glide mid-flight.
class ProgressRing extends StatelessWidget {
  const ProgressRing({required this.fraction, this.size = 22, this.strokeWidth = 2.5, super.key});

  /// Progress in [0,1]; values outside are clamped, never wrapped.
  final double fraction;
  final double size;

  /// Stroke stays absolute, not proportional: the default reads solid at the
  /// inline size, and a hero-sized ring chooses its own weight.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final motion = theme.motion;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: fraction.clamp(0.0, 1.0)),
      duration: context.reduceMotion ? Duration.zero : motion.indicator,
      curve: motion.indicatorCurve,
      builder: (context, value, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          fraction: value,
          track: theme.hairline,
          fill: theme.accent,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
    required this.strokeWidth,
  });

  final double fraction;
  final Color track;
  final Color fill;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      paint..color = fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.track != track ||
      old.fill != fill ||
      old.strokeWidth != strokeWidth;
}
