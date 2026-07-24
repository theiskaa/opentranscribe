import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// The band's noise floor and ceiling, as fractions of the native level (which
/// already carries -60dB..0dB as 0..1). Room tone lives under -48dB and speech
/// peaks well before -9dB, so those bounds are where the expression is; without
/// the window the bars neither rest nor fill, and every take looks the same.
const double _floor = 0.20;
const double _ceiling = 0.85;

/// Bounds on the tracked sample cadence. The tap aims for ~20 Hz; anything far
/// outside this is a hiccup, not the rate, and must not be interpolated
/// against.
const int _minGapUs = 20000;
const int _maxGapUs = 120000;

/// One native level as a bar height, 0..1. Everything below the floor is
/// silence; the gentle curve past that lands ordinary speech tall rather than
/// hugging the baseline.
double waveformLevel(double raw) {
  final windowed = ((raw - _floor) / (_ceiling - _floor)).clamp(0.0, 1.0);
  return math.pow(windowed, 0.75).toDouble();
}

/// The live waveform, symmetric around the midline: the band is full from the
/// first frame (seeded with silence, so it rests as a dotted line on its
/// spine) and scrolls left at ONE rate for the whole take, newest at the right
/// edge. Bars fade in and out over the last [RecorderTheme.waveformFade] at
/// each end, so nothing is ever cut. Sample data lands at ~20 Hz; a ticker
/// interpolates the scroll offset between samples so motion stays frame-rate
/// smooth. Painting is driven by a repaint [Listenable] behind a
/// [RepaintBoundary]; a sample never rebuilds the screen. Paused: the ticker
/// stops and bars dim.
class Waveform extends StatefulWidget {
  const Waveform({required this.levels, required this.active, super.key});

  /// Normalized input levels (0..1).
  final Stream<double> levels;

