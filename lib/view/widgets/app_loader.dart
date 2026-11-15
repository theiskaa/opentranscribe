import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';

/// The brand wave's inner five bars: the loader's word, at full voice.
const List<double> passBars = [0.65, 1.0, 0.7, 0.5, 0.85];

/// One loop: a word passing through the row, then a rest.
const Duration passPeriod = Duration(milliseconds: 1400);

/// The loop is eight bars wide for five bars drawn, so for about a quarter of
/// it every bar is a dot: the pause between words.
const double _loopBars = 8;
const double _crestWidth = 0.7;
const double _crestStart = 1.5;

/// Where the crest rests under Reduce Motion: on the centre bar.
const double passRestingLoop = 0.4375;

const Duration _breathPeriod = Duration(milliseconds: 2400);
const Duration _fadeIn = Duration(milliseconds: 250);

/// How far bar [index] stands between its dot (0) and its full height (1) at
/// loop position [u] in `[0, 1)`: a crest travelling left to right through the
/// row, wrapped over the wider loop so it leaves before it returns.
double passLift(double u, int index) {
  final distance = index - (u * _loopBars - _crestStart);
  final wrapped = distance - _loopBars * (distance / _loopBars).roundToDouble();
  return math.exp(-wrapped * wrapped / (2 * _crestWidth * _crestWidth));
}

/// The Reduce Motion loader's opacity at [elapsed]: a slow breath from 1 down
/// to 0.4 and back, so a still mark still says it is working.
double passBreath(Duration elapsed) =>
    0.7 + 0.3 * math.cos(2 * math.pi * elapsed.inMicroseconds / _breathPeriod.inMicroseconds);

/// The app's one loader, "Pass": five dots rest on the recorder's line and a
/// spoken word passes through them, lifting each into its bar and letting it
/// down again. Silence as dots and speech as bars, the recorder's own grammar,
/// in [color] (the page's secondary ink when null). It opens on the loop's
/// first frame with a short fade, never a rise. Under Reduce Motion the word
/// holds on the centre bar and the mark breathes instead.
class AppLoader extends StatefulWidget {
  const AppLoader({this.size = AppLoaderSize.control, this.color, super.key});

  final double size;
  final Color? color;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with SingleTickerProviderStateMixin {
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => _elapsed.value = elapsed)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PassPainter(
            elapsed: _elapsed,
            color: widget.color ?? context.theme.textSecondary,
            reduce: context.reduceMotion,
          ),
        ),
      ),
    );
  }
}

class _PassPainter extends CustomPainter {
  _PassPainter({required this.elapsed, required this.color, required this.reduce})
    : super(repaint: elapsed);

  final ValueNotifier<Duration> elapsed;
  final Color color;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final t = elapsed.value;
    final fade = Curves.easeOutCubic.transform(
      (t.inMicroseconds / _fadeIn.inMicroseconds).clamp(0.0, 1.0),
    );
    final alpha = fade * (reduce ? passBreath(t) : 1);
    if (alpha <= 0) return;
    // One opacity for the whole mark, so the line never shows through a bar
    // while it fades or breathes.
    final layered = alpha < 1;
    if (layered) {
      canvas.saveLayer(
        Offset.zero & Size.square(s),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
    final u = reduce
        ? passRestingLoop
        : (t.inMicroseconds % passPeriod.inMicroseconds) / passPeriod.inMicroseconds;

    final mid = s / 2;
    // The recorder's line, faint and faded at both ends.
    final spine = math.max(1.0, s / 30);
    final line = color.withValues(alpha: color.a * 0.22);
    canvas.drawRect(
      Rect.fromLTWH(0.04 * s, mid - spine / 2, 0.92 * s, spine),
      Paint()
        ..shader = LinearGradient(
          colors: [line.withValues(alpha: 0), line, line, line.withValues(alpha: 0)],
          stops: const [0, 0.22, 0.78, 1],
        ).createShader(Rect.fromLTWH(0.04 * s, 0, 0.92 * s, s)),
    );

    final bar = math.max(1.5, 0.12 * s);
    final pitch = 0.19 * s;
    final full = 0.84 * s;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bar;
    for (var i = 0; i < passBars.length; i++) {
      final x = mid + (i - 2) * pitch;
      final height = bar + (full * passBars[i] - bar) * passLift(u, i);
      // Round caps add half a bar at each end; a dot keeps a sliver of line,
      // since a renderer may drop a zero-length one.
      final reach = math.max((height - bar) / 2, 0.01);
      canvas.drawLine(Offset(x, mid - reach), Offset(x, mid + reach), paint);
    }
    if (layered) canvas.restore();
  }

  @override
  bool shouldRepaint(_PassPainter old) => old.color != color || old.reduce != reduce;
}
