import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// The classic normalized 8x8 ordered-dither thresholds. NOT the website's
/// values: its recursive bayer is unnormalized (tops out past 1, so some of
/// its cells can never light); this is the corrected matrix, a touch denser
/// at equal tone.
const _bayer = [
  [0, 32, 8, 40, 2, 34, 10, 42],
  [48, 16, 56, 24, 50, 18, 58, 26],
  [12, 44, 4, 36, 14, 46, 6, 38],
  [60, 28, 52, 20, 62, 30, 54, 22],
  [3, 35, 11, 43, 1, 33, 9, 41],
  [51, 19, 59, 27, 49, 17, 57, 25],
  [15, 47, 7, 39, 13, 45, 5, 37],
  [63, 31, 55, 23, 61, 29, 53, 21],
];

/// The ordered-dither threshold for cell ([x], [y]); tiles every 8 cells.
/// Pure, so the pattern is tested.
double ditherBayer8(int x, int y) => _bayer[y % 8][x % 8] / 64;

/// A deterministic per-cell jitter in [0, 1), the shader's sin-dot hash.
double ditherHash(double x, double y) {
  final s = math.sin(x * 41.31 + y * 289.17) * 43758.5453;
  return s - s.floorToDouble();
}

double _smooth(double t) => t * t * (3 - 2 * t);

/// Smooth value noise in [0, 1): the hash at integer corners, blended with a
/// smoothstep so the field drifts without seams. Pure, so bounds are tested.
double ditherNoise(double x, double y) {
  final ix = x.floorToDouble();
  final iy = y.floorToDouble();
  final fx = _smooth(x - ix);
  final fy = _smooth(y - iy);
  final a = ditherHash(ix, iy);
  final b = ditherHash(ix + 1, iy);
  final c = ditherHash(ix, iy + 1);
  final d = ditherHash(ix + 1, iy + 1);
  return _lerp(_lerp(a, b, fx), _lerp(c, d, fx), fy);
}

/// Three octaves of [ditherNoise], the breathing texture. In [0, ~0.9).
double ditherFbm(double x, double y) {
  var sum = 0.0;
  var amp = 0.5;
  var px = x;
  var py = y;
  for (var i = 0; i < 3; i++) {
    sum += amp * ditherNoise(px, py);
    px = px * 2.03 + 1.7;
    py = py * 2.03 + 9.2;
    amp *= 0.5;
  }
  return sum;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _smoothstep(double lo, double hi, double v) {
  final t = ((v - lo) / (hi - lo)).clamp(0.0, 1.0);
  return _smooth(t);
}

/// A quiet corner of living dither: cells lit by an ordered-dither threshold
/// against a glow that breathes on drifting noise, the website background's
/// grammar drawn in plain Dart - no shader asset, nothing added to the
/// bundle. The glow anchors to the BOTTOM-RIGHT corner and dies toward the
/// text. Under Reduce Motion the field holds one still frame.
class DitherField extends StatefulWidget {
  const DitherField({required this.color, this.cell = 4.0, super.key});

  final Color color;

  /// Logical pixels per dither cell.
  final double cell;

  @override
  State<DitherField> createState() => _DitherFieldState();
}

class _DitherFieldState extends State<DitherField> with SingleTickerProviderStateMixin {
  /// The published clock's minimum step: the 0.02x drift looks identical
  /// between vsyncs, so repainting faster than this buys nothing.
  static const _step = 0.09;

  /// How many silent ticks before an unpainted field stops its ticker: the
  /// home list materializes every card, and a ticker left running pumps
  /// frames for a corner nobody can see. Paint is the heartbeat that
  /// restarts it.
  static const _quietLimit = 30;

  /// Drift seconds; unbounded, so the field never loops back over a seam.
  final ValueNotifier<double> _time = ValueNotifier(0);

  // Not lazy: a ticker first touched in dispose would be created during
  // teardown (the waveform's lesson).
  late final Ticker _ticker;

  /// Carried across stops, so a restart (paint returning, a Reduce Motion
  /// round trip) continues the drift instead of snapping it back to zero.
  double _base = 0;
  double _elapsed = 0;

  bool _still = false;
  bool _painted = false;
  int _quietTicks = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_painted) {
      _painted = false;
      _quietTicks = 0;
    } else if (++_quietTicks > _quietLimit) {
      _stop();
      return;
    }
    final t = _base + _elapsed;
    if (t - _time.value >= _step) _time.value = t;
  }

  /// Stops without losing the clock.
  void _stop() {
    _base += _elapsed;
    _elapsed = 0;
    _quietTicks = 0;
    _ticker.stop();
  }

  /// The painter ran, so the field is genuinely on screen: keep (or resume)
  /// ticking.
  void _heartbeat() {
    _painted = true;
    if (!_still && !_ticker.isActive) _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = context.reduceMotion;
    if (_still && _ticker.isActive) _stop();
    if (!_still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DitherPainter(
          time: _time,
          color: widget.color,
          cell: widget.cell,
          onPaint: _heartbeat,
        ),
      ),
    );
  }
}

class _DitherPainter extends CustomPainter {
  _DitherPainter({
    required this.time,
    required this.color,
    required this.cell,
    required this.onPaint,
  }) : super(repaint: time);

  final ValueListenable<double> time;
  final Color color;
  final double cell;

  /// The liveness heartbeat back to the field's ticker.
  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    if (size.isEmpty) return;
    // The clock rate and the breathe/tone/jitter constants below are
    // verbatim from the website shader (web/components/Background.tsx),
    // except where marked; keep them in step when syncing looks.
    final t = time.value * 0.02;
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    final paint = Paint()..color = color;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final x = col * cell;
        final y = row * cell;
        final qx = x / size.width;
        final qy = y / size.width;
        // DELIBERATE deviation: the web glows from mid-screen with a 0.62
        // reach; anchored to the bottom-right corner the falloff runs to
        // 0.95 so the field spans the patch before dying toward the text.
        final dx = 1 - qx;
        final dy = size.height / size.width - qy;
        final d = math.sqrt(dx * dx + dy * dy);
        var glow = 1 - _smoothstep(0.05, 0.95, d);
        glow = _smooth(glow);
        if (glow <= 0) continue;

        final breathe = 0.82 + 0.34 * (ditherFbm(qx * 2.6 + t, qy * 2.6 - t * 0.6) - 0.5);
        final tone = glow * 0.4 * breathe;
        final threshold = _lerp(
          ditherBayer8(col, row),
          ditherHash(col.toDouble(), row.toDouble()),
          0.06,
        );
        if (tone <= threshold) continue;
        // One flat token color where the web modulates its shade by glow:
        // the theme owns the dimness here.
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DitherPainter old) => old.color != color || old.cell != cell;
}
