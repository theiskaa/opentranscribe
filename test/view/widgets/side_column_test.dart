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
      expect(journalColumnEnabled(layout: layout, cover: false), isTrue);
      final column = layout.sideColumn!;
      final slots = journalColumnSlots(column);
      expect(slots.record.top, column.upperSlot.top + AppSpacing.md);
      expect(slots.settings.top, slots.record.bottom + AppSpacing.md);
      expect(slots.record.size, const Size.square(AppSizes.fab));
      expect(slots.settings.size, const Size.square(AppSizes.barControl));
      expect(slots.record.center.dx, column.rect.center.dx);
      expect(slots.settings.center.dx, column.rect.center.dx);
      final actions = sideColumnSlots(slots.detail, const [
        Size.square(AppSizes.barControl),
        Size.square(AppSizes.barControl),
      ]);
      expect(actions.first.top, slots.settings.bottom + AppSpacing.md);
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
    final slots = journalColumnSlots(column);
    expect(slots.record.top, column.upperSlot.top + AppSpacing.md);
    expect(slots.settings.top, slots.record.bottom + AppSpacing.md);
    expect(slots.record.center.dx, column.rect.center.dx);
    expect(slots.settings.center.dx, column.rect.center.dx);
  });

  test('large text keeps journal controls in the inner status column after split collapses', () {
    final layout = layoutOf(DisplayWire.flatWide, largeText: true);
    expect(layout.mode, PaneMode.single);
    expect(journalColumnEnabled(layout: layout, cover: false), isTrue);
  });

  test('cover and top status bar layouts retain the existing home placements', () {
    expect(journalColumnEnabled(layout: layoutOf(DisplayWire.cover), cover: true), isFalse);
    for (final wire in [
      DisplayWire.flatTall,
      DisplayWire.laptop,
      DisplayWire.iphone,
      DisplayWire.unsupported,
    ]) {
      expect(journalColumnEnabled(layout: layoutOf(wire), cover: false), isFalse);
    }
  });

  test('a stale wide signal cannot move controls into the old column', () {
    final layout = layoutOf(DisplayWire.flatWide, size: const Size(669, 951));
    expect(journalColumnEnabled(layout: layout, cover: false), isFalse);
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
}
