import 'package:opentranscribe/core/utils/week.dart';
import 'package:reflections/reflections.dart';

/// The civil date [day] falls into for [period]: the day itself, its locale
/// week's first day, or the first of its month. The single boundary the
/// catch-up and the timeline both resolve through, so they can never disagree
/// on where a period begins. [localeId] fixes the week's first day; it is
/// ignored for daily and monthly, whose boundaries are locale-independent.
DateTime startOfPeriod(DateTime day, ReflectionPeriod period, {String? localeId}) =>
    switch (period) {
      ReflectionPeriod.daily => dateOnly(day),
      ReflectionPeriod.weekly => startOfWeek(day, localeId: localeId),
      ReflectionPeriod.monthly => DateTime(day.year, day.month),
    };

/// The start of the period after the one beginning at [start]: the exclusive
/// end of [start]'s range. One civil day, seven civil days, or the first of the
/// next month (month 13 rolls to January). Civil-date math, never Duration, so
/// a DST edge cannot shift a boundary off its wall-clock day.
DateTime nextPeriodStart(DateTime start, ReflectionPeriod period) => switch (period) {
  ReflectionPeriod.daily => addDays(start, 1),
  ReflectionPeriod.weekly => addDays(start, 7),
  ReflectionPeriod.monthly => DateTime(start.year, start.month + 1),
};

/// Whether the [period] ranges starting at [a] and [b] overlap. The one overlap
/// rule the done-check and the timeline share, so they can never disagree about
/// which two starts name the same period. Judged by range, not equality,
/// because a weekly start can shift when the locale's first day changes.
bool periodsOverlap(DateTime a, DateTime b, ReflectionPeriod period) =>
    b.isBefore(nextPeriodStart(a, period)) && a.isBefore(nextPeriodStart(b, period));

/// Whether [day] falls within the [period] range beginning at [start].
bool periodContains(DateTime start, ReflectionPeriod period, DateTime day) =>
    !day.isBefore(start) && day.isBefore(nextPeriodStart(start, period));

/// Whether the [period] beginning at [start] closed at least partly on or after
/// [floor]: the no-backfill rule, judged by range so a first-day shift cannot
/// pull a pre-feature period back over the line.
bool clearsFloor(DateTime start, ReflectionPeriod period, DateTime floor) =>
    nextPeriodStart(start, period).isAfter(floor);
