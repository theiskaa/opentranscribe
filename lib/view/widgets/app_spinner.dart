import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// How far a dot has risen at loop position [t] (in `[0, 1)`), for the dot at
/// [index] counting 0 from the left, in the source animation's 512-unit space.
/// Each dot's bounce spans a third of the loop and starts a sixth after the one
/// to its left, so the three overlap into a left-to-right wave with a rest at
/// the loop's end. Zero outside the dot's window; eases up to the peak and back
/// with the source's `cubic-bezier(0.333, 0, 0.667, 1)` on each half.
double dotLift(double t, int index) {
  const jump = 66.0;
  const bounce = 1 / 3;
  const stagger = 1 / 6;
  const half = bounce / 2;
  const ease = Cubic(0.333, 0, 0.667, 1);
  final local = t - index * stagger;
  if (local < 0 || local >= bounce) return 0;
  return local < half
      ? jump * ease.transform(local / half)
      : jump * (1 - ease.transform((local - half) / half));
}

/// The loading indicator: three dots that bounce in a left-to-right wave, drawn
/// in pure Flutter and tinted to [color]. One of the app's two sanctioned loops
/// (the other is the live waveform), so it appears only while something is
/// genuinely in flight.
///
/// The dots are the requested [color] (falling back to [textSecondary]), so the
/// loader reads as the page's own ink rather than a fixed black or white.
class AppSpinner extends StatefulWidget {
  const AppSpinner({this.size = 20, this.color, super.key});

  final double size;
  final Color? color;

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner> with SingleTickerProviderStateMixin {
  // One full left-to-right wave and its trailing rest, matching the source loop.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.color ?? context.theme.textSecondary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _DotsPainter(progress: _controller, color: tint),
      ),
    );
  }
}

/// Draws the three dots for a loop position, keeping the source animation's
/// 512-unit geometry and scaling it to the box, so the dots sit and travel in
/// the same proportions the original loader did.
class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.progress, required this.color}) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  static const double _canvas = 512;
  static const double _radius = 55;
  static const double _baseline = 256;
  static const List<double> _centers = [128, 256, 384];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _canvas;
    final paint = Paint()..color = color;
    final t = progress.value;
    for (var i = 0; i < _centers.length; i++) {
      final center = Offset(_centers[i] * scale, (_baseline - dotLift(t, i)) * scale);
      canvas.drawCircle(center, _radius * scale, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}
