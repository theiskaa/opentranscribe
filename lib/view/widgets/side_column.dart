import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';

bool journalColumnEnabled(PaneLayout layout) => layout.sideColumn != null;

Rect journalRecordSlot(SideColumn column) {
  final floor = column.lowerSlot;
  final record =
      columnControlSlots(
        Rect.fromLTRB(
          floor.left,
          floor.top,
          floor.right,
          math.max(floor.top, floor.bottom - AppSpacing.xl),
        ),
        const [Size.square(AppSizes.fab)],
        occlusions: column.occlusions,
        bottom: true,
      ).firstOrNull ??
      Rect.zero;
  return record;
}

({List<Rect> visible, Rect? overflow}) columnBarSlots(SideColumn column, int count) {
  final seats = columnControlSlots(
    column.upperSlot,
    List.filled(count, const Size.square(AppSizes.barControl)),
    occlusions: column.occlusions,
  );
  if (seats.length == count || seats.isEmpty) return (visible: seats, overflow: null);
  return (visible: seats.sublist(0, seats.length - 1), overflow: seats.last);
}

List<Rect> columnControlSlots(
  Rect slot,
  List<Size> controls, {
  List<Rect> occlusions = const [],
  bool bottom = false,
}) {
  final result = <Rect>[];
  var edge = bottom ? slot.bottom : slot.top + AppSpacing.md;
  for (final size in controls) {
    if (size.width > slot.width || size.height > slot.height) break;
    Rect seat;
    while (true) {
      seat = Rect.fromLTWH(
        slot.center.dx - size.width / 2,
        bottom ? edge - size.height : edge,
        size.width,
        size.height,
      );
      if (seat.top < slot.top || seat.bottom > slot.bottom) return result;
      final blocked = occlusions.where((rect) => rect.overlaps(seat)).toList();
      if (blocked.isEmpty) break;
      edge = bottom
          ? blocked.map((rect) => rect.top).reduce(math.min) - AppSpacing.md
          : blocked.map((rect) => rect.bottom).reduce(math.max) + AppSpacing.md;
    }
    result.add(seat);
    edge = bottom ? seat.top - AppSpacing.md : seat.bottom + AppSpacing.md;
  }
  return result;
}

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
  });

  final Rect row;
  final bool leading;
  final int actions;
  final bool centerTitle;
  final TextDirection direction;

  static const leadingId = 'leading';
  static const titleId = 'title';

  @override
  void performLayout(Size size) {
    final constraints = BoxConstraints.loose(row.size);
    final sizes = <Size>[];
    if (leading) {
      sizes.add(layoutChild(leadingId, constraints));
    }
    for (var i = 0; i < actions; i++) {
      sizes.add(layoutChild(i, constraints));
    }
    var start = leading ? AppSpacing.md + sizes.first.width : AppSpacing.xl;
    var end = actions == 0 ? AppSpacing.xl : 0.0;
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
      leading != oldDelegate.leading ||
      actions != oldDelegate.actions ||
      centerTitle != oldDelegate.centerTitle ||
      direction != oldDelegate.direction;
}

class SideColumnGround extends StatelessWidget {
  const SideColumnGround({this.enabled = true, this.window = false, super.key});

  final bool enabled;
  final bool window;

  @override
  Widget build(BuildContext context) {
    final panes = PaneLayoutScope.maybeOf(context);
    final scope = PaneScope.maybeOf(context);
    final column = panes?.layout.sideColumn;
    final visible =
        enabled && panes?.reduceTransparency == true && panes?.settled == true && column != null;
    return Positioned.fromRect(
      rect: visible
          ? column.rect.shift(window ? Offset.zero : -(scope?.pane.rect.topLeft ?? Offset.zero))
          : Rect.zero,
      child: IgnorePointer(child: ColoredBox(color: context.theme.surface)),
    );
  }
}
