import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// The pull-to-record state machine, fed from the home list's scroll
/// notifications. [pull] mirrors the top overscroll in pixels; pulling past
/// [threshold] arms the gesture ([onArm]), backing out below the disarm
/// fraction releases it ([onDisarm]), and lifting the finger while armed
/// fires exactly once per gesture ([onFire]).
class PullToRecordGesture {
  PullToRecordGesture({required this.onArm, required this.onDisarm, required this.onFire});

  static const double threshold = 90;

  /// Backing out of an armed pull releases it well before the threshold, so
  /// the edge cannot chatter.
  static const double _disarmFraction = 0.7;

  final VoidCallback onArm;
  final VoidCallback onDisarm;
  final VoidCallback onFire;

  final ValueNotifier<double> pull = ValueNotifier(0);
  bool _armed = false;
  bool _fired = false;
  bool _wasDragging = false;

  /// Feed every vertical scroll update through here.
  void update({required double pixels, required bool dragging}) {
    // The finger lifted: an armed pull commits now, before the spring-back.
    final committed = _wasDragging && !dragging && _armed && !_fired;
    if (committed) {
      _fired = true;
      onFire();
    }
    _wasDragging = dragging;

    // A committed pull reads zero for the rest of the gesture: the recorder is
    // already rising, and the hint riding the spring-back up behind it belongs
    // to a gesture that is over. (Assigning zero before the line below would do
    // nothing - listeners rebuild on the next frame, so only the last value in
    // a turn is ever painted.)
    pull.value = committed || pixels >= 0 ? 0.0 : -pixels;
    if (dragging && !_armed && pull.value >= threshold) {
      _armed = true;
      onArm();
    } else if (dragging && _armed && pull.value < threshold * _disarmFraction) {
      _armed = false;
      onDisarm();
    }
  }

  /// The scroll settled: everything resets for the next gesture.
  void settle() {
    pull.value = 0;
    _armed = false;
    _fired = false;
    _wasDragging = false;
  }

  void dispose() => pull.dispose();
}

/// How much of a bar's height the travelling wave can eat at its trough, and
/// how far each bar lags the one before it (a little under one full wave across
/// the seven).
const double _swellDepth = 0.45;
const double _swellLag = 0.8;

/// Where in a bar's own growth the wave takes over from the drag. Early, at
/// 60%: waiting for full size leaves the row stiff for most of the pull, and
/// the swell blending in while the bar is still rising is what makes the two
/// motions read as one.
const double _wakeFrom = 0.6;

/// How alive one bar is, from its own scrubbed growth [local] (0..1). The wave
/// takes over as the bar RISES, not when the gesture arms: waiting for the
/// threshold leaves the row frozen for the last stretch of the pull. Because
/// each bar grows on its own delay, the wave wakes across the row in the same
/// order the bars did.
double pullBarAlive(double local) =>
    Curves.easeIn.transform(((local - _wakeFrom) / (1 - _wakeFrom)).clamp(0.0, 1.0));

/// The wave's multiplier for one bar: 1 while the bar is still growing with the
/// drag, and a travelling swell once it is [alive]. It only ever eats into a
/// bar's scrubbed height, so no bar can grow past the band it was drawn in.
double pullBarSwell(int index, double phase, double alive) {
  if (alive <= 0) return 1;
  final wave = 0.5 + 0.5 * math.sin(phase - index * _swellLag);
  return 1 - _swellDepth * alive * (1 - wave);
}

/// The pull at which the first bar starts waking, so the ticker runs from then
/// on and not a frame before.
const double _wavePull = _wakeFrom / 1.4;

/// The affordance in the gap a record pull opens: a small waveform whose bars
/// grow with the pull beside a quiet label, riding into the gap at half the
/// pull's speed (the reeed indicator), both darkening to ink at the threshold.
/// As each bar TOPS OUT it stops reading the drag and comes alive, so a wave
/// travels across the row and keeps travelling while the finger holds: by the
/// time the gesture arms, the hint already looks like a microphone listening.
class PullToRecordHint extends StatefulWidget {
  const PullToRecordHint({required this.pull, required this.threshold, super.key});

