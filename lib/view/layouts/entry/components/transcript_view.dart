import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/audio/playback.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/player_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/shimmer.dart';

/// The transcript body. Where the transcript carries timings, it is a second
/// way through the recording: the segment under the playhead is MARKED (never
/// the rest dimmed), and TAPPING a sentence plays from it. Untranscribed entries
/// get a quiet explanation and a transcribe action.
class TranscriptView extends StatefulWidget {
  const TranscriptView({required this.entry, required this.busy, super.key});

  final Entry entry;
  final bool busy;

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  /// One recognizer per segment, rebuilt when the segments change and disposed
  /// with the widget. Gesture recognizers on spans are not owned by the span:
  /// nothing else will ever free them.
  List<TapGestureRecognizer> _taps = const [];

  @override
  void didUpdateWidget(TranscriptView old) {
    super.didUpdateWidget(old);
    if (old.entry.transcript != widget.entry.transcript) _buildTaps();
  }

  void _buildTaps() {
    for (final tap in _taps) {
      tap.dispose();
    }
    final segments = widget.entry.transcript?.segments ?? const <TranscriptSegment>[];
    _taps = [
      for (final segment in segments)
        TapGestureRecognizer()
          ..onTap = () =>
              context.read<PlayerCubit>().seek(segment.start, duration: widget.entry.duration),
    ];
  }

  @override
  void dispose() {
    for (final tap in _taps) {
      tap.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    // A run in flight (first transcribe or re-transcribe): a shimmering
    // skeleton in the transcript's own place, so the wait reads as the words
    // arriving rather than a spinner parked over the page.
    if (widget.busy) return const _TranscriptSkeleton();

    final transcript = widget.entry.transcript;
    final text = transcript?.fullText.trim() ?? '';
    if (transcript == null || text.isEmpty) {
      // Two different silences: never transcribed (the action lives in the
      // screen's bottom CTA) versus transcribed and empty (no speech, no action).
      return _TranscriptEmpty(untranscribed: transcript == null);
    }

    final segments = transcript.segments;
    if (segments.isEmpty) {
      return Text(text, style: AppType.body.copyWith(color: theme.text));
    }
    if (_taps.length != segments.length) _buildTaps();

    // Selected off the state, not built from it: the native side ticks five
    // times a second, and the paragraph only changes when the LIT SEGMENT does.
    // Rebuilding every span on every tick was re-laying out the whole
    // transcript four times out of five for nothing.
    return BlocSelector<PlayerCubit, PlayerState, int?>(
      selector: (player) => player.status == PlaybackStatus.stopped
          ? null
          : activeSegmentIndex(segments, player.position),
      builder: (context, active) {
        final highlight = Paint()..color = theme.player.activeSegmentHighlight;
        return Text.rich(
          TextSpan(
            children: [
              for (final (i, segment) in segments.indexed)
                TextSpan(
                  text: i == segments.length - 1 ? segment.text : '${segment.text} ',
                  recognizer: _taps[i],
                  style: AppType.body.copyWith(
                    color: theme.player.segmentColor,
                    // The rest of the transcript is NOT dimmed. Reading is the
                    // point of this screen, and dimming everything you are not
                    // hearing makes the page worse at it; the lit segment
                    // carries a mark instead, so following the audio costs the
                    // rest of the text nothing.
                    background: i == active ? highlight : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The transcript placeholder while a run is in flight: a paragraph of shimmering
/// lines in the transcript's own column. The short lines close paragraphs, so the
/// block reads as prose taking shape, not a loading bar.
class _TranscriptSkeleton extends StatelessWidget {
  const _TranscriptSkeleton();

  /// Line lengths as percents of the text column. A ragged run with two short
  /// breaks, so it reads as sentences rather than an even stack.
  static const _widths = [100, 100, 92, 100, 60, 100, 95, 100, 45];

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.player;
    return Shimmer(
      base: tokens.skeletonBase,
      highlight: tokens.skeletonHighlight,
      builder: (color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, width) in _widths.indexed)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == _widths.length - 1 ? 0 : tokens.skeletonLineGap,
              ),
              // Expanded flexes give a bounded fractional width with no reliance
              // on the parent's main-axis constraints; the tail keeps the line
              // left-aligned when it is short.
              child: SizedBox(
                height: tokens.skeletonLineHeight,
                // Stretch, so each bar fills the line's height; an Expanded only
                // pins the width, and a bare DecoratedBox would otherwise be
                // zero pixels tall and paint nothing.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: width,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(tokens.skeletonRadius),
                        ),
                      ),
                    ),
                    if (width < 100) Expanded(flex: 100 - width, child: const SizedBox()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The empty transcript, left-aligned in the document flow under the player,
/// the same "first page of the journal" voice as [HomeEmpty]. Two messages: a
/// recording never transcribed (its action is the screen's bottom CTA) or one
/// transcribed to nothing. A smaller type scale than [HomeEmpty] on purpose:
/// this is nested content below the title, date, and wave, not a full page.
class _TranscriptEmpty extends StatelessWidget {
  const _TranscriptEmpty({required this.untranscribed});

  final bool untranscribed;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          untranscribed ? l10n.entryUntranscribedTitle : l10n.entryNoSpeechTitle,
          style: AppType.title.copyWith(color: theme.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          untranscribed ? l10n.entryUntranscribedMessage : l10n.entryNoSpeechMessage,
          style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}
