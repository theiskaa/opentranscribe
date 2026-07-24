import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/player_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Fits [source] (however finely the file was read) onto [bars] bars, by taking
/// the LOUDEST value in each bar's slice, then stretching what is left between
/// its own quietest and loudest so the shape uses the full height.
///
/// Peak rather than average, for the same reason the file is read that way: an
/// average of averages flattens speech into a band, and what makes a wave worth
/// looking at is that a word stands above the silence around it. The stretch is
/// what separates a room's noise floor from speech - without it a recording made
/// in a quiet room and one made in a loud one look equally full. Asking for more
/// bars than there are values simply repeats them: a wave cannot invent detail
/// the read did not capture.
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
  // A recording of one unvarying level has no shape to stretch; leave it be
  // rather than dividing by nothing.
  if (span <= 0) return fitted;
  return [for (final value in fitted) (value - low) / span];
}

/// The entry's player: one control and the recording itself, in one pill. The
/// played part of the wave is ink, the rest is the quiet tone, and the split IS
/// the playhead - there is no thumb, because the boundary between what you have
/// heard and what you have not already sits exactly where a thumb would.
///
/// Dragging scrubs a local fraction and release commits the seek; a tap seeks
/// straight away. Scrubbing with nothing playing is a real instruction - the
/// cubit holds the position, and play picks it up.
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
    // After the frame: reading the file is a platform round trip, and the screen
    // is still arriving.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlayerCubit>().loadPeaks(widget.entry);
    });
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
        // The screen knows the entry's length before playback starts.
        final duration = state.duration == Duration.zero ? widget.entry.duration : state.duration;
        final fraction = _scrub ?? _fractionOf(state.position, duration);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ONE object: the control and the recording share a surface, so the
            // button reads as part of the player rather than as a circle parked
            // next to a graph.
            DecoratedBox(
              decoration: SuperellipseDecoration(
                // The app's card radius, like every other bordered surface in
                // it. A stadium would make this the one pill-shaped CONTAINER
                // in an app where the pill is reserved for buttons.
                borderRadius: AppRadius.card,
                color: theme.surface,
                border: BorderSide(color: theme.surfaceBorder),
              ),
              child: Padding(
                // Squarer on the right: the circle's mass ends at its own edge,
                // while a bare label needs clearance from the corner's curve.
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    _PlayButton(
                      playing: state.isPlaying,
                      onTap: () => context.read<PlayerCubit>().toggle(widget.entry),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // No clocks. The wave already says where you are and how much
                    // is left, in the one place you are looking; two timestamps
                    // would be the same fact again, in digits. The entry's
                    // duration is on the meta line above regardless.
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
                                // Cleared only after the seek is on the state, so
                                // the wave never falls back to where playback was
                                // for the frames the platform takes to answer.
                                setState(() => _scrub = null);
                              },
                              onTapUp: (details) => context.read<PlayerCubit>().seek(
                                duration * (details.localPosition.dx / width).clamp(0.0, 1.0),
                                duration: duration,
                              ),
                              child: _Wave(peaks: state.peaks, played: fraction, tokens: tokens),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _RateChip(
                      rate: state.rate,
                      onTap: () => context.read<PlayerCubit>().cycleRate(),
                    ),
                  ],
                ),
              ),
            ),
            // Beside the control, never instead of it: a later successful play
            // must stay one tap away.
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

/// The one control: a filled ink circle, the same ink the played wave is drawn
/// in, so the two read as one object rather than as a button beside a graph.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Touchable(
      onTap: onTap,
      pressedScale: theme.motion.pressIconScale,
      haptic: true,
      child: Container(
        width: theme.player.controlSize,
        height: theme.player.controlSize,
        decoration: BoxDecoration(color: theme.button.background, shape: BoxShape.circle),
        child: Center(
          child: AppIcon(
            playing ? AppIcons.pauseFill : AppIcons.playFill,
            size: theme.player.controlSize / 2.6,
            color: theme.button.foreground,
          ),
        ),
      ),
    );
  }
}

/// Playback speed, as the number itself. Cycles rather than opening a menu:
/// there are four speeds and one of them is normal, so normal is never more
/// than three taps away.
///
/// Bare text: no fill, no border. It sits inside a card that already has an
/// edge, beside a button that already has a shape - a third container here is
/// what made the card read as busy. Off normal it darkens to full ink, which is
/// the only signal it needs.
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
        // Full height, so the tap target is the row's and not the glyph's.
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

/// The wave itself. Sized in whole bars, and animated on the frame the file's
/// shape arrives: before that it draws its floor, which is what silence looks
/// like anyway, so nothing jumps and no spinner is needed.
class _Wave extends StatefulWidget {
  const _Wave({required this.peaks, required this.played, required this.tokens});

  final List<double> peaks;
  final double played;
  final PlayerTheme tokens;

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> {
  /// The shape at the current bar count. Held rather than derived in `paint`,
  /// which runs on every position tick and at pointer rate during a scrub, while
  /// this changes only when the read lands or the width does.
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
      // Keyed on whether there IS a shape, so the growth plays once, when the
      // read lands - not again on every position tick.
      key: ValueKey(widget.peaks.isEmpty),
      tween: Tween(begin: widget.peaks.isEmpty ? 1 : 0, end: 1),
      duration: context.theme.motion.crossfade,
      curve: Curves.easeOut,
      builder: (context, grown, _) => CustomPaint(
        size: Size(double.infinity, widget.tokens.waveHeight),
        painter: _WavePainter(
          shapeFor: _shapeFor,
          played: widget.played,
          grown: grown,
          tokens: widget.tokens,
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
      // Every bar starts at its own width and grows from there, so a silent
      // stretch is a row of dots on the midline rather than a hole in the
      // recording, and the loudest moment still reaches full height.
      final height = floor + span * shape[i] * grown;
      // The bar the playhead is inside belongs to what has been played: a bar is
      // a slice of time, and that slice has begun.
      paint.color = i < boundary ? tokens.progress : tokens.waveRemaining;
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
