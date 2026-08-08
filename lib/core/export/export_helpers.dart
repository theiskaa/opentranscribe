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
