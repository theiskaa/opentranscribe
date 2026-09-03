import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

/// How deep each edge of the window dissolves, in lines. Under half a line the
/// cut is still a cut; much over one and the window loses a line to softness.
const double _edgeFade = 0.7;

/// The text as the window lays it out: its words, and for each whether it is
/// glued to the one before (no whitespace between them), so no space is packed
/// or drawn there. A run of spaced script is one word; a CJK character is a
/// word of its own, its closing punctuation riding along, so a script without
/// spaces still breaks across lines instead of running off the edge as one.
({List<String> words, List<bool> glued}) transcriptWords(String text) {
  final words = <String>[];
  final glued = <bool>[];
  int? lastEnd;
  for (final match in _word.allMatches(text)) {
    words.add(match.group(0)!);
    glued.add(lastEnd == match.start);
    lastEnd = match.end;
  }
  return (words: words, glued: glued);
}

/// The code points of the scripts written without spaces (CJK symbols and
/// punctuation, kana, the unified ideographs, and their full-width forms), as a
/// character-class body. One definition: the onboarding take that speaks into
/// this window must agree with it on what counts as a character.
const cjkRange = r'\u3000-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff00-\uffef';

/// Closing punctuation that never opens a line, so it rides with the character
/// before it.
const _cjkClosing = r'\u3001\u3002\uff01\uff0c\uff1a\uff1b\uff1f\u300d\u300f\uff09';
final RegExp _word = RegExp('[$cjkRange][$_cjkClosing]*|[^\\s$cjkRange]+');

