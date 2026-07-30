import 'package:intl/intl.dart';

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
  // intl: FIRSTDAYOFWEEK is 0-based Monday; DateTime.weekday is 1-based Monday.
  final first = DateFormat(null, localeId).dateSymbols.FIRSTDAYOFWEEK + 1;
  final delta = (day.weekday - first + 7) % 7;
  return DateTime(day.year, day.month, day.day - delta);
}

/// [d] stripped to its civil date: year/month/day, no time, no timezone.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
