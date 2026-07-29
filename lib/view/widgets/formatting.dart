import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/models/entry.dart';

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
  // Decided on the ROUNDED value: 999.5 KB must read 1.0 MB, never 1000 KB.
  final kbRounded = (bytes / kb).round();
  if (bytes < mb && kbRounded < 1000) return '$kbRounded KB';
  final decimal = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1);
  if (bytes < gb) return '${decimal.format(bytes / mb)} MB';
  return '${decimal.format(bytes / gb)} GB';
}
