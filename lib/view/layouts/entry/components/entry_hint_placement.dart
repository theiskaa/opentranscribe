import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/safe_sides.dart';

typedef EntryHintPlacement = ({Rect bounds, AxisDirection caret, double caretInset});

EntryHintPlacement? entryHintPlacement({
  required Rect pane,
  required EdgeInsets padding,
  required TextDirection direction,
  required double phoneTop,
  required double actionSize,
  ({Rect menuSlot, Size callout, double caretSize})? column,
}) {
  final safe = padding.deflateRect(Offset.zero & pane.size);
  if (column == null) {
    final end = AppSpacing.md + endInset(padding, direction);
    final bounds = direction == TextDirection.ltr
        ? Rect.fromLTRB(0, phoneTop, pane.width - end, pane.height)
        : Rect.fromLTRB(end, phoneTop, pane.width, pane.height);
    if (bounds.isEmpty) return null;
    return (bounds: bounds, caret: AxisDirection.up, caretInset: actionSize / 2);
  }

  final Size(:width, :height) = column.callout;
  final caretSize = column.caretSize;
  if (width <= caretSize || width > safe.width - 2 * AppSpacing.md) return null;
  if (height > safe.height || height < 2 * caretSize) return null;
  final menu = column.menuSlot.center - pane.topLeft;
  final leftSide = menu.dx < safe.center.dx;
  final top = (menu.dy - height / 2).clamp(safe.top, safe.bottom - height);
  final left = leftSide ? safe.left + AppSpacing.md : safe.right - AppSpacing.md - width;
  return (
    bounds: Rect.fromLTWH(left, top, width, height),
    caret: leftSide ? AxisDirection.left : AxisDirection.right,
    caretInset: (menu.dy - top).clamp(caretSize, height - caretSize),
  );
}
