import 'package:intl/intl.dart';

// Keyed by the effective locale (localeId, or Intl.defaultLocale when null),
// not the raw parameter: a live app-language switch reassigns
// Intl.defaultLocale, and keying on the raw null would freeze the ambient
// entry to whichever locale first resolved it.
final Map<String?, int> _firstDayByLocale = {};

/// The first day of the week containing [day], as a civil date (its
/// year/month/day, no time). The single source both the week strip and the
/// weekly reflection resolve through, so the reflection card and the calendar
/// can never disagree on where a week begins.
///
/// Locale-driven: Sunday-first in the US, Monday-first across most of Europe.
/// Pass [localeId] to fix the first day explicitly (e.g. 'de' -> Monday); omit
/// it to read the ambient Intl locale, which the strip does. The reflection
/// passes its language explicitly so its bucketing never depends on WHEN the
/// global Intl locale happens to be set during launch.
DateTime startOfWeek(DateTime day, {String? localeId}) {
  final effective = localeId ?? Intl.defaultLocale;
  // intl: FIRSTDAYOFWEEK is 0-based Monday; DateTime.weekday is 1-based Monday.
  final first = _firstDayByLocale.putIfAbsent(
    effective,
    () => DateFormat(null, effective).dateSymbols.FIRSTDAYOFWEEK + 1,
  );
  final delta = (day.weekday - first + 7) % 7;
  return DateTime(day.year, day.month, day.day - delta);
}

/// [d] stripped to its civil date: year/month/day, no time, no timezone.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [days] after [d], as a civil date. Never `add(Duration(days: n))` for week
/// math: Duration is epoch arithmetic, so across a DST change it lands an hour
/// off the wall-clock day and a 7-day week edge quietly gains or loses a day.
DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Whole civil days from [from] to [to] (both dates). Computed in UTC because a
/// local-time difference across a DST change is a fractional day, which
/// `inDays` truncates.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
