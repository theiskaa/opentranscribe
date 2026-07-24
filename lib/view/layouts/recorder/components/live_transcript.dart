import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

/// Greedy line packing over [words], returning the LAST [maxLines] lines as
/// absolute word indices. Packing runs forward from the first word so a line's
/// breaks are settled once decided: a newly spoken word only ever extends the
/// last line or starts a new one, and the block above it holds still.
List<List<int>> tailLines(
  List<String> words,
  double Function(String) widthOf, {
  required double spaceWidth,
  required double maxWidth,
  required int maxLines,
}) {
  final lines = <List<int>>[];
  var current = <int>[];
  var used = 0.0;
  for (var i = 0; i < words.length; i++) {
    final width = widthOf(words[i]);
    final advance = current.isEmpty ? width : spaceWidth + width;
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
  return lines.length <= maxLines ? lines : lines.sublist(lines.length - maxLines);
}

/// The ambient live transcript: the TAIL of what is being said, exactly two
/// lines, bottom-anchored so every motion is upward. Each newly heard word
/// fades and rises into place, a revision dissolves in the word it corrects,
/// and when a line rolls off the top the block lifts by one line. This is
/// feedback, not the record; the persisted transcript comes from the batch
/// pass on stop.
class LiveTranscript extends StatefulWidget {
  const LiveTranscript({required this.text, super.key});

  final String text;

  @override
  State<LiveTranscript> createState() => _LiveTranscriptState();
}

class _LiveTranscriptState extends State<LiveTranscript> {
  static const _lines = 2;

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
    }
    final lineHeight = scaler.scale(style.fontSize!) * style.height!;
    final boxHeight = lineHeight * _lines;

    final words = widget.text.split(RegExp(r'\s+'))..removeWhere((word) => word.isEmpty);
    if (words.isEmpty) {
      // Only an emptied text is a fresh take; nothing has been shown under the
      // new numbering.
      _shownThrough = -1;
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
          final lines = tailLines(
            words,
            (word) => _widthOf(word, style, scaler),
            spaceWidth: spaceWidth,
            maxWidth: constraints.maxWidth,
            maxLines: _lines,
          );
          final first = lines.first.first;

          // Stagger runs over the words arriving in THIS frame, so a partial
          // that lands several at once reads as one cascade.
          var arriving = 0;
          final rows = <Widget>[
            for (final line in lines)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (position, index) in line.indexed) ...[
                    if (position > 0) SizedBox(width: spaceWidth),
                    _Word(
                      key: ValueKey(index),
                      text: words[index],
                      style: style,
                      entering: index > shownBefore,
                      order: index > shownBefore ? arriving++ : 0,
                    ),
                  ],
                ],
              ),
          ];

          return ClipRect(
            child: ShaderMask(
              // The older line reads as already spoken.
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tokens.liveTextFadedColor, tokens.liveTextColor],
                stops: const [0.0, 0.6],
              ).createShader(rect),
              blendMode: BlendMode.srcIn,
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: TweenAnimationBuilder<double>(
                  // A roll-off changes the first visible word, which remounts
                  // this and plays the lift once. Before the first roll-off
                  // there is nothing above to rise from.
                  key: ValueKey(first),
                  tween: Tween(begin: first == 0 ? 0.0 : lineHeight, end: 0),
                  duration: theme.motion.lineShift,
                  curve: Curves.easeInOut,
                  builder: (context, dy, child) =>
                      Transform.translate(offset: Offset(0, dy), child: child),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rows,
                  ),
                ),
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
      child: Text(widget.text, key: ValueKey(widget.text), style: widget.style),
    );
    if (!_entering) return word;

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
