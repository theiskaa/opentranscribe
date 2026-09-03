import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/entrance_rise.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// A one-shot hint: one line of guidance under a caret pointing at what it
/// explains, dismissed by a tap and by nothing else. Not [AppNotice], which
/// clears itself: a hint waits to be read. [caretInset] is the caret's centre
/// measured from the trailing edge.
class HintCallout extends StatelessWidget {
  const HintCallout({
    required this.message,
    required this.onDismiss,
    required this.caretInset,
    super.key,
  });

  final String message;
  final VoidCallback onDismiss;
  final double caretInset;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.callout;
    final border = BorderSide(color: tokens.border);
    return EntranceRise(
      child: Touchable(
        onTap: onDismiss,
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
                  child: Text(message, style: AppType.footnote.copyWith(color: tokens.text)),
                ),
              ),
              PositionedDirectional(
                top: 0,
                end: caretInset - tokens.caretSize,
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
