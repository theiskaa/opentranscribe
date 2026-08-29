import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/view/layouts/entry/components/append_ink.dart';
import 'package:opentranscribe/core/state/player_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:transcriber/transcriber.dart';

/// The transcript body. Where the transcript carries timings, the segment under
/// the playhead is MARKED (never the rest dimmed, and never on a hand-edited
/// entry, whose words the timings no longer name). The text selects and copies
/// through the enclosing SelectableRegion; seeking is the wave scrubber's job.
/// Untranscribed entries get a quiet explanation and a transcribe action.
///
/// A re-transcribe crossfades the existing words into an iMessage-style
/// invisible-ink shimmer, holds that living cloud while the run is in flight,
/// then crossfades into the new text. A first transcribe has no words to
/// dissolve, so it shimmers a placeholder instead: lines of ink sized by the
/// recording's length and envelope, resolving into the real text when the run
/// lands. Reduce motion (or a failed capture) falls back to the dots loader.
class TranscriptView extends StatefulWidget {
  const TranscriptView({
    required this.entry,
    required this.busy,
    this.appending = false,
    this.pendingText = '',
    super.key,
  });

  final Entry entry;
  final bool busy;

  /// A take is being added to this entry: the words stay readable and ink
  /// shaped like [pendingText] shimmers under them until the landing, when
  /// it resolves into the words that arrived.
  final bool appending;

  /// What the take's live pass heard, so the ink under the words is as many
  /// lines as the words about to land.
  final String pendingText;

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

enum _Phase { content, shimmer, loading }

class _TranscriptViewState extends State<TranscriptView> with TickerProviderStateMixin {
  /// How long the formed ink holds before it is allowed to resolve, so a
  /// near-instant re-transcribe still shows the full shimmer rather than a blink.
  static const Duration _minHold = Duration(milliseconds: 500);

  /// Wraps the rendered text so a re-transcribe can grab its last painted frame.
  final GlobalKey _textKey = GlobalKey();

  /// 1 shows the text, 0 shows the ink cloud; the crossfade between them.
  /// Created in [initState], never lazily: a view disposed without ever
  /// shimmering must not create its ticker during teardown.
  late final AnimationController _reveal;
  late final Animation<double> _hide;

