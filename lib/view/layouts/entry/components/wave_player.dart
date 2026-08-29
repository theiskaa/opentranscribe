import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/player_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Fits [source] onto [bars] bars using each slice's LOUDEST value (an average
/// flattens speech into a band), then stretches min..max to full height so a
/// quiet room and a loud one don't look equally full.
List<double> resamplePeaks(List<double> source, int bars) {
  if (bars <= 0) return const [];
  if (source.isEmpty) return List<double>.filled(bars, 0);
  final fitted = [
    for (var i = 0; i < bars; i++)
      () {
        final from = i * source.length ~/ bars;
        final to = math.max(from + 1, (i + 1) * source.length ~/ bars);
        var peak = 0.0;
        for (var j = from; j < to && j < source.length; j++) {
          if (source[j] > peak) peak = source[j];
        }
        return peak;
      }(),
  ];
  var low = double.infinity;
  var high = 0.0;
  for (final value in fitted) {
    if (value < low) low = value;
    if (value > high) high = value;
  }
  final span = high - low;
  // One unvarying level has no shape to stretch; don't divide by zero.
  if (span <= 0) return fitted;
  return [for (final value in fitted) (value - low) / span];
}

/// How far the wave dims when not playing. Matches the recorder's paused dim.
const double _pausedWaveOpacity = 0.45;

/// The native player's position report interval (AudioPlayer.swift). The fill
/// tweens across one tick so it glides instead of stepping to each report.
const Duration _positionTick = Duration(milliseconds: 200);

/// The entry's player, drawn bare: the wave IS the play/pause control (tap
/// toggles, opacity shows state), the ink/quiet-tone split is the playhead, and
/// a speed chip sits beside it. Drag scrubs; release seeks.
class WavePlayer extends StatefulWidget {
  const WavePlayer({required this.entry, super.key});

  final Entry entry;

  @override
  State<WavePlayer> createState() => _WavePlayerState();
}

class _WavePlayerState extends State<WavePlayer> {
  /// 0..1 while a finger scrubs; null when the wave follows playback.
  double? _scrub;

