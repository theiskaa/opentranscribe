import 'dart:math' as math;

import 'package:flutter/widgets.dart';

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

/// The lit/covered threshold for cell ([col], [row]): the ordered-dither
/// ladder with a 6% hash jitter so the grid never reads as pure machine.
/// The ONE recipe the corner field and the reveal share.
double ditherThreshold(int col, int row) =>
    _lerp(ditherBayer8(col, row), ditherHash(col.toDouble(), row.toDouble()), 0.06);

double _smooth(double t) => t * t * (3 - 2 * t);

double _lerp(double a, double b, double t) => a + (b - a) * t;

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

/// Three octaves of [ditherNoise], the breathing texture. In [0, 0.875).
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

/// Smoothstep with the shader's edge semantics, for dither consumers.
double ditherSmoothstep(double lo, double hi, double v) {
  final t = ((v - lo) / (hi - lo)).clamp(0.0, 1.0);
  return _smooth(t);
}

/// A cell's cover opacity during a dither reveal. The reveal is a WAVE, not
/// a uniform sweep: [spatial] (0 at the leading corner, 1 at the trailing
/// one) delays each cell so a dithered frontier travels across the surface,
/// and each cell fades through a soft band instead of popping - the two
/// together are what make the dissolve read as crafted rather than static.
/// 1 at [progress] 0 everywhere, 0 at [progress] 1 everywhere, monotone in
/// between. Pure, so the wave is tested.
double ditherCoverAlpha({
  required double threshold,
  required double spatial,
  required double progress,
  double frontier = 0.6,
  double fade = 0.25,
}) {
  final wave = progress * (1 + frontier + fade) - spatial * frontier;
  return 1 - ((wave - threshold) / fade).clamp(0.0, 1.0);
}

/// Materializes [child] through ordered dither: at [progress] 0 every cell
/// is covered in [cover] (the page's own color, so the child reads as
/// absent), at 1 none are. A dithered frontier travels from the top-left
/// toward the bottom-right as the sweep advances (and retreats the same way
/// in reverse), each cell fading through the Bayer ladder as the wave passes
/// ([ditherCoverAlpha]). Cover, not mask: over an opaque page the two are
/// identical, and covering needs no capture and no blend layer.
class DitherReveal extends StatelessWidget {
  const DitherReveal({
    required this.child,
    required this.progress,
    required this.cover,
    this.cell = 4.0,
    super.key,
  });

  final Widget child;

  /// 0 = fully covered (absent), 1 = fully material.
  final double progress;

  /// MUST match what the child sits on; anything else reads as a ghost
  /// rectangle instead of an absence.
  final Color cover;

  /// Logical pixels per dither cell.
  final double cell;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DitherCoverPainter(progress: progress, cover: cover, cell: cell),
      child: child,
    );
  }
}

class _DitherCoverPainter extends CustomPainter {
  const _DitherCoverPainter({required this.progress, required this.cover, required this.cell});

  final double progress;
  final Color cover;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1 || size.isEmpty) return;
    if (progress <= 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = cover);
      return;
    }
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    final span = math.max(1, cols + rows - 2);
    final paint = Paint();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final alpha = ditherCoverAlpha(
          threshold: ditherThreshold(col, row),
          spatial: (col + row) / span,
          progress: progress,
        );
        if (alpha <= 0.004) continue;
        paint.color = cover.withValues(alpha: cover.a * alpha);
        canvas.drawRect(Rect.fromLTWH(col * cell, row * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DitherCoverPainter old) =>
      old.progress != progress || old.cover != cover || old.cell != cell;
}
