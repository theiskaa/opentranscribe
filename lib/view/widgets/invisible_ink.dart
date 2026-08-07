import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// The iMessage "invisible ink" shimmer: the given text's ink is sampled into a
/// dense field of fine sparks, one per point, each drifting a touch and flaring
/// bright then dark on its own slow phase. Most sit dim at any instant, so the
/// glyphs read as a living glitter rather than a solid block or a scatter of
/// pepper.
///
/// Fed the [image] of the rendered text (resampled whenever it changes), the
/// logical [size] it occupies, the ink [color], and a looping [clock] (0..1)
/// that drives the shimmer. The pulse and wander use whole-number harmonics of
/// the clock, so the loop is seamless. The caller crossfades this against the
/// real text to hide or reveal it, owns the image, and gates the whole effect
/// on reduce motion: this widget always shimmers.
///
/// [InvisibleInk.points] shimmers pre-computed points instead of a sampled
/// frame, for text that does not exist yet: the placeholder lines a first
/// transcribe shows (see [placeholderInkPoints]).
class InvisibleInk extends StatefulWidget {
  const InvisibleInk({
    required ui.Image this.image,
    required this.size,
    required this.pixelRatio,
    required this.color,
    required this.clock,
    super.key,
  }) : points = null;

  const InvisibleInk.points({
    required Float32List this.points,
    required this.size,
    required this.color,
    required this.clock,
    super.key,
  }) : image = null,
       pixelRatio = 1;

  final ui.Image? image;

  /// Pre-computed spark points, flat [x0, y0, ...] in logical coordinates;
  /// null in the sampled-image mode.
  final Float32List? points;
  final Size size;
  final double pixelRatio;
  final Color color;

  /// Looping 0..1 while the shimmer is up.
  final Animation<double> clock;

  @override
  State<InvisibleInk> createState() => _InvisibleInkState();
}

class _InvisibleInkState extends State<InvisibleInk> {
  /// Spark points, flat [x0, y0, x1, y1, ...] in logical coordinates on the ink.
  Float32List? _ink;

  @override
  void initState() {
    super.initState();
    final points = widget.points;
    if (points != null) {
      _ink = points;
    } else {
      _sample();
    }
  }

  @override
  void didUpdateWidget(InvisibleInk old) {
    super.didUpdateWidget(old);
    final points = widget.points;
    if (points != null) {
      if (!identical(points, old.points)) setState(() => _ink = points);
      return;
    }
    if (widget.image != old.image) {
      // The old points trace the old text and may lie outside the new bounds;
      // drop them and resample rather than shimmer a stale shape.
      setState(() => _ink = null);
      _sample();
    }
  }

