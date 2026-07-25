import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// The startup splash: the brand waveform drawing itself in, holding, then
/// retracting back to the midline as the app takes over. Rendered as a
/// full-screen overlay above the router (see `App.build`) so home builds behind
/// it and the hand-off has nothing to load at the seam.
///
/// It reads the resolved theme, so it matches the system appearance for free -
/// paper with ink bars in light, ink with paper bars in dark - and its
/// background is the app's own [AppTheme.background], the same colour the native
/// launch screen paints. That match is what makes the exit seamless: the bars
/// collapse to nothing and the overlay is removed over an identical colour, so
/// there is no fade and no flash, just the wave leaving.
///
/// Under Reduce Motion the wave is shown whole (no rising or retracting bars)
/// and the exit is a plain cross-fade instead - the motion-safe substitute the
/// platform asks for when travel and springs are off.
class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onFinished, super.key});

  /// Fired once the exit completes, so the overlay can be removed.
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  /// One controller drives the whole timeline. The splits keep the draw-in at
  /// 750ms (0 -> 0.682 of 1100ms), then a brief 100ms hold, then a quick 250ms
  /// exit - the wave leaves almost as soon as it has landed.
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addStatusListener((status) {
    if (status == AnimationStatus.completed) widget.onFinished();
  });

  /// The draw-in phase: bars rise over the first 750ms.
  late final Animation<double> _draw = CurvedAnimation(
    parent: _timeline,
    curve: const Interval(0, 0.682),
  );

  /// The exit phase, the quick last 250ms. Drives the bars retracting (normal)
  /// or the surface fading (Reduce Motion).
  late final Animation<double> _exit = CurvedAnimation(
    parent: _timeline,
    curve: const Interval(0.773, 1),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start once, here rather than initState, so the first frame is the resting
    // state (nothing drawn) and reduceMotion can be read from context.
    if (!_started) {
      _started = true;
      _timeline.forward();
    }
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final reduceMotion = context.reduceMotion;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    // The glyph keeps the brand SVG's 492x481 box, sized to a calm third of the
    // narrow edge and clamped so it reads on any device.
    final glyphHeight = (shortestSide * 0.3).clamp(104.0, 176.0);
    final glyphWidth = glyphHeight * 492 / 481;

    return AnimatedBuilder(
      animation: _timeline,
      builder: (context, _) {
        return Opacity(
          // Reduce Motion leaves by fading (the motion-safe substitute); the
          // normal exit keeps full opacity and retracts the bars instead.
          opacity: reduceMotion ? 1 - _exit.value : 1,
          child: ColoredBox(
            color: theme.background,
            child: Center(
              child: SizedBox(
                width: glyphWidth,
                height: glyphHeight,
                child: CustomPaint(
                  painter: _WaveSplashPainter(
                    draw: reduceMotion ? 1 : _draw.value,
                    retract: reduceMotion ? 0 : _exit.value,
                    color: theme.accent,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints the seven-bar waveform inside its 492x481 box. Each bar rises from the
/// midline as [draw] advances and collapses back to it as [retract] advances, so
/// the splash both writes and unwrites the wave with no opacity change. Geometry
/// is taken verbatim from the brand SVG (`assets/brand/opentranscribe.svg`): bar
/// width 42, gap 33, pitch 75 in a 492-wide row, heights below. Kept here as
/// literals so the splash owns its own shape and does not reach into the home
/// layer for it.
class _WaveSplashPainter extends CustomPainter {
  const _WaveSplashPainter({required this.draw, required this.retract, required this.color});

  /// Draw-in progress, 0 (bars flat at the midline) to 1 (full height).
  final double draw;

  /// Retract progress, 0 (bars at their [draw] height) to 1 (flat again).
  final double retract;
  final Color color;

  /// Bar heights as a fraction of the box height, tallest bar = 1. Mirrors the
  /// brand SVG and the app's `kWavePattern`.
  static const _pattern = [0.35, 0.65, 1.0, 0.7, 0.5, 0.85, 0.4];

  /// Each bar starts [_stagger] later than the last and moves over [_span] of
  /// the phase, so the wave reads as written left to right, not slammed in.
  static const _stagger = 0.09;
  static const _span = 1 - _stagger * (7 - 1);

  /// One bar's staggered 0..1 progress through a phase, eased.
  double _phase(double t, int i) {
    final local = ((t - i * _stagger) / _span).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final barWidth = size.width * 42 / 492;
    final radius = Radius.circular(barWidth / 2);
    final centerY = size.height / 2;

    for (var i = 0; i < _pattern.length; i++) {
      // Grown by the draw, then pulled back down by the retract.
      final reveal = _phase(draw, i) * (1 - _phase(retract, i));
      if (reveal <= 0) continue;
      // A round-capped bar can never be shorter than it is wide.
      final height = math.max(barWidth, size.height * _pattern[i] * reveal);
      final left = size.width * (75 * i) / 492;
      final rect = Rect.fromLTWH(left, centerY - height / 2, barWidth, height);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveSplashPainter old) =>
      old.draw != draw || old.retract != retract || old.color != color;
}
