import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// A quiet determinate ring: a hairline track and an accent arc growing
/// clockwise from twelve o'clock. The app's first fraction-true progress
/// control (the spinner stays for waits with no known end); drawn, not
/// animated, because the fraction itself moves as downloads report.
class ProgressRing extends StatelessWidget {
  const ProgressRing({required this.fraction, this.size = 22, super.key});

  /// Progress in [0,1]; values outside are clamped, never wrapped.
  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return CustomPaint(
      size: Size.square(size),
      painter: _RingPainter(
        fraction: fraction.clamp(0.0, 1.0),
        track: theme.hairline,
        fill: theme.accent,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.track, required this.fill});

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.5;
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
      old.fraction != fraction || old.track != track || old.fill != fill;
}