  @override
  void initState() {
    super.initState();
    // Reading the file is a platform round trip; defer past first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlayerCubit>().loadPeaks(widget.entry);
    });
  }

  @override
  void didUpdateWidget(WavePlayer old) {
    super.didUpdateWidget(old);
    // The service's backfill landed the shape this wave was waiting for.
    if (old.entry.peaks == null && widget.entry.peaks != null) {
      context.read<PlayerCubit>().loadPeaks(widget.entry);
    }
  }

  double _fractionOf(Duration position, Duration duration) {
    if (duration == Duration.zero) return 0;
    return (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.player;
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<PlayerCubit, PlayerState>(
      builder: (context, state) {
        // Entry length is known before playback starts.
        final duration = state.duration == Duration.zero ? widget.entry.duration : state.duration;
        final fraction = _scrub ?? _fractionOf(state.position, duration);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) => setState(() {
                            _scrub = ((_scrub ?? fraction) + details.delta.dx / width).clamp(
                              0.0,
                              1.0,
                            );
                          }),
                          onHorizontalDragEnd: (_) {
                            final scrub = _scrub;
                            if (scrub != null) {
                              context.read<PlayerCubit>().seek(
                                duration * scrub,
                                duration: duration,
                              );
                            }
                            // Cleared only after the seek is on the state, so the
                            // wave never falls back to where playback was for the
                            // frames the platform takes to answer.
                            setState(() => _scrub = null);
                          },
                          onTapUp: (_) => context.read<PlayerCubit>().toggle(widget.entry),
                          child: AnimatedOpacity(
                            duration: theme.motion.crossfade,
                            opacity: state.isPlaying ? 1 : _pausedWaveOpacity,
                            child: _Wave(
                              peaks: state.peaks,
                              played: fraction,
                              // Glide only while self-advancing: a scrub tracks
                              // the finger 1:1, and a paused wave must not drift
                              // toward the last reported point.
                              smooth: state.isPlaying && _scrub == null,
                              tokens: tokens,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _RateChip(rate: state.rate, onTap: () => context.read<PlayerCubit>().cycleRate()),
              ],
            ),
            if (state.failed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  l10n.playbackFailed,
                  style: AppType.footnote.copyWith(color: theme.textSecondary),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Playback speed as the number itself. Cycles rather than opening a menu;
/// normal is never more than three taps away. Off normal it darkens to full ink.
class _RateChip extends StatelessWidget {
  const _RateChip({required this.rate, required this.onTap});

  final double rate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // 1x, not 1.0x; 1.25x keeps its quarter.
    final label = rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : '$rate';
    return Touchable(
      onTap: onTap,
      pressedScale: theme.motion.pressIconScale,
      haptic: true,
      child: SizedBox(
        // Tap target is the row's height, not the glyph's.
        height: theme.player.controlSize,
        child: Center(
          child: Text(
            '$label×',
            style: AppType.digits(
              AppType.callout,
            ).copyWith(color: rate == 1 ? theme.textSecondary : theme.text, height: 1),
          ),
        ),
      ),
    );
  }
}

/// The wave, sized in whole bars. Draws its floor until the file's shape
/// arrives, then grows into it, so nothing jumps and no spinner is needed.
class _Wave extends StatefulWidget {
  const _Wave({
    required this.peaks,
    required this.played,
    required this.smooth,
    required this.tokens,
  });

  final List<double> peaks;
  final double played;

  /// Whether the fill self-advances. Set: [played] tweens across one tick.
  /// Clear: it snaps, so a scrub tracks the finger and a stop holds still.
  final bool smooth;

  final PlayerTheme tokens;

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> {
  /// Held, not recomputed in paint (which runs every tick and at pointer rate);
  /// changes only when the read lands or the width does.
  List<double> _fitted = const [];
  List<double>? _from;
  int _bars = 0;

  List<double> _shapeFor(int bars) {
    if (bars != _bars || !identical(_from, widget.peaks)) {
      _bars = bars;
      _from = widget.peaks;
      _fitted = resamplePeaks(widget.peaks, bars);
    }
    return _fitted;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Keyed so the growth plays once, when the read lands.
      key: ValueKey(widget.peaks.isEmpty),
      tween: Tween(begin: widget.peaks.isEmpty ? 1 : 0, end: 1),
      duration: context.theme.motion.crossfade,
      curve: Curves.easeOut,
      builder: (context, grown, _) => TweenAnimationBuilder<double>(
        // Linearly bridges the gap between position reports. Linear (the
        // default) on purpose: playback is constant-rate, so an ease would
        // surge and stall each tick.
        tween: Tween<double>(end: widget.played),
        duration: widget.smooth ? _positionTick : Duration.zero,
        builder: (context, played, _) => CustomPaint(
          size: Size(double.infinity, widget.tokens.waveHeight),
          painter: _WavePainter(
            shapeFor: _shapeFor,
            played: played,
            grown: grown,
            tokens: widget.tokens,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.shapeFor,
    required this.played,
    required this.grown,
    required this.tokens,
  });

  final List<double> Function(int bars) shapeFor;
  final double played;
  final double grown;
  final PlayerTheme tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final step = tokens.waveBarWidth + tokens.waveGap;
    final bars = ((size.width + tokens.waveGap) / step).floor();
    if (bars <= 0) return;
    final shape = shapeFor(bars);
    final mid = size.height / 2;
    final boundary = played * bars;
    final floor = tokens.waveBarWidth;
    final span = tokens.waveHeight - floor;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = tokens.waveBarWidth;

    var x = tokens.waveBarWidth / 2;
    for (var i = 0; i < bars; i++) {
      // Floor height so silence is a row of dots, not a hole.
      final height = floor + span * shape[i] * grown;
      // The one bar the playhead sits in lerps between played and remaining, so
      // the leading edge dissolves instead of snapping colour whole.
      final fill = (boundary - i).clamp(0.0, 1.0);
      paint.color = Color.lerp(tokens.waveRemaining, tokens.progress, fill)!;
      canvas.drawLine(Offset(x, mid - height / 2), Offset(x, mid + height / 2), paint);
      x += step;
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.played != played ||
      old.grown != grown ||
      old.shapeFor != shapeFor ||
      old.tokens != tokens;
}