/// Greedy line packing over [words], as absolute word indices per line.
/// Packing runs forward from the first word so a line's breaks are settled once
/// decided: a newly spoken word only ever extends the last line or starts a new
/// one, and the block above it holds still. [first] starts a fresh line at that
/// word, for [repackFrom] to continue an earlier packing. A word [glued] to
/// the one before it takes no space in front.
List<List<int>> packLines(
  List<String> words,
  double Function(String) widthOf, {
  required double spaceWidth,
  required double maxWidth,
  int first = 0,
  List<bool>? glued,
}) {
  final lines = <List<int>>[];
  var current = <int>[];
  var used = 0.0;
  for (var i = first; i < words.length; i++) {
    final width = widthOf(words[i]);
    final joined = current.isEmpty || (glued?[i] ?? false);
    final advance = joined ? width : spaceWidth + width;
    // A word wider than the line still gets a line of its own, rather than
    // vanishing between two of them.
    if (current.isNotEmpty && used + advance > maxWidth) {
      lines.add(current);
      current = [i];
      used = width;
    } else {
      current.add(i);
      used += advance;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

/// The first index where [a] and [b] disagree; their shared length when one
/// is a prefix of the other. A live partial usually only appends, so this
/// lands near the end. A word whose glue changed diverges too: the same words
/// with a space put between them, or taken out, are packed differently.
int firstDivergence(List<String> a, List<String> b, {List<bool>? aGlued, List<bool>? bGlued}) {
  final shared = math.min(a.length, b.length);
  var i = 0;
  while (i < shared && a[i] == b[i] && (aGlued?[i] ?? false) == (bGlued?[i] ?? false)) {
    i++;
  }
  return i;
}

/// [lines]' packing continued after the words from [from] on changed: lines
/// whose break the change cannot move are kept, and packing re-runs from the
/// first line whose break it could. Assumes [words] before [from] matches the
/// packing [lines] came from; then this equals [packLines] over all of
/// [words], at the cost of the changed tail alone.
List<List<int>> repackFrom(
  List<List<int>> lines,
  int from,
  List<String> words,
  double Function(String) widthOf, {
  required double spaceWidth,
  required double maxWidth,
  List<bool>? glued,
}) {
  var keep = 0;
  // Line j's break was decided by the word AFTER it (index last + 1), so the
  // line is settled only while that word is unchanged.
  while (keep < lines.length && lines[keep].last < from - 1) {
    keep++;
  }
  final first = keep == 0 ? 0 : lines[keep - 1].last + 1;
  return lines.sublist(0, keep)..addAll(
    packLines(
      words,
      widthOf,
      spaceWidth: spaceWidth,
      maxWidth: maxWidth,
      first: first,
      glued: glued,
    ),
  );
}

/// The packing for [words], continued from the previous partial's
/// [previousWords] and [previous] packing at [previousMaxWidth]. Unchanged
/// words keep the previous packing, identity included, so an idle rebuild
/// re-lays nothing; a width change re-packs everything.
List<List<int>> packIncrementally(
  List<String> words,
  double Function(String) widthOf, {
  required double spaceWidth,
  required double maxWidth,
  required List<String> previousWords,
  required List<List<int>> previous,
  required double? previousMaxWidth,
  List<bool>? glued,
  List<bool>? previousGlued,
}) {
  if (maxWidth != previousMaxWidth) {
    return packLines(words, widthOf, spaceWidth: spaceWidth, maxWidth: maxWidth, glued: glued);
  }
  final from = firstDivergence(previousWords, words, aGlued: previousGlued, bGlued: glued);
  if (from == words.length && from == previousWords.length) return previous;
  return repackFrom(
    previous,
    from,
    words,
    widthOf,
    spaceWidth: spaceWidth,
    maxWidth: maxWidth,
    glued: glued,
  );
}

/// The live transcript: a four-line window on what is being said, anchored at
/// the bottom so every motion is upward, and SCROLLABLE back through the whole
/// take. Each newly heard word fades and rises into place, a revision dissolves
/// in the word it corrects, and a new line lifts the block by gliding the
/// scroll rather than by moving the text under it. This is feedback, not the
/// record; the persisted transcript comes from the batch pass on stop.
class LiveTranscript extends StatefulWidget {
  const LiveTranscript({required this.text, super.key});

  final String text;

  @override
  State<LiveTranscript> createState() => _LiveTranscriptState();
}

class _LiveTranscriptState extends State<LiveTranscript> {
  static const _lines = 4;

  /// The last partial's words and their packing, so the next one re-packs
  /// only its changed tail instead of the whole take.
  List<String> _words = const [];
  List<bool> _glued = const [];
  List<List<int>> _packed = const [];
  double? _packedWidth;

  void _dropPacking() {
    _words = const [];
    _glued = const [];
    _packed = const [];
    _packedWidth = null;
  }

  /// Reversed: offset 0 is the NEWEST line, so the window stays on the latest
  /// speech for free and scrolling back is scrolling forward.
  final _HoldingController _scroll = _HoldingController();

  /// Measured word widths, so a long take does not re-measure its history on
  /// every partial. Dropped when the style or text scale changes under it.
  final Map<String, double> _widths = {};
  TextStyle? _measuredWith;
  TextScaler _measuredAt = TextScaler.noScaling;

  /// The highest word index that has already been on screen. A word entering
  /// past this one is genuinely new, and only those animate in.
  int _shownThrough = -1;

  double _measure(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double _widthOf(String word, TextStyle style, TextScaler scaler) =>
      _widths[word] ??= _measure(word, style, scaler);

  /// A lone space measures as nothing (layout trims trailing whitespace), so
  /// take its advance from the difference a space makes inside a run.
  double _spaceWidth(TextStyle style, TextScaler scaler) =>
      _widths[' '] ??= _measure('x x', style, scaler) - _measure('xx', style, scaler);

  /// Each edge's dissolve, as a FRACTION of the window, for a [fade] that deep.
  /// An edge only softens when there is speech being cut off behind it: the
  /// newest line must never be dimmed while it is the thing being read, and a
  /// take shorter than the window has nothing hidden at either end. Both ramp
  /// in over the fade's own depth, so scrolling away from an edge grows its
  /// dissolve rather than switching it on.
  (double, double) _cutOff(double fade) {
    if (!_scroll.hasClients || fade <= 0) return (0, 0);
    final position = _scroll.position;
    // Reversed axis: pixels measures back from the NEWEST line, so it is
    // exactly how much is hidden below the window, and what is left above is
    // the rest of the take.
    final below = (position.pixels / fade).clamp(0.0, 1.0);
    final above = ((position.maxScrollExtent - position.pixels) / fade).clamp(0.0, 1.0);
    final span = fade / position.viewportDimension;
    return (above * span, below * span);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.recorder;
    final style = AppType.body.copyWith(color: tokens.liveTextColor);
    final scaler = MediaQuery.textScalerOf(context);
    if (_measuredWith != style || _measuredAt != scaler) {
      _widths.clear();
      _measuredWith = style;
      _measuredAt = scaler;
      _dropPacking();
    }
    final lineHeight = scaler.scale(style.fontSize!) * style.height!;
    final boxHeight = lineHeight * _lines;

    final (:words, :glued) = transcriptWords(widget.text);
    if (words.isEmpty) {
      // Only an emptied text is a fresh take; nothing has been shown under the
      // new numbering.
      _shownThrough = -1;
      _dropPacking();
      return SizedBox(height: boxHeight);
    }
    // A shortening revision ("recognise it" -> "recognized") must not make
    // words that are still on screen count as new, or they replay their
    // entrance; it only ever pulls the watermark back to what exists.
    _shownThrough = math.min(_shownThrough, words.length - 1);
    // Hoisted out of the layout callback below: every word belongs to exactly
    // one line, so the last line's last word is always the last word, and the
    // watermark never needed the packing to know it.
    final shownBefore = _shownThrough;
    _shownThrough = words.length - 1;

    return SizedBox(
      height: boxHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spaceWidth = _spaceWidth(style, scaler);
          final lines = packIncrementally(
            words,
            (word) => _widthOf(word, style, scaler),
            spaceWidth: spaceWidth,
            maxWidth: constraints.maxWidth,
            previousWords: _words,
            previous: _packed,
            previousMaxWidth: _packedWidth,
            glued: glued,
            previousGlued: _glued,
          );
          _words = words;
          _glued = glued;
          _packed = lines;
          _packedWidth = constraints.maxWidth;
          _scroll.lift = context.reduceMotion ? Duration.zero : theme.motion.lineShift;

          // Stagger runs over the words arriving in THIS frame, so a partial
          // that lands several at once reads as one cascade. Counted over the
          // packing, not the build, so a line scrolled out of the viewport
          // cannot renumber the words that are actually appearing. Only the
          // tail can hold arrivals.
          var firstArriving = lines.length;
          while (firstArriving > 0 && lines[firstArriving - 1].last > shownBefore) {
            firstArriving--;
          }
          final arrivalOrder = <int, int>{};
          for (var l = firstArriving; l < lines.length; l++) {
            for (final index in lines[l]) {
              if (index > shownBefore) arrivalOrder[index] = arrivalOrder.length;
            }
          }

          // The window is only as tall as it has speech to hold, pinned to the
          // TOP of the reserved block: a first line sits right under the band
          // rather than at the foot of four lines of nothing, and each new one
          // arrives BELOW it without moving what is already there. The block
          // itself keeps its full height, so the page never reflows. Once the
          // window is full it stops growing and starts scrolling, which is the
          // point the lift takes over.
          final window = math.min(lines.length, _lines) * lineHeight;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: window,
              child: AnimatedBuilder(
                animation: _scroll,
                child: ListView.builder(
                  controller: _scroll,
                  // Bottom-anchored by construction: a take shorter than the window
                  // rests on the floor, and a longer one holds the newest line
                  // there without anything having to chase it.
                  reverse: true,
                  padding: EdgeInsets.zero,
                  itemCount: lines.length,
                  itemBuilder: (context, row) {
                    final line = lines[lines.length - 1 - row];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (position, index) in line.indexed) ...[
                          if (position > 0 && !glued[index]) SizedBox(width: spaceWidth),
                          _Word(
                            key: ValueKey(index),
                            text: words[index],
                            style: style,
                            entering: index > shownBefore,
                            order: arrivalOrder[index] ?? 0,
                          ),
                        ],
                      ],
                    );
                  },
                ),
                builder: (context, child) {
                  final fade = lineHeight * _edgeFade;
                  final (top, bottom) = _cutOff(fade);
                  return ShaderMask(
                    // srcIn takes the shader's OWN color, so these are the text's
                    // colors and the gradient is what dissolves it: speech leaves
                    // the window rather than meeting a cut. The top ramp passes
                    // through the faded ink on its way in, so what is about to go
                    // reads as already spoken.
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        tokens.liveTextColor.withValues(alpha: 0),
                        context.highContrast ? tokens.liveTextColor : tokens.liveTextFadedColor,
                        tokens.liveTextColor,
                        tokens.liveTextColor,
                        tokens.liveTextColor.withValues(alpha: 0),
                      ],
                      stops: [0, top / 2, top, 1 - bottom, 1],
                    ).createShader(rect),
                    blendMode: BlendMode.srcIn,
                    child: child,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One word. It rises into place on the frame it is first heard and holds
/// still ever after; a revision to a word already on screen dissolves in
/// place instead of flickering.
class _Word extends StatefulWidget {
  const _Word({
    required this.text,
    required this.style,
    required this.entering,
    required this.order,
    super.key,
  });

  final String text;
  final TextStyle style;

  /// Whether this word is arriving now. Read once, on mount: a rebuild or a
  /// reflow must never replay an entrance.
  final bool entering;

  /// Position among the words arriving in the same frame, for the stagger.
  final int order;

  @override
  State<_Word> createState() => _WordState();
}

class _WordState extends State<_Word> {
  late final bool _entering = widget.entering;
  late final int _order = widget.order;

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    final Widget word = AnimatedSwitcher(
      duration: motion.crossfade,
      // The CURRENT word alone sizes the slot; the word it replaced dissolves
      // out over the top of it. The default stack sizes to the LARGER of the
      // two, so a revision to a shorter word ("recognise it" -> "recognized")
      // would hold the old, wider layout for the length of the crossfade - and
      // the line was packed for the new one, so the row overflowed.
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          for (final child in previous) Positioned(left: 0, child: child),
          ?current,
        ],
      ),
      child: Text(widget.text, key: ValueKey(widget.text), style: widget.style),
    );
    // The rise is vestibular motion; under Reduce Motion a heard word just
    // appears (the switcher above still crossfades revisions, which aids reading).
    if (!_entering || context.reduceMotion) return word;

    final delay = motion.wordStagger * _order;
    final total = delay + motion.wordIn;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      // The stagger is the head of this word's own window, so one tween covers
      // both the wait and the rise.
      curve: Interval(
        total.inMicroseconds == 0 ? 0 : delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOut,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, motion.wordRise * (1 - t)), child: child),
      ),
      child: word,
    );
  }
}

