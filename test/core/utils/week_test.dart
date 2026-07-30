import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:opentranscribe/core/utils/week.dart';

/// Pins the locale-driven week boundary the reflection and the strip both use.
/// Dates verified: 2026-07-20 Mon, 07-26 Sun, 07-27 Mon, 07-29 Wed, 01-01 Thu,
/// 2025-12-28 Sun.
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  test('a Sunday-first locale starts the week on Sunday', () {
    Intl.defaultLocale = 'en_US';
    expect(startOfWeek(DateTime(2026, 7, 29)), DateTime(2026, 7, 26)); // Wed -> Sun
    expect(startOfWeek(DateTime(2026, 7, 26)), DateTime(2026, 7, 26)); // Sun -> itself
  });

  test('a Monday-first locale starts the week on Monday', () {
    Intl.defaultLocale = 'de_DE';
    expect(startOfWeek(DateTime(2026, 7, 29)), DateTime(2026, 7, 27)); // Wed -> Mon
    expect(startOfWeek(DateTime(2026, 7, 26)), DateTime(2026, 7, 20)); // Sun -> prior Mon
  });

  test('crosses the month and year boundary', () {
    Intl.defaultLocale = 'en_US';
    expect(startOfWeek(DateTime(2026, 1, 2)), DateTime(2025, 12, 28)); // Fri -> prior Sun
  });

  test('drops the time of day, returning a civil date', () {
    Intl.defaultLocale = 'en_US';
    expect(startOfWeek(DateTime(2026, 7, 29, 23, 59)), DateTime(2026, 7, 26));
  });

  test('an explicit localeId overrides the ambient locale', () {
    Intl.defaultLocale = 'en_US'; // ambient is Sunday-first
    expect(startOfWeek(DateTime(2026, 7, 29), localeId: 'de'), DateTime(2026, 7, 27)); // Mon
    Intl.defaultLocale = 'de'; // ambient is Monday-first
    expect(startOfWeek(DateTime(2026, 7, 29), localeId: 'en_US'), DateTime(2026, 7, 26)); // Sun
  });

  test('addDays stays on civil days, even across a DST transition', () {
    // In a US timezone, epoch arithmetic (add(Duration(days: 7))) lands this on
    // Mar 15 01:00; the civil constructor must land on midnight regardless of
    // the timezone the suite runs in.
    expect(addDays(DateTime(2026, 3, 8), 7), DateTime(2026, 3, 15));
    expect(addDays(DateTime(2026, 10, 31), 7), DateTime(2026, 11, 7));
    expect(addDays(DateTime(2026, 12, 29), 7), DateTime(2027, 1, 5)); // year edge
  });

  test('daysBetween counts whole civil days, immune to DST fractions', () {
    expect(daysBetween(DateTime(2026, 3, 2), DateTime(2026, 3, 16)), 14); // spring-forward inside
    expect(daysBetween(DateTime(2026, 10, 25), DateTime(2026, 11, 8)), 14); // fall-back inside
    expect(daysBetween(DateTime(2026, 7, 20), DateTime(2026, 7, 20)), 0);
  });
}
