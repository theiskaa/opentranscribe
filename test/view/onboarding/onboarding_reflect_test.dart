import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_reflect.dart';

void main() {
  test('the ISO week number follows the week that holds the Thursday', () {
    expect(isoWeekNumber(DateTime(2026)), 1);
    expect(isoWeekNumber(DateTime(2024, 12, 30)), 1);
    expect(isoWeekNumber(DateTime(2026, 8, 31)), 36);
    expect(isoWeekNumber(DateTime(2026, 1, 4)), 1);
    expect(isoWeekNumber(DateTime(2026, 4, 2)), 14);
  });
}
