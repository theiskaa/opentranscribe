import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';

void main() {
  group('AppRadius.inner (concentric corners)', () {
    test('a shape inset inside a corner loses exactly its inset from the radius', () {
      expect(AppRadius.inner(AppRadius.card, AppSpacing.md), 8);
    });

    test('an inset deeper than the corner leaves a square corner, never a negative one', () {
      expect(AppRadius.inner(AppRadius.chip, AppSpacing.lg), 0);
    });
  });

  test('a bar control is never smaller than the smallest tap target', () {
    expect(AppSizes.barControl, greaterThanOrEqualTo(AppSizes.minTarget));
  });
}
