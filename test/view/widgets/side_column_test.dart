import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/side_column.dart';

void main() {
  const upper = Rect.fromLTRB(867, 124, 951, 379.5);
  const lower = Rect.fromLTRB(867, 379.5, 951, 635);

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
