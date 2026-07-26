import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// One character position in a rolling transition: the character it shows now
/// and whether it changed from the previous text (unchanged slots hold still).
typedef RollingSlot = ({String char, bool rolls});

/// Per-index diff between two strings, over GRAPHEME CLUSTERS (an emoji or a
/// combining sequence is one slot, never split into lone surrogates). A slot
/// rolls when its character differs; positions past either string's end
/// compare as empty, so growth and shrinkage roll in and out instead of
/// snapping.
List<RollingSlot> rollingSlots(String from, String to) {
  final a = from.characters.toList();
  final b = to.characters.toList();
  final length = math.max(a.length, b.length);
  return [
    for (var i = 0; i < length; i++)
      (
        char: i < b.length ? b[i] : '',
        rolls: (i < a.length ? a[i] : '') != (i < b.length ? b[i] : ''),
      ),
  ];
}

/// Text whose characters roll vertically when they change, the odometer way:
/// unchanged characters hold still, while a changed character's old glyph and
/// its replacement travel through the line box as one connected column,
/// clipped at the edges, arriving with a whisper of settle. Changed slots
/// cascade with a small stagger. [direction] +1 rolls upward (for values that
/// grew), -1 downward. One painter and one ticker for the whole text; pass a
/// tabular-figures style when the text carries digits so neighbors never
/// shift.
class RollingText extends StatefulWidget {
  const RollingText({
    required this.text,
    required this.style,
    this.direction = 1,
    this.window,
    this.stagger,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int direction;

  /// One slot's roll duration; null uses the motion theme's `digitRoll`.
  final Duration? window;

  /// Delay between consecutive rolling slots; null uses the motion theme's
  /// `rollStagger`. Zero moves every changed character together, for quieter
  /// secondary text.
  final Duration? stagger;

  @override
  State<RollingText> createState() => _RollingTextState();
}

class _RollingTextState extends State<RollingText> with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(vsync: this, value: 1);

  /// The text the current roll animates away from.
  String _from = '';

  List<_PaintSlot> _slots = const [];
  double _height = 0;
  (String, String, TextStyle, TextScaler)? _specKey;

  @override
  void initState() {
    super.initState();
    _from = widget.text;
  }

  Duration _window(BuildContext context) => widget.window ?? context.motionNow.digitRoll;

  Duration _stagger(BuildContext context) => widget.stagger ?? context.motionNow.rollStagger;

  @override
  void didUpdateWidget(RollingText old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    if (context.reduceMotion) {
      // Reduce Motion: no odometer roll. From == to means no slot rolls, so the
      // painter simply draws the new text at rest.
      _from = widget.text;
      _roll.value = 1;
      return;
    }
    _from = old.text;
    final rolling = rollingSlots(_from, widget.text).where((s) => s.rolls).length;
    _roll.duration = _window(context) + _stagger(context) * math.max(rolling - 1, 0);
    _roll.forward(from: 0);
  }

  void _disposeSlots() {
    for (final slot in _slots) {
      slot.oldGlyph?.dispose();
      slot.newGlyph?.dispose();
    }
    _slots = const [];
  }

  /// Lays the glyphs out once per text change, not per frame: the painter
  /// only moves prebuilt [TextPainter]s afterwards.
  void _buildSpec(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final key = (_from, widget.text, widget.style, scaler);
    if (key == _specKey) return;
    _specKey = key;
    _disposeSlots();

    final direction = Directionality.of(context);
    TextPainter layout(String text) => TextPainter(
      text: TextSpan(text: text, style: widget.style),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    TextPainter? glyph(String char) => char.isEmpty ? null : layout(char);

    final probe = layout('0');
    _height = probe.height;
    probe.dispose();

    final window = _window(context);
    final stagger = _stagger(context);
    final totalMs = (_roll.duration ?? window).inMilliseconds.toDouble();
    final diff = rollingSlots(_from, widget.text);
    final fromChars = _from.characters.toList();
    var rollIndex = 0;
    _slots = [
      for (var i = 0; i < diff.length; i++)
        if (!diff[i].rolls)
          _PaintSlot(
            oldGlyph: null,
            newGlyph: glyph(diff[i].char),
            rolls: false,
            start: 0,
            window: 1,
          )
        else
          _PaintSlot(
            oldGlyph: glyph(i < fromChars.length ? fromChars[i] : ''),
            newGlyph: glyph(diff[i].char),
            rolls: true,
            start: (rollIndex++ * stagger.inMilliseconds) / totalMs,
            window: window.inMilliseconds / totalMs,
          ),
    ];
  }

  @override
  void dispose() {
    _disposeSlots();
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _buildSpec(context);
    final up = widget.direction >= 0;
    return AnimatedBuilder(
      animation: _roll,
      builder: (context, _) {
        var width = 0.0;
        for (final slot in _slots) {
          width += slot.widthAt(_roll.value);
        }
        return CustomPaint(
          size: Size(width, _height),
          painter: _RollPainter(slots: _slots, progress: _roll.value, up: up, height: _height),
        );
      },
    );
  }
}

class _PaintSlot {
  _PaintSlot({
    required this.oldGlyph,
    required this.newGlyph,
    required this.rolls,
    required this.start,
    required this.window,
  });

  final TextPainter? oldGlyph;
  final TextPainter? newGlyph;
  final bool rolls;

  /// This slot's stagger window, as fractions of the whole animation.
  final double start;
  final double window;

  double localT(double value) => rolls ? ((value - start) / window).clamp(0.0, 1.0) : 1.0;

  /// Slot width glides between the two glyphs' widths so proportional
  /// characters never make their neighbors jump.
  double widthAt(double value) {
    if (!rolls) return newGlyph?.width ?? 0;
    return lerpDouble(
      oldGlyph?.width ?? 0,
      newGlyph?.width ?? 0,
      Curves.easeOutCubic.transform(localT(value)),
    )!;
  }
}

class _RollPainter extends CustomPainter {
  const _RollPainter({
    required this.slots,
    required this.progress,
    required this.up,
    required this.height,
  });

  final List<_PaintSlot> slots;
  final double progress;
  final bool up;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    // The line box is the odometer window: glyphs travel through it and are
    // sheared off at its edges, no fading.
    canvas.clipRect(Offset.zero & size);
    final sign = up ? 1.0 : -1.0;
    var x = 0.0;
    for (final slot in slots) {
      if (!slot.rolls) {
        slot.newGlyph?.paint(canvas, Offset(x, 0));
        x += slot.newGlyph?.width ?? 0;
        continue;
      }
      // Old and new share one eased position, so they move as a connected
      // column; the overshoot lets the arrival settle like a wheel.
      final e = Curves.easeOutBack.transform(slot.localT(progress));
      slot.oldGlyph?.paint(canvas, Offset(x, -height * e * sign));
      slot.newGlyph?.paint(canvas, Offset(x, height * (1 - e) * sign));
      x += slot.widthAt(progress);
    }
  }

  @override
  bool shouldRepaint(_RollPainter old) =>
      old.progress != progress || old.slots != slots || old.up != up || old.height != height;
}
