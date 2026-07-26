import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// Startup splash: the brand waveform draws itself in, settles, then collapses
/// away as the app takes over. It REPLACES the app while running (see
/// `App.build`) because home's top-bar buttons are native platform views that
/// would punch through a Flutter overlay. Reduce Motion shows the wave whole and
/// fades out instead.
class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..addStatusListener((status) {
    if (status == AnimationStatus.completed) widget.onFinished();
  });

  // Draw in over the first ~730ms, a short settle, then a ~200ms collapse.
  late final Animation<double> _draw = CurvedAnimation(
    parent: _timeline,
    curve: const Interval(0, 0.73),
  );
  late final Animation<double> _exit = CurvedAnimation(
    parent: _timeline,
    curve: const Interval(0.8, 1),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    final glyphHeight = (shortestSide * 0.3).clamp(104.0, 176.0);
    final glyphWidth = glyphHeight * 492 / 481;

    return AnimatedBuilder(
      animation: _timeline,
      builder: (context, _) {
        return Opacity(
          opacity: reduceMotion ? 1 - _exit.value : 1,
          child: ColoredBox(
            color: theme.background,
            child: Center(
              child: SizedBox(
                width: glyphWidth,
                height: glyphHeight,
                child: CustomPaint(
                  painter: _WaveSplashPainter(
                    // The brand mark is monochrome ink, not the accent hue: a
                    // themed accent (Gruvbox orange, Solarized blue) would tint
                    // the wave, so it rides the text colour in every theme.
                    draw: reduceMotion ? 1 : _draw.value,
                    retract: reduceMotion ? 0 : _exit.value,
                    color: theme.text,
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

/// Seven bars in the brand SVG's 492x481 box (width 42, gap 33, pitch 75). Each
/// rises from the midline as [draw] advances and collapses back as [retract] does.
class _WaveSplashPainter extends CustomPainter {
  const _WaveSplashPainter({required this.draw, required this.retract, required this.color});

  final double draw;
  final double retract;
  final Color color;

  static const _pattern = [0.35, 0.65, 1.0, 0.7, 0.5, 0.85, 0.4];
  static const _stagger = 0.09;
  static const _span = 1 - _stagger * (7 - 1);

  // The draw is staggered left to right; the collapse is unified.
  double _drawn(int i) {
    final local = ((draw - i * _stagger) / _span).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final barWidth = size.width * 42 / 492;
    final centerY = size.height / 2;
    // easeInOut: eases out of the settled wave and decelerates into the midline,
    // so it neither jumps at the start nor snaps shut at the end.
    final collapse = Curves.easeInOut.transform(retract);

    for (var i = 0; i < _pattern.length; i++) {
      final drawn = _drawn(i);
      if (drawn <= 0) continue;
      final grown = math.max(barWidth, size.height * _pattern[i] * drawn);
      final height = grown * (1 - collapse);
      if (height <= 0.5) continue;
      final left = size.width * (75 * i) / 492;
      final radius = Radius.circular(math.min(barWidth / 2, height / 2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, centerY - height / 2, barWidth, height), radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveSplashPainter old) =>
      old.draw != draw || old.retract != retract || old.color != color;
}