  final ValueListenable<double> pull;
  final double threshold;

  @override
  State<PullToRecordHint> createState() => _PullToRecordHintState();
}

class _PullToRecordHintState extends State<PullToRecordHint> with TickerProviderStateMixin {
  static const double _waveHeight = 28;

  /// The hint travels at half the pull and stops early, so it reads as
  /// surfacing from under the strip rather than being dragged.
  static const double _parallax = 0.5;
  static const double _travel = 44;

  late final AnimationController _phase = AnimationController(vsync: this);
  bool _waving = false;

  @override
  void initState() {
    super.initState();
    widget.pull.addListener(_onPull);
  }

  @override
  void didUpdateWidget(PullToRecordHint old) {
    super.didUpdateWidget(old);
    if (identical(old.pull, widget.pull)) return;
    old.pull.removeListener(_onPull);
    widget.pull.addListener(_onPull);
  }

  /// The clock runs from the moment the first bar starts waking until the pull
  /// lets go of it. How much of the wave shows is the painter's business, per
  /// bar; nothing ticks before there is a bar to move.
  void _onPull() {
    final waving = widget.pull.value >= widget.threshold * _wavePull;
    if (waving == _waving) return;
    _waving = waving;
    if (!waving) {
      _phase.stop();
      return;
    }
    _phase
      ..duration = context.read<ThemeCubit>().state.resolved.motion.pullWave
      ..repeat();
  }

  @override
  void dispose() {
    widget.pull.removeListener(_onPull);
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final barWidth = theme.recorder.waveformBarWidth;
    final gap = theme.recorder.waveformGap;
    final width =
        _PullWavePainter.pattern.length * barWidth + (_PullWavePainter.pattern.length - 1) * gap;
    return ValueListenableBuilder<double>(
      valueListenable: widget.pull,
      builder: (context, px, _) {
        final t = (px / widget.threshold).clamp(0.0, 1.0);
        if (t == 0) return const SizedBox.shrink();
        // Ink, not a hue: the app carries no colour at all, so the commitment
        // is expressed by the hint darkening as it arms.
        final color = Color.lerp(theme.textSecondary, theme.text, Curves.easeIn.transform(t))!;
        return Opacity(
          opacity: (t * 2).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (px * _parallax).clamp(0.0, _travel) - _travel / 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: Size(width, _waveHeight),
                  painter: _PullWavePainter(
                    repaint: _phase,
                    progress: t,
                    phase: () => _phase.value * 2 * math.pi,
                    color: color,
                    barWidth: barWidth,
                    gap: gap,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(l10n.homePullToRecord, style: AppType.callout.copyWith(color: color)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PullWavePainter extends CustomPainter {
  const _PullWavePainter({
    required Listenable repaint,
    required this.progress,
    required this.phase,
    required this.color,
    required this.barWidth,
    required this.gap,
  }) : super(repaint: repaint);

  final double progress;

  /// The travelling wave's position in radians. Read per frame: the controller
  /// drives the repaint.
  final double Function() phase;
  final Color color;
  final double barWidth;
  final double gap;

  static const pattern = [0.35, 0.65, 1.0, 0.7, 0.5, 0.85, 0.4];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    var x = barWidth / 2;
    final mid = size.height / 2;
    final now = phase();
    for (var i = 0; i < pattern.length; i++) {
      // Each bar rises in its own slightly offset window, so the wave builds
      // across the row as the pull deepens; as a bar tops out the swell takes
      // over from the drag and keeps travelling.
      final local = (progress * 1.4 - i * 0.06).clamp(0.0, 1.0);
      final scrubbed = size.height * pattern[i] * Curves.easeOutCubic.transform(local);
      final h = math.max(barWidth, scrubbed * pullBarSwell(i, now, pullBarAlive(local)));
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_PullWavePainter old) =>
      old.progress != progress || old.color != color || old.barWidth != barWidth || old.gap != gap;
}
