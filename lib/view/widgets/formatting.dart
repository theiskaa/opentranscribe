import 'package:intl/intl.dart';

import 'package:opentranscribe/core/models/entry.dart';

/// The one place display formatting for entries lives, so every surface renders
/// the same shapes. All formats follow intl's default locale, which the root
/// widget keeps in step with the app language.

/// The display title rule: the user's title, else a localized date-time
/// default. Untitled entries are always presentable.
String entryDisplayTitle(Entry entry) =>
    entry.title ?? DateFormat.MMMMd().add_jm().format(entry.createdAt.toLocal());

/// Wall-clock time of a moment, localized (e.g. 14:05 or 2:05 PM).
String formatTime(DateTime utc) => DateFormat.jm().format(utc.toLocal());

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
