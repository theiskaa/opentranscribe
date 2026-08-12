import 'package:opentranscribe/core/export/export_helpers.dart';
import 'package:opentranscribe/core/export/file_names.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/utils/week.dart';

/// Export shaped for an Obsidian vault: markdown only, YAML frontmatter,
/// `![[...]]` audio embeds, and reflections that `[[wikilink]]` the entry
/// notes of their period. Entry notes carry no heading of their own, because
/// Obsidian titles a note by its file name. A single entry is one note (plus
/// its audio); a
/// journal is a vault fragment with `entries/`, `reflections/` and `audio/`
/// folders. Wikilinks use bare basenames, Obsidian's shortest-path form, so
/// notes keep resolving wherever a vault reorganizes them.
final class ObsidianExporter implements JournalExporter {
  const ObsidianExporter();

  /// Obsidian's link parser reserves these; a note name carrying one can
  /// never be wikilinked, and `]]` inside a name corrupts the linking line.
  static final _linkReserved = RegExp(r'[\[\]#^|]');

  @override
  String get id => 'obsidian';

  @override
  List<ExportFile> exportEntry(ExportEntry entry, ExportContext context) => [
    ExportFile.text(
      '${_noteBaseName(entry.entry, context.strings.untitledEntry)}.md',
      _entryNote(entry, context),
    ),
  ];

  @override
  List<ExportFile> exportJournal(ExportSnapshot snapshot, ExportContext context) {
    final files = <ExportFile>[];
    final taken = <String>{};
    final noteNames = <String, String>{};
    for (final entry in snapshot.entries) {
      final base = _noteBaseName(entry.entry, context.strings.untitledEntry);
      final name = uniqueFileName('$base.md', taken);
      noteNames[entry.entry.id] = name.substring(0, name.length - 3);
      files.add(ExportFile.text('entries/$name', _entryNote(entry, context)));
    }
    for (final reflection in snapshot.reflections) {
      files.add(
        ExportFile.text(
          'reflections/${reflection.period.wire} ${reflection.periodKey}.md',
          _reflectionNote(reflection, snapshot, noteNames, context),
        ),
      );
    }
    return files;
  }

  String _noteBaseName(Entry entry, String untitled) {
    final base = entryFileBaseName(entry, untitled: untitled, separator: ' ');
    final linkable = base.replaceAll(_linkReserved, '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return linkable.isEmpty ? entryDateStamp(entry) : linkable;
  }

  String _entryNote(ExportEntry exportEntry, ExportContext context) {
    final entry = exportEntry.entry;
    final buffer = StringBuffer()..writeln('---');
    final title = entry.title;
    // The note's file name is a sanitized, link-safe, 80-rune truncation of
    // the title, and can reduce to the bare date. This is the only lossless
    // copy the note carries; without it a title made of reserved characters
    // would not survive the export at all.
    if (title != null) buffer.writeln('title: ${yamlScalar(flattenTitle(title))}');
    buffer
      ..writeln('id: ${yamlScalar(entry.id)}')
      ..writeln('created: ${entry.createdAt.toUtc().toIso8601String()}')
      ..writeln('duration_seconds: ${entry.duration.inSeconds}');
    final locale = entry.effectiveLocaleId;
    if (locale != null) buffer.writeln('locale: ${yamlScalar(locale)}');
    buffer
      ..writeln('tags:')
      ..writeln('  - opentranscribe')
      ..writeln('---')
      ..writeln();
    final audio = exportEntry.audioRelativePath;
    if (audio != null) {
      final basename = baseName(audio);
      buffer
        ..writeln('![[$basename]]')
        ..writeln();
    }
    final text = entry.readableText;
    if (text != null && text.isNotEmpty) buffer.writeln(text);
    return buffer.toString();
  }

  String _reflectionNote(
    Reflection reflection,
    ExportSnapshot snapshot,
    Map<String, String> noteNames,
    ExportContext context,
  ) {
    final strings = context.strings;
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('period: ${reflection.period.wire}')
      ..writeln('start: ${reflection.periodKey}')
      ..writeln('tags:')
      ..writeln('  - opentranscribe')
      ..writeln('---')
      ..writeln()
      ..writeln('# ${strings.periodLabel(reflection.period)} ${reflection.periodKey}')
      ..writeln()
      ..writeln(reflection.text ?? strings.quietReflection);
    final linked = [
      for (final entry in snapshot.entries)
        if (periodContains(
          reflection.periodStart,
          reflection.period,
          dateOnly(entry.entry.createdAt.toLocal()),
        ))
          noteNames[entry.entry.id],
    ];
    if (linked.isEmpty) return buffer.toString();
    buffer.writeln();
    for (final name in linked) {
      buffer.writeln('- [[$name]]');
    }
    return buffer.toString();
  }
}
