import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/utils/period_math.dart';
import 'package:reflections/reflections.dart';

void main() {
  setUpAll(initializeDateFormatting);

  // The literal DateTime(y, m, 1) trips avoid_redundant_argument_values; a
  // helper over variables writes a month's first day without the lint.
  DateTime month(int year, int m) => DateTime(year, m);

  test('startOfPeriod daily strips to the civil date', () {
    expect(
      startOfPeriod(DateTime(2026, 7, 29, 23, 59), ReflectionPeriod.daily),
      DateTime(2026, 7, 29),
    );
  });

  test('startOfPeriod weekly follows the locale first day', () {
    expect(
      startOfPeriod(DateTime(2026, 7, 29), ReflectionPeriod.weekly, localeId: 'en_US'),
      DateTime(2026, 7, 26),
    );
    expect(
      startOfPeriod(DateTime(2026, 7, 29), ReflectionPeriod.weekly, localeId: 'de'),
      DateTime(2026, 7, 27),
    );
  });

  test('startOfPeriod monthly lands on the first, ignoring locale', () {
    expect(
      startOfPeriod(DateTime(2026, 7, 29), ReflectionPeriod.monthly, localeId: 'de'),
      month(2026, 7),
    );
  });

  test('nextPeriodStart advances one day, seven days, or one month', () {
    expect(nextPeriodStart(DateTime(2026, 7, 29), ReflectionPeriod.daily), DateTime(2026, 7, 30));
    expect(nextPeriodStart(DateTime(2026, 7, 20), ReflectionPeriod.weekly), DateTime(2026, 7, 27));
    expect(nextPeriodStart(month(2026, 7), ReflectionPeriod.monthly), month(2026, 8));
  });

  test('nextPeriodStart rolls December into the next January', () {
    expect(nextPeriodStart(month(2026, 12), ReflectionPeriod.monthly), month(2027, 1));
  });

  test('periodsOverlap is true only for the same period start', () {
    expect(
      periodsOverlap(DateTime(2026, 7, 20), DateTime(2026, 7, 20), ReflectionPeriod.daily),
      isTrue,
    );
    expect(
      periodsOverlap(DateTime(2026, 7, 20), DateTime(2026, 7, 21), ReflectionPeriod.daily),
      isFalse,
    );
    expect(periodsOverlap(month(2026, 7), month(2026, 7), ReflectionPeriod.monthly), isTrue);
    expect(periodsOverlap(month(2026, 7), month(2026, 8), ReflectionPeriod.monthly), isFalse);
  });

  test('periodsOverlap weekly tolerates a first-day shift within the same week', () {
    expect(
      periodsOverlap(DateTime(2026, 7, 26), DateTime(2026, 7, 27), ReflectionPeriod.weekly),
      isTrue,
    );
  });

  test('periodContains bounds the range at its exclusive end', () {
    expect(periodContains(month(2026, 7), ReflectionPeriod.monthly, DateTime(2026, 7, 31)), isTrue);
    expect(periodContains(month(2026, 7), ReflectionPeriod.monthly, month(2026, 8)), isFalse);
    expect(
      periodContains(month(2026, 7), ReflectionPeriod.monthly, DateTime(2026, 6, 30)),
      isFalse,
    );
  });

  test('clearsFloor keeps a period that closed on or after the floor', () {
    expect(
      clearsFloor(DateTime(2026, 7, 20), ReflectionPeriod.weekly, DateTime(2026, 7, 26)),
      isTrue,
    );
    expect(
      clearsFloor(DateTime(2026, 7, 20), ReflectionPeriod.weekly, DateTime(2026, 7, 27)),
      isFalse,
    );
    expect(clearsFloor(month(2026, 7), ReflectionPeriod.monthly, DateTime(2026, 7, 15)), isTrue);
  });
}
