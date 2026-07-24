import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/view/layouts/home/components/pull_to_record.dart';

/// A small looping waveform: the pull-to-record hint's bars at full height with
/// the wave travelling across them forever. It stands where an icon would in an
/// empty state, so the empty home previews the very gesture that fills it. It
/// reuses the pull hint's [pullBarSwell] with the swell pinned fully on, so only
/// the wave moves - the bars never grow or shrink.
class WaveGlyph extends StatefulWidget {
  const WaveGlyph({this.size = 44, this.barWidth = 3, this.gap = 4, this.color, super.key});

  final double size;
  final double barWidth;
  final double gap;
  final Color? color;

  @override
  State<WaveGlyph> createState() => _WaveGlyphState();
}

class _WaveGlyphState extends State<WaveGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    // A plain read, not context.theme (a select): this runs outside build, and
    // inside a lazy list a select here throws. The duration is a static token,
    // so reading it once is right anyway.
    _phase
      ..duration = context.read<ThemeCubit>().state.resolved.motion.pullWave
      ..repeat();
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: _WaveGlyphPainter(
          repaint: _phase,
          phase: () => _phase.value * 2 * math.pi,
          color: widget.color ?? context.theme.textSecondary,
          barWidth: widget.barWidth,
          gap: widget.gap,
        ),
      ),
    );
  }
}

class _WaveGlyphPainter extends CustomPainter {
  const _WaveGlyphPainter({
    required Listenable repaint,
    required this.phase,
    required this.color,
    required this.barWidth,
    required this.gap,
  }) : super(repaint: repaint);

  /// The travelling wave's position in radians; the controller drives repaint.
  final double Function() phase;
  final Color color;
  final double barWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final row = kWavePattern.length * barWidth + (kWavePattern.length - 1) * gap;
    var x = (size.width - row) / 2 + barWidth / 2;
    final mid = size.height / 2;
    final now = phase();
    for (var i = 0; i < kWavePattern.length; i++) {
      // Fully grown and fully alive: progress and alive are both 1, so the bars
      // hold their shape and only the swell travels through them.
      final full = size.height * kWavePattern[i];
      final h = math.max(barWidth, full * pullBarSwell(i, now, 1));
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_WaveGlyphPainter old) =>
      old.color != color || old.barWidth != barWidth || old.gap != gap;
}
