import 'package:opentranscribe/core/export/file_names.dart';
import 'package:opentranscribe/core/models/entry.dart';

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

/// The entry's JSON with [audioRelativePath] as its audio reference: what a
/// consumer outside the app can actually resolve, instead of an internal
/// recordings-directory filename. Absent audio drops the field entirely.
Map<String, dynamic> entryJsonForExport(Entry entry, String? audioRelativePath) {
  final json = entry.toJson()..remove('audioPath');
  if (audioRelativePath != null) json['audioPath'] = audioRelativePath;
  return json;
}
