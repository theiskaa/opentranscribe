import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/export/file_names.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/utils/period_math.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:reflections/reflections.dart';

/// m:ss below an hour, h:mm:ss from there. Negative durations cannot occur in
/// real recordings; they clamp to zero rather than print disagreeing parts.
String exportClock(Duration duration) {
  final seconds = duration.isNegative ? 0 : duration.inSeconds;
  final minutes = (seconds ~/ 60) % 60;
  final hours = seconds ~/ 3600;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$rest';
  return '$minutes:$rest';
}

/// yyyy-MM-dd of the entry's local creation day, matching how the journal
/// groups its days.
String entryDateStamp(Entry entry) {
  final local = entry.createdAt.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// `<date><separator><sanitized title>`, the base file name an entry exports
/// under. [untitled] is sanitized too: it is an l10n string, and a translation
/// carrying a reserved character must not be able to abort an export.
String entryFileBaseName(Entry entry, {required String untitled, String separator = '-'}) =>
    '${entryDateStamp(entry)}$separator'
    '${sanitizeFileName(entry.title ?? '', fallback: sanitizeFileName(untitled))}';

/// A title reduced to one line for a markdown heading; the field accepts
/// pasted newlines, and a heading must not spill its tail into the body.
String flattenTitle(String title) => title.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The entry's title as a surface should show it, falling back to [untitled].
/// A title of spaces falls back too: the field is stored as typed, and an
/// import carries whatever the archive held, so blank is reachable and would
/// otherwise render as a heading with nothing in it.
String entryTitle(Entry entry, String untitled) {
  final title = flattenTitle(entry.title ?? '');
  return title.isEmpty ? flattenTitle(untitled) : title;
}

/// A relative export path safe to put in an `href` or `src`. Encoded per
/// segment so the separators survive, because real recording names carry
/// spaces and `#`, either of which would truncate the reference.
String urlPath(String relativePath) => relativePath.split('/').map(Uri.encodeComponent).join('/');

/// A YAML double-quoted scalar. Escapes every character that could end the
/// scalar or the line, so no value can break the frontmatter that holds it:
/// a locale or file name is read back from stored JSON and a picked file's
/// name, neither of which the app gets to promise anything about, and a bare
/// newline would fold into a fresh line that YAML may read as the block's
/// closing `---`.
String yamlScalar(String value) {
  final escaped = StringBuffer();
  for (final rune in value.runes) {
    switch (rune) {
      case 0x5C:
        escaped.write(r'\\');
      case 0x22:
        escaped.write(r'\"');
      case 0x0A:
        escaped.write(r'\n');
      case 0x0D:
        escaped.write(r'\r');
      case 0x09:
        escaped.write(r'\t');
      // C0 controls, DEL, and the three characters YAML counts as line breaks
      // beyond \n and \r: NEL, LINE SEPARATOR, PARAGRAPH SEPARATOR.
      case < 0x20 || 0x7F || 0x85 || 0x2028 || 0x2029:
        escaped.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
      default:
        escaped.writeCharCode(rune);
    }
  }
  return '"$escaped"';
}

/// The entry's JSON with [audioRelativePath] as its audio reference: what a
/// consumer outside the app can actually resolve, instead of an internal
/// recordings-directory filename. Absent audio drops the field entirely.
Map<String, dynamic> entryJsonForExport(Entry entry, String? audioRelativePath) {
  final json = entry.toJson()..remove('audioPath');
  if (audioRelativePath != null) json['audioPath'] = audioRelativePath;
  return json;
}

/// One civil day of the journal as a document reads it: the reflection cards
/// seated above the day, then the day's entries, newest first.
@immutable
final class TimelineDay {
  TimelineDay({
    required this.day,
    required List<Reflection> reflections,
    required List<ExportEntry> entries,
  }) : reflections = List.unmodifiable(reflections),
       entries = List.unmodifiable(entries);

  final DateTime day;
  final List<Reflection> reflections;
  final List<ExportEntry> entries;
}

/// The journal as one timeline, newest day first, in the order home reads it:
/// a reflection is seated above the most recent day its period covers, and
/// cards sharing a day run broad to narrow (month over week over day).
///
/// Two rules a document needs that a scrolling list does not. A card is
/// seated only within its own civil month, so it can never sit under a month
/// heading its own label contradicts; and a period with no such day falls
/// back to its own start, because an export may drop nothing. No clock is
/// read either: the service never writes a period that is still open, and
/// the same snapshot must always export the same bytes.
List<TimelineDay> journalTimeline({
  required List<ExportEntry> entries,
  required List<Reflection> reflections,
}) {
  final newestFirst = [...entries]..sort((a, b) => b.entry.createdAt.compareTo(a.entry.createdAt));
  final byDay = <DateTime, List<ExportEntry>>{};
  for (final entry in newestFirst) {
    byDay.putIfAbsent(dateOnly(entry.entry.createdAt.toLocal()), () => []).add(entry);
  }
  final entryDays = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

  // Grouped by the identity home keys its cards by and the store keys its
  // rows by, so one period seats once and carries everything stored under it.
  final byPeriod = <(ReflectionPeriod, DateTime), List<Reflection>>{};
  for (final reflection in reflections) {
    (byPeriod[(reflection.period, reflection.periodStart)] ??= []).add(reflection);
  }

  final cards = <DateTime, List<Reflection>>{};
  final seated = <(ReflectionPeriod, DateTime)>{};
  for (final day in entryDays) {
    for (final MapEntry(key: key, value: group) in byPeriod.entries) {
      final (period, start) = key;
      if (seated.contains(key)) continue;
      if (day.year != start.year || day.month != start.month) continue;
      if (!periodContains(start, period, day)) continue;
      (cards[day] ??= []).addAll(group);
      seated.add(key);
    }
  }
  for (final MapEntry(key: key, value: group) in byPeriod.entries) {
    if (seated.contains(key)) continue;
    (cards[key.$2] ??= []).addAll(group);
  }
  // Relies on ReflectionPeriod being declared narrow to broad, like the home
  // stack does.
  for (final day in cards.values) {
    day.sort((a, b) => b.period.index.compareTo(a.period.index));
  }

  final days = <DateTime>{...entryDays, ...cards.keys}.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      TimelineDay(day: day, reflections: cards[day] ?? const [], entries: byDay[day] ?? const []),
  ];
}
