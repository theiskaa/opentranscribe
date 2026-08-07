import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// The one place display formatting for entries lives, so every surface renders
/// the same shapes. Date formats take an explicit locale so they render in the
/// app language and rebuild when it changes; when omitted they follow intl's
/// default locale, which the root widget keeps in step with the app language.

/// The app locale as a date-format tag. Reading it makes the caller a
/// [Localizations] dependent, so date text rebuilds when the language changes,
/// and passing it to [DateFormat] avoids relying on the mutable global
/// [Intl.defaultLocale], which the async localization load can leave a step
/// behind on the first paint after a switch.
String localeTag(BuildContext context) => Localizations.localeOf(context).languageCode;

/// The display title rule: the user's title, else a localized date-time
/// default. Untitled entries are always presentable.
String entryDisplayTitle(Entry entry, [String? locale]) =>
    entry.title ?? DateFormat.MMMMd(locale).add_jm().format(entry.createdAt.toLocal());

/// Wall-clock time of a moment, localized (e.g. 14:05 or 2:05 PM).
String formatTime(DateTime utc, [String? locale]) => DateFormat.jm(locale).format(utc.toLocal());

/// A week's label: "Jul 20 – 26", or "Jun 30 – Jul 6" across a month. A week
/// not wholly inside [now]'s year closes with its year ("Dec 29 – Jan 4,
/// 2026"), or every past January would shadow this one's. The dash is an en
/// dash (a range), not an em dash. Tests pin [now]; callers omit it.
String weekRangeLabel(DateTime weekStart, String locale, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final end = addDays(weekStart, 6);
  final start = DateFormat.MMMd(locale).format(weekStart);
  if (weekStart.year != today.year || end.year != today.year) {
    return '$start – ${DateFormat.yMMMd(locale).format(end)}';
  }
  final endText = weekStart.month == end.month
      ? DateFormat.d(locale).format(end)
      : DateFormat.MMMd(locale).format(end);
  return '$start – $endText';
}

/// A day as reading meta: "Jul 27" inside [now]'s year, "Jul 27, 2025"
/// outside it, so an old record dates itself. Tests pin [now]; callers omit
/// it.
String shortDateLabel(DateTime date, String locale, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (date.year == today.year) return DateFormat.MMMd(locale).format(date);
  return DateFormat.yMMMd(locale).format(date);
}

/// A reflection page's title for its [period] starting at [start]: the day
/// ("Jul 27"), the week's range ("Jul 20 – 26"), or the month ("August"). A
/// start outside [now]'s year carries the year, so an old page dates itself.
/// Tests pin [now]; callers omit it.
String periodRangeLabel(ReflectionPeriod period, DateTime start, String locale, {DateTime? now}) =>
    switch (period) {
      ReflectionPeriod.daily => shortDateLabel(start, locale, now: now),
      ReflectionPeriod.weekly => weekRangeLabel(start, locale, now: now),
      ReflectionPeriod.monthly =>
        start.year == (now ?? DateTime.now()).year
            ? DateFormat.MMMM(locale).format(start)
            : DateFormat.yMMMM(locale).format(start),
    };

/// The "quiet period" marker for [period]: a day, week, or month the model
/// recorded as silence. One place so the home card and the pager name a
/// silence identically.
String reflectionQuietLabel(AppLocalizations l10n, ReflectionPeriod period) => switch (period) {
  ReflectionPeriod.daily => l10n.reflectionQuietDay,
  ReflectionPeriod.weekly => l10n.reflectionQuietWeek,
  ReflectionPeriod.monthly => l10n.reflectionQuietMonth,
};

/// A duration as m:ss, the audio-length shape for player surfaces.
String formatClock(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// A duration in spoken units (1m 34s, 58s, 1h 12m), the card-meta shape.
String formatDurationCompact(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  return '${d.inSeconds}s';
}

/// A byte count as storage prose (312 KB, 4.5 MB, 1.2 GB). Decimal units,
/// matching what iOS itself reports for storage; whole numbers below a
/// megabyte, one locale-aware decimal from there up.
String formatBytes(int bytes, [String? locale]) {
  const kb = 1000, mb = kb * 1000, gb = mb * 1000;
  if (bytes < kb) return '$bytes B';
  // Every seam is decided on the ROUNDED value: 999.5 KB must read 1.0 MB
  // and 999.95 MB must read 1.0 GB, never "1000" of the smaller unit.
  final kbRounded = (bytes / kb).round();
  if (bytes < mb && kbRounded < 1000) return '$kbRounded KB';
  final decimal = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1);
  final mbTenths = (bytes / mb * 10).round();
  if (bytes < gb && mbTenths < 10000) return '${decimal.format(mbTenths / 10)} MB';
  return '${decimal.format(bytes / gb)} GB';
}
