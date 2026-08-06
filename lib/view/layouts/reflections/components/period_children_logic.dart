import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/utils/week.dart';

/// One day's standing in the week page's strip: a stored daily reflection
/// (solid, drills), transcribed entries with no reflection (texture only), or
/// nothing.
enum DayChipState { reflection, entries, empty }

DayChipState dayChipState({
  required DateTime day,
  required Set<DateTime> reflectedDays,
  required Set<DateTime> journaledDays,
}) {
  if (reflectedDays.contains(day)) return DayChipState.reflection;
  if (journaledDays.contains(day)) return DayChipState.entries;
  return DayChipState.empty;
}

/// The seven civil days of the week starting at [weekStart].
List<DateTime> daysOfWeek(DateTime weekStart) => [
  for (var i = 0; i < 7; i++) addDays(weekStart, i),
];

/// Every week overlapping [monthStart]'s month, as week starts, oldest first.
/// The edge weeks reach into the neighboring months: the row IS the week, and
/// the week page it drills to shows the same seven days.
List<DateTime> weeksOfMonth(DateTime monthStart, {String? localeId}) {
  final end = nextPeriodStart(monthStart, ReflectionPeriod.monthly);
  final weeks = <DateTime>[];
  var start = startOfWeek(monthStart, localeId: localeId);
  while (start.isBefore(end)) {
    weeks.add(start);
    start = addDays(start, 7);
  }
  return weeks;
}

/// The STORED weekly start whose range overlaps [weekStart], or null. Range
/// overlap, not equality: a week stored under another locale's first day still
/// drills, and returning the stored start is what lets the landing exact-match
/// its page.
DateTime? weeklyDrillTarget({required DateTime weekStart, required Set<DateTime> reflectedWeeks}) {
  for (final stored in reflectedWeeks) {
    if (periodsOverlap(stored, weekStart, ReflectionPeriod.weekly)) return stored;
  }
  return null;
}

typedef MonthWeekRow = ({DateTime weekStart, DateTime? drillStart, List<DayChipState> dayStates});

/// The month page's contents: one row per week of the month, each carrying its
/// drill target (null when that week holds no stored page) and its seven days'
/// states for the density dots.
List<MonthWeekRow> monthWeekRows({
  required DateTime monthStart,
  required Set<DateTime> reflectedWeeks,
  required Set<DateTime> reflectedDays,
  required Set<DateTime> journaledDays,
  String? localeId,
}) => [
  for (final weekStart in weeksOfMonth(monthStart, localeId: localeId))
    (
      weekStart: weekStart,
      drillStart: weeklyDrillTarget(weekStart: weekStart, reflectedWeeks: reflectedWeeks),
      dayStates: [
        for (final day in daysOfWeek(weekStart))
          dayChipState(day: day, reflectedDays: reflectedDays, journaledDays: journaledDays),
      ],
    ),
];

typedef BreadcrumbTarget = ({ReflectionPeriod period, DateTime start});

/// Where the smart back climbs from the viewed page, or null (the top of the
/// hierarchy: back pops the route instead). A day climbs to its NEAREST
/// stored ancestor - the containing week, else the day's month - so a
/// deep-linked day whose week went unwritten still reshapes up rather than
/// abruptly leaving. A week climbs to a stored month that lists it as a row -
/// its start day's month first, else the month its tail reaches into, since a
/// month's edge weeks straddle into the neighboring month; a month is the
/// top. Only stored pages are offered - the same rule that gates drilling
/// down, so up and down traverse the same set of pages and a climb can never
/// land where no page exists.
BreadcrumbTarget? breadcrumbTarget({
  required ReflectionPeriod period,
  required DateTime start,
  required Map<ReflectionPeriod, Set<DateTime>> reflectedStartsByPeriod,
  String? localeId,
}) {
  final months = reflectedStartsByPeriod[ReflectionPeriod.monthly] ?? const {};
  switch (period) {
    case ReflectionPeriod.daily:
      final week = weeklyDrillTarget(
        weekStart: startOfWeek(start, localeId: localeId),
        reflectedWeeks: reflectedStartsByPeriod[ReflectionPeriod.weekly] ?? const {},
      );
      if (week != null) return (period: ReflectionPeriod.weekly, start: week);
      final month = DateTime(start.year, start.month);
      if (months.contains(month)) return (period: ReflectionPeriod.monthly, start: month);
      return null;
    case ReflectionPeriod.weekly:
      for (final day in [start, addDays(start, 6)]) {
        final month = DateTime(day.year, day.month);
        if (months.contains(month)) return (period: ReflectionPeriod.monthly, start: month);
      }
      return null;
    case ReflectionPeriod.monthly:
      return null;
  }
}

/// The level the smart back falls to when [breadcrumbTarget] finds no stored
/// ancestor: the nearest broader period holding ANY stored page, or null
/// (the true top: back may pop the route). The landing is the level's newest
/// page, not a containing ancestor, so the caller must land it PLAIN - no
/// roll, no seat close - a transformation would claim a containment that is
/// not there.
ReflectionPeriod? breadcrumbFallbackPeriod({
  required ReflectionPeriod period,
  required Map<ReflectionPeriod, Set<DateTime>> reflectedStartsByPeriod,
}) {
  final broader = switch (period) {
    ReflectionPeriod.daily => const [ReflectionPeriod.weekly, ReflectionPeriod.monthly],
    ReflectionPeriod.weekly => const [ReflectionPeriod.monthly],
    ReflectionPeriod.monthly => const <ReflectionPeriod>[],
  };
  for (final p in broader) {
    if ((reflectedStartsByPeriod[p] ?? const {}).isNotEmpty) return p;
  }
  return null;
}
