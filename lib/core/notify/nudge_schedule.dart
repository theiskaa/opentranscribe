import 'package:opentranscribe/core/utils/week.dart';
import 'package:reflections/reflections.dart';

/// Whether [period]'s nudge fires on [day]: daily every day, weekly on the
/// week's first day ([weekStart], a DateTime weekday), monthly on the 1st.
/// The same calendar the reflection notifier schedules by.
bool nudgeFiresOn(ReflectionPeriod period, DateTime day, {required int weekStart}) =>
    switch (period) {
      ReflectionPeriod.daily => true,
      ReflectionPeriod.weekly => day.weekday == weekStart,
      ReflectionPeriod.monthly => day.day == 1,
    };

/// When the next nudge lands for [periods] at [hour]:[minute], strictly after
/// [now], or null with no period to nudge for. A month always holds a 1st, so
/// two months of days are enough to find any of them.
DateTime? nextNudge({
  required DateTime now,
  required int hour,
  required int minute,
  required Iterable<ReflectionPeriod> periods,
  required int weekStart,
}) {
  if (periods.isEmpty) return null;
  for (var offset = 0; offset < 62; offset++) {
    final at = DateTime(now.year, now.month, now.day + offset, hour, minute);
    if (!at.isAfter(now)) continue;
    if (periods.any((period) => nudgeFiresOn(period, at, weekStart: weekStart))) return at;
  }
  return null;
}

/// How a nudge's day reads from [now]: today, tomorrow, or a later date.
enum NudgeDay { today, tomorrow, later }

/// Which [NudgeDay] [at] falls on, counted in civil days so a day shortened
/// or lengthened by a clock change still counts as one.
NudgeDay nudgeDayOf(DateTime now, DateTime at) => switch (daysBetween(now, at)) {
  0 => NudgeDay.today,
  1 => NudgeDay.tomorrow,
  _ => NudgeDay.later,
};
