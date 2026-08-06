import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/view/layouts/reflections/components/period_children_logic.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('daysOfWeek', () {
    test('a week yields seven consecutive civil days', () {
      final days = daysOfWeek(DateTime(2026, 7, 20));
      expect(days, [for (var i = 20; i < 27; i++) DateTime(2026, 7, i)]);
    });

    test('days cross a month edge without gaps', () {
      final days = daysOfWeek(DateTime(2026, 7, 27));
      expect(days.first, DateTime(2026, 7, 27));
      expect(days.last, DateTime(2026, 8, 2));
    });
  });

  group('weeksOfMonth', () {
    test('the weeks cover the month from its first day to its last', () {
      final weeks = weeksOfMonth(DateTime(2026, 7), localeId: 'de');
      expect(weeks, [
        DateTime(2026, 6, 29),
        DateTime(2026, 7, 6),
        DateTime(2026, 7, 13),
        DateTime(2026, 7, 20),
        DateTime(2026, 7, 27),
      ]);
    });

    test('the week starts follow a Sunday-first locale', () {
      final weeks = weeksOfMonth(DateTime(2026, 7), localeId: 'en_US');
      expect(weeks.first, DateTime(2026, 6, 28));
      expect(weeks.last, DateTime(2026, 7, 26));
    });

    test('the last week extends into the next month', () {
      final weeks = weeksOfMonth(DateTime(2026, 7), localeId: 'de');
      expect(daysOfWeek(weeks.last).last, DateTime(2026, 8, 2));
    });

    test('a month starting on the week boundary yields exactly its weeks', () {
      final weeks = weeksOfMonth(DateTime(2027, 2), localeId: 'de');
      expect(weeks, [
        DateTime(2027, 2),
        DateTime(2027, 2, 8),
        DateTime(2027, 2, 15),
        DateTime(2027, 2, 22),
      ]);
    });
  });

  group('dayChipState', () {
    final day = DateTime(2026, 7, 21);

    test('a day with a reflection is the reflection chip even when journaled', () {
      expect(
        dayChipState(day: day, reflectedDays: {day}, journaledDays: {day}),
        DayChipState.reflection,
      );
    });

    test('a day with entries and no reflection is the entries chip', () {
      expect(
        dayChipState(day: day, reflectedDays: const {}, journaledDays: {day}),
        DayChipState.entries,
      );
    });

    test('an empty day is the empty chip', () {
      expect(
        dayChipState(day: day, reflectedDays: const {}, journaledDays: const {}),
        DayChipState.empty,
      );
    });
  });

  group('weeklyDrillTarget', () {
    test('a locale-shifted stored start matches by range and is returned as stored', () {
      final stored = DateTime(2026, 7, 26);
      expect(weeklyDrillTarget(weekStart: DateTime(2026, 7, 27), reflectedWeeks: {stored}), stored);
    });

    test('no stored week means no target', () {
      expect(
        weeklyDrillTarget(
          weekStart: DateTime(2026, 7, 27),
          reflectedWeeks: {DateTime(2026, 7, 13)},
        ),
        isNull,
      );
    });
  });

  group('monthWeekRows', () {
    test('rows mark drillable weeks with their stored start', () {
      final rows = monthWeekRows(
        monthStart: DateTime(2026, 7),
        reflectedWeeks: {DateTime(2026, 7, 13)},
        reflectedDays: const {},
        journaledDays: const {},
        localeId: 'de',
      );
      expect(rows.map((r) => r.drillStart), [null, null, DateTime(2026, 7, 13), null, null]);
    });

    test('edge-week days outside the month keep their true states', () {
      final rows = monthWeekRows(
        monthStart: DateTime(2026, 7),
        reflectedWeeks: const {},
        reflectedDays: {DateTime(2026, 6, 30)},
        journaledDays: {DateTime(2026, 8)},
        localeId: 'de',
      );
      expect(rows.first.dayStates[1], DayChipState.reflection);
      expect(rows.last.dayStates[5], DayChipState.entries);
    });
  });

  group('breadcrumbTarget', () {
    test('a day climbs to the stored week containing it', () {
      final crumb = breadcrumbTarget(
        period: ReflectionPeriod.daily,
        start: DateTime(2026, 7, 29),
        reflectedStartsByPeriod: {
          ReflectionPeriod.weekly: {DateTime(2026, 7, 26)},
        },
        localeId: 'de',
      );
      expect(crumb, (period: ReflectionPeriod.weekly, start: DateTime(2026, 7, 26)));
    });

    test('a day with no stored week climbs to its month', () {
      final crumb = breadcrumbTarget(
        period: ReflectionPeriod.daily,
        start: DateTime(2026, 7, 29),
        reflectedStartsByPeriod: {
          ReflectionPeriod.weekly: {DateTime(2026, 7, 13)},
          ReflectionPeriod.monthly: {DateTime(2026, 7)},
        },
        localeId: 'de',
      );
      expect(crumb, (period: ReflectionPeriod.monthly, start: DateTime(2026, 7)));
    });

    test('a day with no stored ancestor has no target', () {
      final crumb = breadcrumbTarget(
        period: ReflectionPeriod.daily,
        start: DateTime(2026, 7, 29),
        reflectedStartsByPeriod: {
          ReflectionPeriod.weekly: {DateTime(2026, 7, 13)},
        },
        localeId: 'de',
      );
      expect(crumb, isNull);
    });

    test('a week climbs to the month of its first day', () {
      final crumb = breadcrumbTarget(
        period: ReflectionPeriod.weekly,
        start: DateTime(2026, 6, 29),
        reflectedStartsByPeriod: {
          ReflectionPeriod.monthly: {DateTime(2026, 6), DateTime(2026, 7)},
        },
      );
      expect(crumb, (period: ReflectionPeriod.monthly, start: DateTime(2026, 6)));
    });

    test('a week straddling into the next month climbs there when only that '
        'month is stored', () {
      final crumb = breadcrumbTarget(
        period: ReflectionPeriod.weekly,
        start: DateTime(2026, 6, 29),
        reflectedStartsByPeriod: {
          ReflectionPeriod.monthly: {DateTime(2026, 7)},
        },
      );
      expect(crumb, (period: ReflectionPeriod.monthly, start: DateTime(2026, 7)));
    });

    test('a straddling week still prefers its start day\'s month when both '
        'neighbors are stored', () {
      final crumb = breadcrumbTarget(
        period: ReflectionPeriod.weekly,
        start: DateTime(2026, 6, 29),
        reflectedStartsByPeriod: {
          ReflectionPeriod.monthly: {DateTime(2026, 6), DateTime(2026, 7)},
        },
      );
      expect(crumb, (period: ReflectionPeriod.monthly, start: DateTime(2026, 6)));
    });

    test('a week has no crumb when its month holds no reflection', () {
      final crumb = breadcrumbTarget(
        period: ReflectionPeriod.weekly,
        start: DateTime(2026, 7, 6),
        reflectedStartsByPeriod: const {},
      );
      expect(crumb, isNull);
    });

    test('a month has no crumb', () {
      final crumb = breadcrumbTarget(
        period: ReflectionPeriod.monthly,
        start: DateTime(2026, 7),
        reflectedStartsByPeriod: {
          ReflectionPeriod.monthly: {DateTime(2026, 6)},
        },
      );
      expect(crumb, isNull);
    });
  });

  group('breadcrumbFallbackPeriod', () {
    test('a day with no stored ancestor falls to the weekly level when weeks exist', () {
      final fallback = breadcrumbFallbackPeriod(
        period: ReflectionPeriod.daily,
        reflectedStartsByPeriod: {
          ReflectionPeriod.weekly: {DateTime(2026, 7, 13)},
        },
      );
      expect(fallback, ReflectionPeriod.weekly);
    });

    test('a day falls past an empty weekly level to the monthly one', () {
      final fallback = breadcrumbFallbackPeriod(
        period: ReflectionPeriod.daily,
        reflectedStartsByPeriod: {
          ReflectionPeriod.weekly: const {},
          ReflectionPeriod.monthly: {DateTime(2026, 7)},
        },
      );
      expect(fallback, ReflectionPeriod.monthly);
    });

    test('a day with no broader pages anywhere has no fallback', () {
      final fallback = breadcrumbFallbackPeriod(
        period: ReflectionPeriod.daily,
        reflectedStartsByPeriod: const {},
      );
      expect(fallback, isNull);
    });

    test('a week with no containing month falls to the monthly level when months exist', () {
      final fallback = breadcrumbFallbackPeriod(
        period: ReflectionPeriod.weekly,
        reflectedStartsByPeriod: {
          ReflectionPeriod.monthly: {DateTime(2026, 7)},
        },
      );
      expect(fallback, ReflectionPeriod.monthly);
    });

    test('a month never falls anywhere', () {
      final fallback = breadcrumbFallbackPeriod(
        period: ReflectionPeriod.monthly,
        reflectedStartsByPeriod: {
          ReflectionPeriod.monthly: {DateTime(2026, 6)},
        },
      );
      expect(fallback, isNull);
    });
  });
}
