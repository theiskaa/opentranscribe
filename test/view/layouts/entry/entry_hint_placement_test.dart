import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/layouts/entry/components/entry_hint_placement.dart';
import 'package:opentranscribe/view/widgets/side_column.dart';

void main() {
  test('the phone hint stays below the bar with its caret at the trailing action', () {
    const pane = Rect.fromLTWH(0, 0, 390, 844);
    const padding = EdgeInsets.only(left: 16, right: 32);
    for (final direction in TextDirection.values) {
      final hint = entryHintPlacement(
        pane: pane,
        padding: padding,
        direction: direction,
        phoneTop: 100,
        actionSize: AppSizes.barControl,
      )!;
      expect(hint.bounds.top, 100);
      expect(hint.caret, AxisDirection.up);
      expect(hint.caretInset, AppSizes.barControl / 2);
      if (direction == TextDirection.ltr) {
        expect(hint.bounds.right, pane.right - padding.right - AppSpacing.md);
      } else {
        expect(hint.bounds.left, pane.left + padding.left + AppSpacing.md);
      }
    }
  });

  test('the side caret tracks the More slot across pane offsets and reading directions', () {
    const pane = Rect.fromLTWH(280, 16, 500, 420);
    for (final side in [BarSide.left, BarSide.right]) {
      final left = side == BarSide.left ? pane.left - 84 : pane.right - 84;
      final column = SideColumn(
        side: side,
        rect: Rect.fromLTWH(left, 0, 84, 440),
        upperSlot: Rect.fromLTWH(left, 35, 84, 190),
        lowerSlot: Rect.fromLTWH(left, 225, 84, 210),
      );
      final menuSlot = columnBarSlots(column, 2).visible.last;
      for (final direction in TextDirection.values) {
        final hint = entryHintPlacement(
          pane: pane,
          padding: const EdgeInsets.only(left: 24, right: 84),
          direction: direction,
          phoneTop: 100,
          actionSize: AppSizes.barControl,
          column: (menuSlot: menuSlot, callout: const Size(300, 62), caretSize: 8),
        )!;
        expect(hint.caret, side == BarSide.left ? AxisDirection.left : AxisDirection.right);
        expect(hint.bounds.top + hint.caretInset + pane.top, menuSlot.center.dy);
        expect(hint.bounds.left, greaterThanOrEqualTo(24));
        expect(hint.bounds.right, lessThanOrEqualTo(pane.width - 84));
      }
    }
  });

  test('a tall hint stays inside the safe pane near either end of the side column', () {
    const pane = Rect.fromLTWH(220, 44, 500, 350);
    const safeTop = 20.0;
    const safeBottom = 16.0;
    const caretSize = 8.0;
    for (final y in [pane.top, pane.bottom]) {
      final hint = entryHintPlacement(
        pane: pane,
        padding: const EdgeInsets.only(top: safeTop, right: 84, bottom: safeBottom),
        direction: TextDirection.ltr,
        phoneTop: 100,
        actionSize: AppSizes.barControl,
        column: (
          menuSlot: Rect.fromCenter(center: Offset(680, y), width: 44, height: 44),
          callout: const Size(300, 200),
          caretSize: caretSize,
        ),
      )!;
      expect(hint.bounds.top, greaterThanOrEqualTo(safeTop));
      expect(hint.bounds.bottom, lessThanOrEqualTo(pane.height - safeBottom));
      expect(hint.caretInset, inInclusiveRange(caretSize, hint.bounds.height - caretSize));
    }
  });
}