  /// Reads the captured frame's alpha into a dense set of spark points on the
  /// glyphs. Async, but the cloud is near-invisible in the first frames of the
  /// crossfade anyway, so the points are in place by the time it matters.
  Future<void> _sample() async {
    final image = widget.image;
    if (image == null) return;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    // The last guard drops a sample that lost a race with a newer image.
    if (!mounted || data == null || widget.image != image) return;
    setState(() {
      _ink = sampleInkPoints(
        data,
        width: image.width,
        height: image.height,
        pixelRatio: widget.pixelRatio,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: widget.size,
      child: CustomPaint(size: widget.size, painter: _InkPainter(_ink, widget.color, widget.clock)),
    );
  }
}

/// The most sparks drawn per frame; [sampleInkPoints] holds its count to this.
const int kMaxInkPoints = 24000;

/// Samples a captured frame's alpha into spark points, flat [x0, y0, ...] in
/// logical coordinates: one candidate per ~0.9 logical px of ink (dense enough
/// that the text shape reads crisp rather than under-sampled), thinned with a
/// uniform stride past [maxPoints] so coverage stays even. Pure, so the grid,
/// threshold, and cap are testable off the widget.
Float32List sampleInkPoints(
  ByteData rgba, {
  required int width,
  required int height,
  required double pixelRatio,
  int maxPoints = kMaxInkPoints,
}) {
  final step = math.max(1, (pixelRatio * 0.9).round());
  final points = <double>[];
  for (var y = 0; y < height; y += step) {
    final row = y * width * 4;
    for (var x = 0; x < width; x += step) {
      if (rgba.getUint8(row + x * 4 + 3) > 50) {
        points.add(x / pixelRatio);
        points.add(y / pixelRatio);
      }
    }
  }
  return _capInkPoints(points, maxPoints);
}

/// Speech and type factors behind the placeholder estimate. Rough on purpose:
/// the ink only has to look like the right amount of text, not measure it.
const double _kWordsPerSecond = 2.4; // conversational pace, ~145 wpm
const double _kCharsPerWord = 6.2; // an average word plus its space
const double _kCharWidthEm = 0.48; // average glyph advance per font size
const double _kInkHeightEm = 0.46; // the x-height band a line's ink fills
const int _kMaxInkRows = 16; // about a screenful; taller reads no better
const int _kVoicedFloor = 20; // envelope level (0..255) that counts as speech

/// Approximates how many transcript lines [audio] will produce laid out at
/// [width] in a [fontSize] body, weighing the recording's amplitude envelope
/// ([peaks], 0..255) so silence does not count as prose. Pure, so the estimate
/// is testable; it only has to be believable, never right.
int estimateInkLines({
  required Duration audio,
  required double width,
  required double fontSize,
  List<int>? peaks,
}) {
  // No envelope (older entries, not yet backfilled): assume mostly speech.
  var voiced = 0.9;
  if (peaks != null && peaks.isNotEmpty) {
    final speaking = peaks.where((p) => p > _kVoicedFloor).length;
    voiced = (speaking / peaks.length).clamp(0.35, 1.0);
  }
  final chars = audio.inMilliseconds / 1000 * voiced * _kWordsPerSecond * _kCharsPerWord;
  return _linesFor(chars, width, fontSize);
}

/// Approximates how many lines [characters] of existing prose occupy laid out
/// at [width] in a [fontSize] body, so a regenerate's placeholder cloud is
/// shaped like the text it replaces. Pure, like [estimateInkLines].
int estimateTextInkLines({
  required int characters,
  required double width,
  required double fontSize,
}) => _linesFor(characters.toDouble(), width, fontSize);

int _linesFor(double characters, double width, double fontSize) {
  final charsPerLine = width / (fontSize * _kCharWidthEm);
  if (charsPerLine <= 0) return 1;
  return (characters / charsPerLine).ceil().clamp(1, _kMaxInkRows);
}

/// Lays believable lines of ink for text that does not exist yet: word-length
/// blocks with gaps, a full measure on every line but the last (which ends
/// mid-air the way a paragraph does), thinned so the field has glyph texture
/// rather than reading as solid bars. Deterministic: the same block always
/// shimmers the same shape.
Float32List placeholderInkPoints({
  required double width,
  required int lines,
  required double fontSize,
  required double lineHeight,
  int maxPoints = kMaxInkPoints,
}) {
  const step = 0.9; // the sampled-text grid spacing, so density matches
  final inkHeight = fontSize * _kInkHeightEm;
  final gap = fontSize * 0.45;
  final points = <double>[];
  var index = 0;
  for (var line = 0; line < lines; line++) {
    final top = line * lineHeight + (lineHeight - inkHeight) / 2;
    final last = line == lines - 1;
    final measure = last
        ? width * (0.35 + 0.4 * _rand(line, 11))
        : width * (0.94 + 0.06 * _rand(line, 12));
    var x = 0.0;
    var word = 0;
    while (x < measure) {
      final wordWidth = math.min(fontSize * (1.6 + 3.6 * _rand(line * 97 + word, 13)), measure - x);
      for (var px = x; px < x + wordWidth; px += step) {
        for (var py = top; py < top + inkHeight; py += step) {
          // Sparse fill: real glyphs ink only a fraction of their band, so a
          // low keep rate reads as strokes rather than a solid dark ribbon.
          if (_rand(index++, 14) < 0.3) {
            points.add(px);
            points.add(py);
          }
        }
      }
      x += wordWidth + gap;
      word++;
    }
  }
  return _capInkPoints(points, maxPoints);
}

/// Thins flat [x, y] pairs to [maxPoints] with a uniform stride, keeping even
/// coverage over the whole block rather than truncating its tail.
Float32List _capInkPoints(List<double> points, int maxPoints) {
  final count = points.length ~/ 2;
  if (count <= maxPoints) return Float32List.fromList(points);
  final stride = (count / maxPoints).ceil();
  final reduced = Float32List(2 * (count ~/ stride + 1));
  var j = 0;
  for (var i = 0; i < count; i += stride) {
    reduced[j++] = points[i * 2];
    reduced[j++] = points[i * 2 + 1];
  }
  return Float32List.sublistView(reduced, 0, j);
}

int _hash(int i, int salt) {
  var h = (i * 374761393 + salt * 668265263) & 0x7fffffff;
  h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
  return h;
}

double _rand(int i, int salt) => (_hash(i, salt) & 0xffff) / 0xffff;

class _InkPainter extends CustomPainter {
  _InkPainter(this.ink, this.color, this.clock) : super(repaint: clock);

  final Float32List? ink;
  final Color color;
  final Animation<double> clock;

  static const double _sizeMin = 1.4; // logical px, fine glitter, not blobs
  static const double _sizeVar = 1.8;
  static const double _wander = 1.0; // logical px each spark drifts around its point
  static const double _spread = 1.6; // static scatter off the sample grid

  // Medium so the small sparks downscale smoothly instead of reading as pixels.
  final Paint _atlasPaint = Paint()..filterQuality = FilterQuality.medium;
  Float32List? _transforms;
  Float32List? _rects;
  Int32List? _colors;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = this.ink;
    if (ink == null || ink.isEmpty) return;
    final count = ink.length ~/ 2;
    final sprite = _sparkSprite();
    final tf = _ensure(count);
    final rc = _rects!;
    final cl = _colors!;
    final v = clock.value;
    final sd = sprite.width.toDouble();
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    final rgb = (r << 16) | (g << 8) | b;
    const twoPi = 2 * math.pi;

    for (var i = 0; i < count; i++) {
      final phase = _rand(i, 2);
      // Whole-number harmonics of the clock, so the loop closes seamlessly.
      final k = 3 + (_hash(i, 7) % 5); // pulses per loop, kept slow
      final s = 0.5 + 0.5 * math.sin(twoPi * (k * v + phase));
      // Low duty: a spark is dark most of its cycle and flares brief and bright,
      // so only a fraction are lit at once and the field reads as glitter.
      final s2 = s * s;
      final a = (s2 * s2 * 255).round().clamp(0, 255);

      // Scatter off the sample grid (so it never reads as a lattice) plus one
      // slow circle around that point over the loop.
      final wp = twoPi * (v + phase);
      final x = ink[i * 2] + (_rand(i, 8) - 0.5) * _spread + _wander * math.cos(wp);
      final y = ink[i * 2 + 1] + (_rand(i, 9) - 0.5) * _spread + _wander * math.sin(wp);

      final px = _sizeMin + _rand(i, 4) * _sizeVar;
      final scale = px / sd;
      final o = i * 4;
      tf[o] = scale; // scos (no rotation; a soft dot needs none)
      tf[o + 1] = 0; // ssin
      tf[o + 2] = x - scale * sd / 2; // centre the sprite on (x, y)
      tf[o + 3] = y - scale * sd / 2;
      cl[i] = (a << 24) | rgb;
    }
    // modulate tints the white spark to the ink colour and scales its alpha.
    canvas.drawRawAtlas(sprite, tf, rc, cl, BlendMode.modulate, null, _atlasPaint);
  }

  Float32List _ensure(int n) {
    var tf = _transforms;
    if (tf == null || tf.length < n * 4) {
      tf = _transforms = Float32List(n * 4);
      final rc = _rects = Float32List(n * 4);
      _colors = Int32List(n);
      final sd = _sparkSprite().width.toDouble();
      for (var i = 0; i < n; i++) {
        final o = i * 4;
        rc[o + 2] = sd;
        rc[o + 3] = sd;
      }
    }
    return tf;
  }

  @override
  bool shouldRepaint(_InkPainter old) => old.ink != ink || old.color != color;

  // One crisp dot, built once and shared by every field: a solid core with a
  // thin anti-aliased edge, at high resolution so it downscales clean instead of
  // reading as a blurry blob. Rendered supersampled (64px) for a smooth rim.
  static ui.Image? _spark;

  static ui.Image _sparkSprite() {
    final cached = _spark;
    if (cached != null) return cached;
    const d = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = const RadialGradient(
        // Solid to most of the radius, then a quick soft falloff at the rim.
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.66, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, d, d));
    canvas.drawCircle(const Offset(d / 2, d / 2), d / 2, paint);
    return _spark = recorder.endRecording().toImageSync(d.toInt(), d.toInt());
  }
}