/// The live window's scroll controller: it holds the words where they are when
/// a line arrives, and carries the lift's [lift] duration for its position.
class _HoldingController extends ScrollController {
  Duration lift = Duration.zero;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _HoldingPosition(
    controller: this,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );
}

/// On the reversed axis a new line pushes everything already there one line
/// further from the bottom. Correcting the offset by that much INSIDE layout
/// keeps the same words in place with no frame in between: a post-frame jump
/// showed the shifted block for one frame before the lift, a visible jolt on
/// every new line. A reader at the newest line then glides to it; a reader
/// scrolled back is reading and stays where they are. No lift means no hold:
/// the new line simply appears, for Reduce Motion.
class _HoldingPosition extends ScrollPositionWithSingleContext {
  _HoldingPosition({
    required this.controller,
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  final _HoldingController controller;

  /// The glide in progress, if any. A reader mid-glide is still following the
  /// speech; a line arriving then restarts the glide from the held offset,
  /// since the running one would set its next frame's offset absolutely.
  Future<void>? _glide;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final grew = hasContentDimensions ? maxScrollExtent - this.maxScrollExtent : 0.0;
    final hold = grew > 0 && controller.lift > Duration.zero;
    if (hold) {
      final following = pixels <= 0.5 || _glide != null;
      correctPixels(pixels + grew);
      if (following) WidgetsBinding.instance.addPostFrameCallback((_) => _liftToNewest());
    }
    final settled = super.applyContentDimensions(minScrollExtent, maxScrollExtent);
    // A corrected offset is only on screen if the viewport lays out again with
    // it; answering true would paint this frame at the old offset, the jolt.
    return settled && !hold;
  }

  void _liftToNewest() {
    // The frame between the hold and this callback can rebuild the scrollable
    // onto a new position; the old one is disposed and must not animate.
    if (!hasPixels || !controller.positions.contains(this)) return;
    final glide = animateTo(0, duration: controller.lift, curve: Curves.easeInOut);
    _glide = glide;
    glide.whenComplete(() {
      if (_glide == glide) _glide = null;
    });
  }
}
