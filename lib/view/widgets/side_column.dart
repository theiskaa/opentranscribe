import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';

List<Rect> sideColumnSlots(Rect slot, List<Size> controls, {bool bottom = false}) {
  final result = <Rect>[];
  var y = bottom
      ? slot.bottom -
            controls.fold<double>(0.0, (sum, size) => sum + size.height) -
            AppSpacing.md * math.max(0, controls.length - 1)
      : slot.top + AppSpacing.md;
  for (final control in controls) {
    final size = Size(math.min(control.width, slot.width), math.min(control.height, slot.height));
    final top = y.clamp(slot.top, math.max(slot.top, slot.bottom - size.height)).toDouble();
    result.add(Rect.fromLTWH(slot.center.dx - size.width / 2, top, size.width, size.height));
    y += size.height + AppSpacing.md;
  }
  return result;
}

class TopBarLayout extends MultiChildLayoutDelegate {
  TopBarLayout({
    required this.row,
    required this.leading,
    required this.actions,
    required this.centerTitle,
    required this.direction,
    this.column,
  });

  final Rect row;
  final bool leading;
  final int actions;
  final bool centerTitle;
  final TextDirection direction;
  final Rect? column;

  static const leadingId = 'leading';
  static const titleId = 'title';

  @override
  void performLayout(Size size) {
    final constraints = BoxConstraints.loose(row.size);
    final controls = <Object>[];
    final sizes = <Size>[];
    if (leading) {
      controls.add(leadingId);
      sizes.add(layoutChild(leadingId, constraints));
    }
    for (var i = 0; i < actions; i++) {
      controls.add(i);
      sizes.add(layoutChild(i, constraints));
    }
    final slot = column;
    var start = leading && slot == null ? AppSpacing.md + sizes.first.width : AppSpacing.xl;
    var end = actions == 0 || slot != null ? AppSpacing.xl : 0.0;
    if (slot == null) {
      var right = row.right;
      for (var i = actions - 1; i >= 0; i--) {
        final controlSize = sizes[i + (leading ? 1 : 0)];
        right -= AppSpacing.md + controlSize.width;
        positionChild(i, _position(right, controlSize));
        end += AppSpacing.md + controlSize.width;
      }
      if (leading) {
        final x = direction == TextDirection.rtl
            ? row.right - sizes.first.width
            : row.left + AppSpacing.md;
        positionChild(leadingId, Offset(x, row.top + (row.height - sizes.first.height) / 2));
      }
    } else {
      final rects = sideColumnSlots(slot, sizes);
      for (var i = 0; i < controls.length; i++) {
        positionChild(controls[i], rects[i].topLeft);
      }
    }
    if (hasChild(titleId)) {
      if (centerTitle) start = end = 0;
      final width = math.max(0.0, row.width - start - end);
      final titleSize = layoutChild(titleId, BoxConstraints.tight(Size(width, row.height)));
      final left = direction == TextDirection.ltr ? row.left + start : row.left + end;
      positionChild(titleId, Offset(left, row.top + (row.height - titleSize.height) / 2));
    }
  }

  Offset _position(double left, Size child) => Offset(
    direction == TextDirection.ltr ? left : row.left + row.right - left - child.width,
    row.top + (row.height - child.height) / 2,
  );

  @override
  bool shouldRelayout(TopBarLayout oldDelegate) =>
      row != oldDelegate.row ||
      column != oldDelegate.column ||
      leading != oldDelegate.leading ||
      actions != oldDelegate.actions ||
      centerTitle != oldDelegate.centerTitle ||
      direction != oldDelegate.direction;
}
