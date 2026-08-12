import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:opentranscribe/core/utils/week.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  test('a Sunday-first locale starts the week on Sunday', () {
    Intl.defaultLocale = 'en_US';
    expect(startOfWeek(DateTime(2026, 7, 29)), DateTime(2026, 7, 26));
    expect(startOfWeek(DateTime(2026, 7, 26)), DateTime(2026, 7, 26));
  });

  test('a Monday-first locale starts the week on Monday', () {
    Intl.defaultLocale = 'de_DE';
    expect(startOfWeek(DateTime(2026, 7, 29)), DateTime(2026, 7, 27));
    expect(startOfWeek(DateTime(2026, 7, 26)), DateTime(2026, 7, 20));
  });

  test('crosses the month and year boundary', () {
    Intl.defaultLocale = 'en_US';
    expect(startOfWeek(DateTime(2026, 1, 2)), DateTime(2025, 12, 28));
  });

  test('drops the time of day, returning a civil date', () {
    Intl.defaultLocale = 'en_US';
    expect(startOfWeek(DateTime(2026, 7, 29, 23, 59)), DateTime(2026, 7, 26));
  });

  test('an explicit localeId overrides the ambient locale', () {
    Intl.defaultLocale = 'en_US';
    expect(startOfWeek(DateTime(2026, 7, 29), localeId: 'de'), DateTime(2026, 7, 27));
    Intl.defaultLocale = 'de';
    expect(startOfWeek(DateTime(2026, 7, 29), localeId: 'en_US'), DateTime(2026, 7, 26));
  });

  test('startOfWeek answers consistently for a repeated locale', () {
    Intl.defaultLocale = 'de_DE';
    expect(startOfWeek(DateTime(2026, 7, 29)), startOfWeek(DateTime(2026, 7, 29)));
    expect(startOfWeek(DateTime(2026, 7, 29), localeId: 'en_US'), DateTime(2026, 7, 26));
  });

  test('startOfWeek follows a changed ambient default locale', () {
    final prior = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    final sundayFirst = startOfWeek(DateTime(2026, 7, 29));
    Intl.defaultLocale = 'de';
    final mondayFirst = startOfWeek(DateTime(2026, 7, 29));

    expect(sundayFirst, DateTime(2026, 7, 26));
    expect(mondayFirst, DateTime(2026, 7, 27));
    expect(sundayFirst, isNot(mondayFirst));

    Intl.defaultLocale = prior;
  });

  test('addDays stays on civil days, even across a DST transition', () {
    expect(addDays(DateTime(2026, 3, 8), 7), DateTime(2026, 3, 15));
    expect(addDays(DateTime(2026, 10, 31), 7), DateTime(2026, 11, 7));
    expect(addDays(DateTime(2026, 12, 29), 7), DateTime(2027, 1, 5));
  });

  test('daysBetween counts whole civil days, immune to DST fractions', () {
    expect(daysBetween(DateTime(2026, 3, 2), DateTime(2026, 3, 16)), 14);
    expect(daysBetween(DateTime(2026, 10, 25), DateTime(2026, 11, 8)), 14);
    expect(daysBetween(DateTime(2026, 7, 20), DateTime(2026, 7, 20)), 0);
  });
}