  /// Whether capture runs right now; false freezes and dims the band.
  final bool active;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> with TickerProviderStateMixin {
  static const _capacity = 256;

  /// Seeded with silence, so the band is FULL from the first frame: it rests
  /// as a dotted line on its spine and starts scrolling the moment capture
  /// opens. A band that fills up first would have to move at a different rate
  /// while it did, and that change of behaviour is what reads as lag.
  final List<double> _samples = List.filled(_capacity, 0, growable: true);
  final _RepaintNotifier _repaint = _RepaintNotifier();

  /// Built in initState, never lazily: the band now mounts BEFORE capture
  /// starts, so a lazy ticker would first be touched in dispose, and creating
  /// one there looks up an ancestor of a deactivated element.
  late final Ticker _ticker;

  /// How live the band is, 0..1. Pausing does not switch the band off, it fades
  /// it out: the bars settle toward their idle colour and the spine goes with
  /// them, because a line through a frozen band reads as a scratch.
  late final AnimationController _activity;
  StreamSubscription<double>? _sub;

  /// Ticker time now and at the latest sample, for interpolating the scroll
  /// offset between samples. The ticker restarts from zero after a pause;
  /// the math self-heals on the first fresh sample.
  Duration _now = Duration.zero;
  Duration _lastSampleAt = Duration.zero;
  Duration _sampleGap = const Duration(milliseconds: 50);

  /// The last interpolation the band actually drew. A stopped ticker restarts
  /// its clock at zero, so on resume the elapsed time reads as BEFORE the last
  /// sample; holding the last value there keeps the band still until the next
  /// sample lands, instead of snapping a step right and back.
  double _fraction = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _now = elapsed;
      _repaint.repaint();
    });
    _activity = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.active ? 1 : 0,
    );
    _sub = widget.levels.listen(_onSample);
    if (widget.active) _ticker.start();
  }

  @override
  void didUpdateWidget(Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.levels, widget.levels)) {
      _sub?.cancel();
      _sub = widget.levels.listen(_onSample);
    }
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      if (!_ticker.isActive) _ticker.start();
      _activity.forward();
      return;
    }
    // The ticker runs on through the fade, so the band coasts into its last
    // step instead of stopping dead on the frame the tap landed.
    _activity.reverse().whenComplete(() {
      if (mounted && !widget.active && _ticker.isActive) _ticker.stop();
    });
  }

  /// How far the band has travelled toward the next sample, 0..1. Held at its
  /// last value whenever the clock cannot answer (no sample yet, or a ticker
  /// that restarted behind it), so the band never jumps sideways.
  double _scrollFraction() {
    if (_lastSampleAt == Duration.zero) return _fraction;
    final since = _now - _lastSampleAt;
    final gapUs = _sampleGap.inMicroseconds;
    if (since.isNegative || gapUs <= 0) return _fraction;
    return _fraction = (since.inMicroseconds / gapUs).clamp(0.0, 1.0);
  }

  void _onSample(double level) {
    final now = _ticker.isActive ? _now : Duration.zero;
    if (_lastSampleAt != Duration.zero && now > _lastSampleAt) {
      // Track the real cadence, but SMOOTHED: the engine's first buffers land
      // bursty, and taking the last interval raw makes the band race through
      // a step and then sit frozen until the next sample.
      final delta = now - _lastSampleAt;
      final blended = _sampleGap.inMicroseconds * 0.7 + delta.inMicroseconds * 0.3;
      _sampleGap = Duration(microseconds: blended.round().clamp(_minGapUs, _maxGapUs));
    }
    _lastSampleAt = now;
    // The new bar takes the position the interpolation was heading for, so the
    // travel restarts from nothing rather than doubling back.
    _fraction = 0;
    // Shaped on arrival, so the painter only ever draws heights.
    _samples.add(waveformLevel(level));
    if (_samples.length > _capacity) _samples.removeAt(0);
    if (!_ticker.isActive) _repaint.repaint();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker.dispose();
    _activity.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.recorder;
    return RepaintBoundary(
      child: SizedBox(
        height: tokens.waveformHeight,
        child: CustomPaint(
          painter: _WaveformPainter(
            // The fade repaints too: the ticker may already have stopped.
            repaint: Listenable.merge([_repaint, _activity]),
            samples: _samples,
            liveColor: tokens.waveformBar,
            idleColor: tokens.waveformBarIdle,
            baselineColor: tokens.waveformBaseline,
            activity: () => _activity.value,
            barWidth: tokens.waveformBarWidth,
            gap: tokens.waveformGap,
            fade: tokens.waveformFade,
            scrollFraction: _scrollFraction,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// [ChangeNotifier.notifyListeners] is protected; this names the one public
/// entry point the ticker and sample path use.
class _RepaintNotifier extends ChangeNotifier {
  void repaint() => notifyListeners();
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required Listenable repaint,
    required this.samples,
    required this.liveColor,
    required this.idleColor,
    required this.baselineColor,
    required this.activity,
    required this.barWidth,
    required this.gap,
    required this.fade,
    required this.scrollFraction,
  }) : super(repaint: repaint);

  final List<double> samples;
  final Color liveColor;
  final Color idleColor;
  final Color baselineColor;

  /// 0..1: how far the band is toward being live. Drives the bars' colour and
  /// the spine's presence together.
  final double Function() activity;
  final double barWidth;
  final double gap;
  final double fade;

  /// 0..1 progress toward the next sample, shifting all bars left so 20 Hz
  /// data reads as continuous motion.
  final double Function() scrollFraction;

  /// The spine's gradient, rebuilt only when the band's size or color changes.
  /// It never animates, so paying for it every frame would be pure waste on a
  /// canvas that repaints at 60 Hz.
  Shader? _spine;
  Size? _spineSize;
  Color? _spineColor;

  /// The band's own alpha ramp at both ends, so bars (and the spine) arrive and
  /// leave instead of being cut.
  double _edge(double x, double width) =>
      fade <= 0 ? 1 : Curves.easeOut.transform((math.min(x, width - x) / fade).clamp(0.0, 1.0));

  Shader _spineShader(Size size, Color color) {
    if (_spine != null && _spineSize == size && _spineColor == color) return _spine!;
    final stop = fade <= 0 ? 0.0 : (fade / size.width).clamp(0.0, 0.5);
    _spineSize = size;
    _spineColor = color;
    return _spine = ui.Gradient.linear(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      [color.withValues(alpha: 0), color, color, color.withValues(alpha: 0)],
      [0, stop, 1 - stop, 1],
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final step = barWidth + gap;
    final capacity = (size.width / step).floor();
    if (capacity <= 0) return;
    final mid = size.height / 2;
    final live = activity();
    final barColor = Color.lerp(idleColor, liveColor, live)!;

    // The spine: what silence rests on, and what makes the band an instrument
    // before the first sample arrives. One line under a gradient, so it carries
    // the band's fade without costing a draw call per segment. It belongs to
    // the LIVE band: over frozen bars it reads as a scratch, so it leaves with
    // them.
    if (live > 0.01) {
      canvas.drawLine(
        Offset(0, mid),
        Offset(size.width, mid),
        Paint()
          ..strokeWidth = 1
          ..shader = _spineShader(size, baselineColor.withValues(alpha: baselineColor.a * live)),
      );
    }

    if (samples.isEmpty) return;
    final visible = math.min(samples.length, capacity);

    // ONE behaviour, from the first frame to the last: newest at the right
    // edge, everything sliding left by a step per sample, interpolated between
    // them so 20 Hz data reads as continuous motion.
    final shift = scrollFraction() * step;

    for (var i = 0; i < visible; i++) {
      final sample = samples[samples.length - visible + i];
      final x = size.width - (visible - i) * step - shift + step;
      if (x < 0 || x > size.width) continue;
      paint.color = barColor.withValues(alpha: barColor.a * _edge(x, size.width));
      final half = math.max(barWidth / 2, sample * mid);
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  // The sample buffer is one mutated list for the widget's life, so it can
  // never differ here; the repaint Listenable is what actually drives painting.
  // Only a theme change needs a rebuild-driven repaint.
  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.liveColor != liveColor ||
      oldDelegate.idleColor != idleColor ||
      oldDelegate.baselineColor != baselineColor;
}
