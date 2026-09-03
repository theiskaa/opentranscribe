import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// A one-shot hint: one line of guidance under a caret pointing at what it
/// explains. Not [AppNotice], which clears itself: a hint waits to be read,
/// and its owner says when it has been ([visible] false). It rises in like
/// every entrance and leaves the way it came, quicker; hidden, it takes no
/// touches. [caretInset] is the caret's centre measured from the trailing
/// edge.
class HintCallout extends StatefulWidget {
  const HintCallout({
    required this.message,
    required this.visible,
    required this.onDismiss,
    required this.caretInset,
    super.key,
  });

  final String message;
  final bool visible;
  final VoidCallback onDismiss;
  final double caretInset;

  @override
  State<HintCallout> createState() => _HintCalloutState();
}

class _HintCalloutState extends State<HintCallout> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final double _rise;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final motion = context.motionNow;
    _rise = motion.entranceRise;
    _controller = AnimationController(
      vsync: this,
      duration: motion.entrance,
      reverseDuration: motion.crossfade,
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: motion.entranceCurve,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: the Reduce Motion read needs the tree.
    if (_started) return;
    _started = true;
    _drive();
  }

  @override
  void didUpdateWidget(HintCallout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _drive();
  }

  void _drive() {
    if (context.reduceMotion) {
      _controller.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.callout;
    final border = BorderSide(color: tokens.border);
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Opacity(
          opacity: _curve.value,
          child: Transform.translate(offset: Offset(0, (1 - _curve.value) * _rise), child: child),
        ),
        child: Touchable(
          onTap: widget.onDismiss,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tokens.maxWidth),
            // The caret paints after the card so its fill covers the card's top
            // border under its base, and the outline reads as one shape.
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: tokens.caretSize),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: SuperellipseDecoration(
                      borderRadius: tokens.radius,
                      color: tokens.background,
                      border: border,
                    ),
                    child: Text(
                      widget.message,
                      style: AppType.footnote.copyWith(color: tokens.text),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 0,
                  end: widget.caretInset - tokens.caretSize,
                  child: CustomPaint(
                    size: Size(tokens.caretSize * 2, tokens.caretSize),
                    painter: _CaretPainter(
                      fill: tokens.background,
                      stroke: tokens.border,
                      strokeWidth: border.width,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter({required this.fill, required this.stroke, required this.strokeWidth});

  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // The fill runs one border width past the base to cover the card's top
    // border there; the stroke stays open at the base for the same reason.
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height + strokeWidth)
        ..lineTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height + strokeWidth)
        ..close(),
      Paint()..color = fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height),
      Paint()
        ..color = stroke
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CaretPainter old) =>
      old.fill != fill || old.stroke != stroke || old.strokeWidth != strokeWidth;
}