  /// A seamless 0..1 loop driving the shimmer while it is up; its lap is
  /// [AppMotion.inkLoop], read when the shimmer starts.
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, value: 1);
    _hide = ReverseAnimation(_reveal);
    _clock = AnimationController(vsync: this);
    _append = AnimationController(vsync: this, value: 1);
    _appendEase = CurvedAnimation(parent: _append, curve: Curves.easeInOut);
  }

  late _Phase _phase = widget.busy ? _Phase.loading : _Phase.content;
  ui.Image? _inkImage;

  /// The ink of a continuation: 0 shows the ink over the words about to land,
  /// 1 the landed words.
  late final AnimationController _append;
  late final Animation<double> _appendEase;
  Float32List? _appendPoints;
  Size? _appendSize;
  double _appendTop = 0;
  _AppendKey? _appendFor;
  _AppendKey? _appendWanted;
  bool _appendPainting = false;
  int _appendJob = 0;

  /// A landing whose ink is being reshaped before it dissolves.
  bool _landing = false;

  /// Where the landed words begin, while they fade in: the old text's length
  /// for a plain paragraph, the old segment count for a timed one.
  int? _tailStart;
  int? _tailIndex;

  /// Synthetic ink for a first transcribe, where there is no text to capture.
  Float32List? _inkPoints;
  Size? _inkSize;
  double _inkDpr = 1;

  /// Identifies the current shimmer, so a delayed callback from a superseded run
  /// cannot resolve the wrong one.
  int _run = 0;

  /// The ink has formed AND held its beat (ready to resolve), and the new
  /// transcript has landed. The reveal waits for BOTH.
  bool _inkSettled = false;
  bool _newReady = false;

  @override
  void didUpdateWidget(TranscriptView old) {
    super.didUpdateWidget(old);

    if (!old.appending && widget.appending) {
      // A take starting inside the last landing's fade: setting the value
      // cancels that ticker without its whenComplete, so clear here.
      _tailStart = null;
      _tailIndex = null;
      _releaseAppendInk();
      if (!context.reduceMotion) {
        _append.value = 0;
        _runClock();
      }
    } else if (old.appending && !widget.appending) {
      _landAppend(old.entry);
    }

    if (!old.busy && widget.busy) {
      // A run started. Dissolve the words if there are any; a first transcribe
      // shimmers a placeholder shaped like the transcript the audio should
      // produce instead. Reduce motion (or a failed prep) shows the loader.
      final hadText = old.entry.readableText?.trim().isNotEmpty ?? false;
      if (context.reduceMotion) {
        _phase = _Phase.loading;
      } else if (hadText ? _captureText() : _prepareInkLines()) {
        _startHide();
      } else {
        _phase = _Phase.loading;
      }
    } else if (old.busy && !widget.busy) {
      // The run landed. New words reveal once the ink has settled; a run that
      // produced nothing steps aside at once so the error surface, not the
      // shimmer, gets the stage.
      if (_phase == _Phase.shimmer) {
        if (old.entry.transcript != widget.entry.transcript) {
          _newReady = true;
          _tryReveal(_run);
        } else {
          _failReveal();
        }
      } else {
        _phase = _Phase.content;
        _stopShimmer();
      }
    }
  }

  /// The words a [entry] lays out as: its segments joined the way the timed
  /// paragraph draws them, else what it reads as. One source, so the ink and
  /// the paragraph under it never disagree on where a line breaks.
  static String _paragraphText(Entry entry) {
    final segments = entry.transcript?.segments ?? const <TranscriptSegment>[];
    if (segments.isEmpty || !entry.readsAsTranscript) return entry.readableText?.trim() ?? '';
    return segments.map((s) => s.text).join(' ');
  }

  /// The take landed: its words fade in where the ink was, and the ink shrinks
  /// away. Nothing new (a silent take, a fallback) just drops the ink.
  void _landAppend(Entry old) {
    final before = _paragraphText(old);
    final after = _paragraphText(widget.entry);
    // Only words added after the old ones fade in as a tail; a landing that
    // replaced the text (a whole-file pass) just swaps.
    final grew = after.length > before.length && after.startsWith(before);
    final layout = _appendFor;
    if (!grew || _append.value != 0 || _appendPoints == null || layout == null) {
      _swapAppend();
      return;
    }
    _tailStart = before.length;
    _tailIndex = old.transcript?.segments.length ?? 0;
    _landing = true;
    // The words that landed may differ from the live ones the ink was shaped
    // by: reshape first, then dissolve, so the ink never blinks mid-fade.
    final landed = after.substring(before.length).trim();
    if (landed == layout.pending.trim()) {
      _dissolveAppend();
      return;
    }
    final key = (base: before, pending: landed, width: layout.width, scaler: layout.scaler);
    _appendWanted = null;
    unawaited(_paintAppendInk(key).then((ready) => ready ? _dissolveAppend() : _swapAppend()));
  }

  /// No dissolve to run: the words show at once and the ink goes.
  void _swapAppend() {
    if (!mounted) return;
    setState(() {
      _append.value = 1;
      _tailStart = null;
      _tailIndex = null;
      _landing = false;
      _releaseAppendInk();
    });
  }

  void _dissolveAppend() {
    if (!mounted) return;
    _landing = false;
    _append.duration = context.motionNow.inkResolve;
    _append.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _tailStart = null;
        _tailIndex = null;
        _releaseAppendInk();
      });
    });
  }

  void _runClock() {
    if (_clock.isAnimating) return;
    _clock
      ..duration = context.motionNow.inkLoop
      ..repeat();
  }

  void _releaseAppendInk() {
    _appendJob++;
    _appendPoints = null;
    _appendSize = null;
    _appendFor = null;
    _appendWanted = null;
    _appendPainting = false;
    if (_phase != _Phase.shimmer) _clock.stop();
  }

  /// Ink that is [pendingText] laid out after the words on screen; one paint
  /// in flight at a time, the newest ask painted when it lands.
  void _ensureAppendInk(double width, TextScaler scaler) {
    final key = (
      base: _paragraphText(widget.entry),
      pending: widget.pendingText,
      width: width,
      scaler: scaler,
    );
    if (_appendFor == key || _appendWanted == key) return;
    if (_appendPainting) {
      _appendWanted = key;
      return;
    }
    unawaited(_paintAppendInk(key));
  }

  /// Paints the words and samples their ink; a newer request or a release in
  /// flight drops the result. Answers whether the ink landed.
  Future<bool> _paintAppendInk(_AppendKey key) async {
    final job = ++_appendJob;
    _appendPainting = true;
    _appendFor = key;
    final bold = MediaQuery.boldTextOf(context);
    ({Float32List points, Size size, double top})? ink;
    try {
      ink = await appendedInkPoints(
        base: key.base,
        addition: key.pending,
        width: key.width,
        style: bold ? AppType.body.copyWith(fontWeight: FontWeight.bold) : AppType.body,
        textScaler: key.scaler,
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
        color: context.themeNow.player.segmentColor,
        locale: Localizations.maybeLocaleOf(context),
      );
    } catch (_) {
      ink = null;
    }
    if (!mounted || job != _appendJob) return false;
    _appendPainting = false;
    final wanted = _appendWanted;
    if (wanted != null && wanted != key) {
      _appendWanted = null;
      unawaited(_paintAppendInk(wanted));
    }
    if (ink == null) return false;
    setState(() {
      _appendPoints = ink!.points;
      _appendSize = ink.size;
      _appendTop = ink.top;
    });
    return true;
  }

  /// Text -> ink, then hold. The reveal is gated on this finishing, so it never
  /// races a fast re-transcribe.
  void _startHide() {
    final run = ++_run;
    _inkSettled = false;
    _newReady = false;
    _phase = _Phase.shimmer;
    _runClock();
    _reveal.duration = context.motionNow.inkDissolve;
    _reveal.reverse().whenComplete(() {
      Future<void>.delayed(_minHold, () {
        if (!mounted || run != _run) return;
        _inkSettled = true;
        _tryReveal(run);
      });
    });
  }

  /// A failed run's exit: a quick crossfade back to what was there, skipping
  /// the hold and the slow arrival, which are earned by new words only.
  void _failReveal() {
    final run = ++_run;
    _reveal.duration = context.motionNow.crossfade;
    _reveal.forward().whenComplete(() {
      if (mounted && run == _run && _phase == _Phase.shimmer) {
        setState(() => _phase = _Phase.content);
        _stopShimmer();
      }
    });
  }

  /// Ink -> new text, but only once the ink has settled and the words are ready.
  void _tryReveal(int run) {
    if (run != _run || !_inkSettled || !_newReady || _phase != _Phase.shimmer) return;
    _reveal.duration = context.motionNow.inkResolve;
    _reveal.forward().whenComplete(() {
      if (mounted && run == _run && _phase == _Phase.shimmer) {
        setState(() => _phase = _Phase.content);
        _stopShimmer();
      }
    });
  }

  /// Grabs the transcript's last painted frame into an image the shimmer draws
  /// from. Returns whether a usable frame was captured.
  bool _captureText() {
    final boundary = _textKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return false;
    if (!boundary.hasSize || boundary.size.isEmpty) return false;
    try {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      _releaseInk();
      _inkImage = boundary.toImageSync(pixelRatio: dpr);
      // A plain copy: RenderBox.size hands back a debug size that tracks its
      // owner, and reusing it once the boundary detaches trips debugAdoptSize.
      _inkSize = Size(boundary.size.width, boundary.size.height);
      _inkDpr = dpr;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Builds the placeholder a first transcribe shimmers: estimated lines of
  /// word-shaped ink, sized by the recording's length and amplitude envelope.
  /// Returns whether the layout gave a usable width.
  bool _prepareInkLines() {
    // Not context.size: Element.size asserts during build, and didUpdateWidget
    // runs inside it. The render box still carries last frame's size.
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final width = box.size.width;
    if (width <= 0) return false;
    const style = AppType.body;
    final fontSize = style.fontSize!;
    final lineHeight = fontSize * style.height!;
    final lines = estimateInkLines(
      audio: widget.entry.duration,
      width: width,
      fontSize: fontSize,
      peaks: widget.entry.peaks,
    );
    _releaseInk();
    _inkPoints = placeholderInkPoints(
      width: width,
      lines: lines,
      fontSize: fontSize,
      lineHeight: lineHeight,
    );
    _inkSize = Size(width, lines * lineHeight);
    return true;
  }

  void _stopShimmer() {
    if (_appendPoints == null) _clock.stop();
    _releaseInk();
  }

  void _releaseInk() {
    _inkImage?.dispose();
    _inkImage = null;
    _inkPoints = null;
    _inkSize = null;
  }

  @override
  void dispose() {
    _reveal.dispose();
    _append.dispose();
    _clock.dispose();
    _releaseInk();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    // The shimmer: the real text and the ink cloud stacked, crossfaded by
    // [_reveal]. The text layer is the OLD words while a run is in flight (they
    // fade under the cloud) and the NEW words once it lands (they fade back in),
    // so one crossfade covers both halves with nothing ever snapping. A first
    // transcribe has no old words; its cloud is the placeholder lines instead.
    final inkSize = _inkSize;
    final inkImage = _inkImage;
    final inkPoints = _inkPoints;
    if (_phase == _Phase.shimmer && inkSize != null && (inkImage != null || inkPoints != null)) {
      return Stack(
        children: [
          // Opacity does not block hit testing: the IgnorePointer keeps the
          // fading text out of the SelectableRegion while the shimmer is up, so
          // a selection cannot start on words mid-dissolve.
          IgnorePointer(
            child: FadeTransition(opacity: _reveal, child: _content(context)),
          ),
          IgnorePointer(
            child: RepaintBoundary(
              child: FadeTransition(
                opacity: _hide,
                child: inkImage != null
                    ? InvisibleInk(
                        image: inkImage,
                        size: inkSize,
                        pixelRatio: _inkDpr,
                        color: theme.player.segmentColor,
                        clock: _clock,
                      )
                    : InvisibleInk.points(
                        points: inkPoints!,
                        size: inkSize,
                        color: theme.player.segmentColor,
                        clock: _clock,
                      ),
              ),
            ),
          ),
        ],
      );
    }

    final loading = _phase == _Phase.loading;
    final body = AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
      layoutBuilder: meltStack,
      child: loading
          ? const _QuietWait(key: ValueKey('loading'))
          : KeyedSubtree(key: const ValueKey('content'), child: _content(context)),
    );
    final trailing = widget.appending || _append.isAnimating || _landing;
    if (!trailing) return body;
    if (context.reduceMotion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [body, const _QuietWait()],
      );
    }
    // The ink sits over the paragraph where the words will land: the
    // paragraph below reserves their room with the pending text invisible.
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.appending && constraints.hasBoundedWidth && constraints.maxWidth > 0) {
          _ensureAppendInk(constraints.maxWidth, scaler);
        }
        final points = _appendPoints;
        final size = _appendSize;
        final inked = points != null && size != null && points.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                // Words still arriving are not for selecting, and a selection
                // begun over a paragraph that rebuilds each frame trips the
                // scroll view's selection delegate.
                SelectionContainer.disabled(child: body),
                if (inked)
                  Positioned(
                    top: _appendTop,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: ReverseAnimation(_appendEase),
                        child: RepaintBoundary(
                          child: InvisibleInk.points(
                            points: points,
                            size: size,
                            color: theme.player.segmentColor,
                            clock: _clock,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Nothing heard yet, or the words not painted yet: a quiet wait.
            if (widget.appending && !inked) const _QuietWait(),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context) {
    final theme = context.theme;
    final transcript = widget.entry.transcript;
    final text = widget.entry.readableText?.trim() ?? '';
    final inking =
        widget.appending && widget.pendingText.trim().isNotEmpty && !context.reduceMotion;
    if (text.isEmpty && !inking) {
      // Two different silences: never transcribed (the action lives in the
      // screen's bottom CTA) versus transcribed and empty (no speech, no action).
      return _TranscriptEmpty(untranscribed: transcript == null);
    }

    // No transcript can still mean words: an edit typed over an entry that was
    // never transcribed (or restored from an archive that way) must show.
    final segments = transcript?.segments ?? const <TranscriptSegment>[];
    // An entry not reading as its transcript renders plain: the timings name
    // the engine's words, and the mark would light text the audio never said.
    final tailStart = _tailStart;
    final pending = widget.pendingText.trim();
    if (inking) {
      // The words about to land hold their room, unseen, so the ink over
      // them sits exactly where they will.
      final style = AppType.body.copyWith(color: theme.text);
      final shown = _paragraphText(widget.entry);
      return RepaintBoundary(
        key: _textKey,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: shown, style: style),
              TextSpan(
                text: shown.isEmpty ? pending : ' $pending',
                style: style.copyWith(color: theme.text.withValues(alpha: 0)),
              ),
            ],
          ),
        ),
      );
    }
    if (segments.isEmpty || !widget.entry.readsAsTranscript) {
      if (tailStart == null || tailStart >= text.length) {
        return RepaintBoundary(
          key: _textKey,
          child: Text(text, style: AppType.body.copyWith(color: theme.text)),
        );
      }
      // The landed words fade in after the old ones, in one paragraph.
      final style = AppType.body.copyWith(color: theme.text);
      return RepaintBoundary(
        key: _textKey,
        child: AnimatedBuilder(
          animation: _appendEase,
          builder: (context, _) => Text.rich(
            TextSpan(
              children: [
                TextSpan(text: text.substring(0, tailStart), style: style),
                TextSpan(
                  text: text.substring(tailStart),
                  style: style.copyWith(color: theme.text.withValues(alpha: _appendEase.value)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Selected off the state, not built from it: the native side ticks five
    // times a second, and the paragraph only changes when the LIT SEGMENT does.
    // Rebuilding every span on every tick was re-laying out the whole
    // transcript four times out of five for nothing.
    return RepaintBoundary(
      key: _textKey,
      child: BlocSelector<PlayerCubit, PlayerState, int?>(
        selector: (player) => player.status == PlaybackStatus.stopped
            ? null
            : activeSegmentIndex(segments, player.position),
        builder: (context, active) {
          final tailIndex = _tailIndex;
          return AnimatedBuilder(
            animation: _appendEase,
            builder: (context, _) => Text.rich(
              TextSpan(
                children: [
                  for (final (i, segment) in segments.indexed)
                    TextSpan(
                      text: i == segments.length - 1 ? segment.text : '${segment.text} ',
                      style: AppType.body.copyWith(
                        // The landed words fade in where the ink stood.
                        color: tailIndex != null && i >= tailIndex
                            ? theme.player.segmentColor.withValues(alpha: _appendEase.value)
                            : theme.player.segmentColor,
                        // The rest of the transcript is NOT dimmed. Reading is the
                        // point of this screen, and dimming everything you are not
                        // hearing makes the page worse at it; the lit segment
                        // carries a mark instead, so following the audio costs the
                        // rest of the text nothing.
                        // backgroundColor, not a background Paint: a Paint counts
                        // as a layout change and would rebuild the selectables each
                        // tick, dropping any active selection mid-playback.
                        backgroundColor: i == active ? theme.player.activeSegmentHighlight : null,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The ink dots at the page's left edge, so a wait reads as the page's own,
/// not a chip.
class _QuietWait extends StatelessWidget {
  const _QuietWait({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: AppSpinner(size: 30, color: theme.player.segmentColor),
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

typedef _AppendKey = ({String base, String pending, double width, TextScaler scaler});
