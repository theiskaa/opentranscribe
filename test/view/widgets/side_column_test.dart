import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';

import 'package:opentranscribe/view/widgets/side_column.dart';

import '../../support/fake_display_channels.dart';

PaneLayout layoutOf(Map<String, Object?> wire, {bool largeText = false, Size? size}) {
  final signal = DisplayWire.decode(wire);
  return paneLayoutFor(
    PaneInputs(
      size: size ?? signal.size,
      padding: signal.padding,
      signal: signal,
      bodySize: largeText ? AppType.largeTextBody : AppType.body.fontSize!,
      closedContentWidth: AppDuo.closedContentWidth,
    ),
  );
}

void main() {
  const upper = Rect.fromLTRB(867, 124, 951, 379.5);
  const lower = Rect.fromLTRB(867, 379.5, 951, 635);

  test('journal controls use the column on the flat and folded inner display', () {
    for (final wire in [DisplayWire.flatWide, DisplayWire.bookWide]) {
      final layout = layoutOf(wire);
      expect(journalColumnEnabled(layout), isTrue);
      final column = layout.sideColumn!;
      final record = journalRecordSlot(column);
      final navigation = columnBarSlots(column, 2).visible;
      expect(record.bottom, column.lowerSlot.bottom - AppSpacing.xl);
      expect(navigation.first.top, column.upperSlot.top + AppSpacing.md);
      expect(record.size, const Size.square(AppSizes.fab));
      expect(navigation.first.size, const Size.square(AppSizes.barControl));
      expect(record.center.dx, column.rect.center.dx);
      expect(navigation.first.center.dx, column.rect.center.dx);
      final actions = navigation;
      expect(actions.first.top, column.upperSlot.top + AppSpacing.md);
      expect(actions.last.top, greaterThanOrEqualTo(actions.first.bottom + AppSpacing.md));
      expect(actions.last.bottom, lessThanOrEqualTo(column.upperSlot.bottom));
    }
  });

  test('column controls follow a changed measured status edge and a physical left column', () {
    const column = SideColumn(
      rect: Rect.fromLTWH(0, 0, 84, 669),
      side: BarSide.left,
      upperSlot: Rect.fromLTRB(0, 150, 84, 392.5),
      lowerSlot: Rect.fromLTRB(0, 392.5, 84, 635),
    );
    final record = journalRecordSlot(column);
    final navigation = columnBarSlots(column, 2).visible;
    expect(record.bottom, column.lowerSlot.bottom - AppSpacing.xl);
    expect(navigation.first.top, column.upperSlot.top + AppSpacing.md);
    expect(record.center.dx, column.rect.center.dx);
    expect(navigation.first.center.dx, column.rect.center.dx);
  });

  test('large text keeps journal controls in the inner status column after split collapses', () {
    final layout = layoutOf(DisplayWire.flatWide, largeText: true);
    expect(layout.mode, PaneMode.single);
    expect(journalColumnEnabled(layout), isTrue);
  });

  test('cover uses the column and top status bar layouts retain horizontal placements', () {
    expect(journalColumnEnabled(layoutOf(DisplayWire.cover)), isTrue);
    for (final wire in [
      DisplayWire.flatTall,
      DisplayWire.laptop,
      DisplayWire.iphone,
      DisplayWire.unsupported,
    ]) {
      expect(journalColumnEnabled(layoutOf(wire)), isFalse);
    }
  });

  test('a stale wide signal cannot move controls into the old column', () {
    final layout = layoutOf(DisplayWire.flatWide, size: const Size(669, 951));
    expect(journalColumnEnabled(layout), isFalse);
  });

  test('Back precedes the actions below the status cluster', () {
    final slots = sideColumnSlots(upper, const [Size.square(44), Size.square(44)]);
    expect(slots.first.top, upper.top + AppSpacing.md);
    expect(slots.last.top, slots.first.bottom + AppSpacing.md);
    for (final slot in slots) {
      expect(upper.contains(slot.topLeft), isTrue);
      expect(slot.center.dx, upper.center.dx);
      expect(slot.bottom, lessThanOrEqualTo(upper.bottom));
    }
  });

  test('the floating disc rests above the lower slot floor', () {
    final slot = sideColumnSlots(lower, const [Size.square(AppSizes.fab)], bottom: true).single;
    expect(slot.bottom, lower.bottom);
    expect(slot.center.dx, lower.center.dx);
    expect(slot.top, greaterThanOrEqualTo(lower.top));
  });

  test('a physical left column uses the same vertical slots', () {
    final right = sideColumnSlots(upper, const [Size.square(44)]).single;
    final left = sideColumnSlots(upper.shift(const Offset(-867, 0)), const [
      Size.square(44),
    ]).single;
    expect(left, right.shift(const Offset(-867, 0)));
  });

  test('an empty bar reserves no control seats', () {
    expect(sideColumnSlots(upper, const []), isEmpty);
  });

  test('a control stays within a slot smaller than its natural size', () {
    const tiny = Rect.fromLTWH(0, 0, 32, 30);
    final slot = sideColumnSlots(tiny, const [Size.square(44)]).single;
    expect(slot, tiny);
  });

  test('column seats skip every measured occlusion without shrinking the touch target', () {
    const slot = Rect.fromLTRB(0, 100, 84, 400);
    const occlusions = [Rect.fromLTRB(0, 140, 84, 190), Rect.fromLTRB(0, 240, 84, 270)];
    final seats = columnControlSlots(slot, const [
      Size.square(AppSizes.barControl),
      Size.square(AppSizes.barControl),
    ], occlusions: occlusions);
    expect(seats, hasLength(2));
    for (final seat in seats) {
      expect(seat.size, const Size.square(AppSizes.barControl));
      expect(occlusions.any(seat.overlaps), isFalse);
      expect(seat.top, greaterThanOrEqualTo(slot.top));
      expect(seat.bottom, lessThanOrEqualTo(slot.bottom));
    }
    expect(seats.last.top - seats.first.bottom, greaterThanOrEqualTo(AppSpacing.md));
  });

  test('Record rises above a measured lower column occlusion', () {
    const column = SideColumn(
      rect: Rect.fromLTRB(0, 0, 84, 678),
      side: BarSide.left,
      upperSlot: Rect.fromLTRB(0, 174, 84, 409),
      lowerSlot: Rect.fromLTRB(0, 409, 84, 644),
      occlusions: [Rect.fromLTRB(0, 560, 84, 600)],
    );
    final seat = journalRecordSlot(column);
    expect(seat.size, const Size.square(AppSizes.fab));
    expect(seat.bottom, 560 - AppSpacing.md);
    expect(column.occlusions.any(seat.overlaps), isFalse);
  });

  test('an overflowing bar keeps its first controls and reserves the final seat for More', () {
    const column = SideColumn(
      rect: Rect.fromLTRB(0, 0, 84, 678),
      side: BarSide.right,
      upperSlot: Rect.fromLTRB(0, 174, 84, 350),
      lowerSlot: Rect.fromLTRB(0, 350, 84, 644),
    );
    final slots = columnBarSlots(column, 6);
    expect(slots.visible, hasLength(2));
    expect(slots.overflow, isNotNull);
    expect(slots.overflow!.top, greaterThanOrEqualTo(slots.visible.last.bottom + AppSpacing.md));
    expect(slots.overflow!.bottom, lessThanOrEqualTo(column.upperSlot.bottom));
    expect(slots.overflow!.size, const Size.square(AppSizes.barControl));
  });

  test('a bar that fits uses every seat without introducing an overflow control', () {
    final column = layoutOf(DisplayWire.cover).sideColumn!;
    final slots = columnBarSlots(column, 3);
    expect(slots.visible, hasLength(3));
    expect(slots.overflow, isNull);
    expect(slots.visible.first.top, column.upperSlot.top + AppSpacing.md);
  });

  test('a blocked column cannot create overlapping or undersized targets', () {
    const column = SideColumn(
      rect: Rect.fromLTRB(0, 0, 32, 678),
      side: BarSide.right,
      upperSlot: Rect.fromLTRB(0, 174, 32, 350),
      lowerSlot: Rect.fromLTRB(0, 350, 32, 644),
    );
    expect(columnBarSlots(column, 3).visible, isEmpty);
    expect(columnBarSlots(column, 3).overflow, isNull);
    expect(journalRecordSlot(column), Rect.zero);
  });
}
