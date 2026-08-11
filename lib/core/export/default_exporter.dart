import 'dart:convert';

import 'package:opentranscribe/core/export/export_helpers.dart';
import 'package:opentranscribe/core/export/file_names.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/models/reflection.dart';

/// The app's own export language: plain markdown for humans next to plain
/// JSON for machines. A single entry becomes `<date>-<title>.md` plus a
/// sibling `.json` carrying [Entry.toJson]; a journal becomes `entries/*.md`,
/// one `journal.json` with every entry, and the reflections as
/// `reflections/*.md` plus `reflections.json`. Markdown carries the entry's
/// readable text (the hand edit when one exists, else the engine's
/// transcript); the engine's timed transcript rides untouched in the JSON,
/// which is where a machine looks for it anyway.
final class DefaultExporter implements JournalExporter {
  const DefaultExporter();

  static const _jsonIndent = JsonEncoder.withIndent('  ');

  @override
  String get id => 'markdown';

  @override
  List<ExportFile> exportEntry(ExportEntry entry, ExportContext context) {
    final base = entryFileBaseName(entry.entry, untitled: context.strings.untitledEntry);
    return [
      ExportFile.text('$base.md', _entryMarkdown(entry, context)),
      ExportFile.text(
        '$base.json',
        _jsonIndent.convert(entryJsonForExport(entry.entry, entry.audioRelativePath)),
      ),
    ];
  }

  @override
  List<ExportFile> exportJournal(ExportSnapshot snapshot, ExportContext context) {
    final files = <ExportFile>[];
    final taken = <String>{};
    for (final entry in snapshot.entries) {
      final base = entryFileBaseName(entry.entry, untitled: context.strings.untitledEntry);
      final name = uniqueFileName('$base.md', taken);
      files.add(
        ExportFile.text('entries/$name', _entryMarkdown(entry, context, audioPathPrefix: '../')),
      );
    }
    files.add(
      ExportFile.text(
        'journal.json',
        _jsonIndent.convert({
          'appVersion': context.appVersion,
          'generatedAt': context.generatedAt.toUtc().toIso8601String(),
          'entries': [
            for (final e in snapshot.entries) entryJsonForExport(e.entry, e.audioRelativePath),
          ],
        }),
      ),
    );
    if (snapshot.reflections.isEmpty) return files;
    for (final reflection in snapshot.reflections) {
      files.add(
        ExportFile.text(
          'reflections/${reflection.period.wire}-${reflection.periodKey}.md',
          _reflectionMarkdown(reflection, context),
        ),
      );
    }
    files.add(
      ExportFile.text(
        'reflections.json',
        _jsonIndent.convert([for (final r in snapshot.reflections) r.toJson()]),
      ),
    );
    return files;
  }

  /// Frontmatter keys stay in English: a property name is queried and sorted
  /// on, not read as prose. [audioPathPrefix] climbs out of the note's own
  /// directory, because `audio:` is recorded relative to the note that
  /// carries it: journal notes live under `entries/` while audio lives under
  /// `audio/`, and a path a reader cannot follow from the file they are
  /// reading is worse than none.
  String _entryMarkdown(
    ExportEntry exportEntry,
    ExportContext context, {
    String audioPathPrefix = '',
  }) {
    final entry = exportEntry.entry;
    final strings = context.strings;
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('created: ${entry.createdAt.toUtc().toIso8601String()}')
      ..writeln('duration: ${yamlScalar(exportClock(entry.duration))}');
    final locale = entry.effectiveLocaleId;
    if (locale != null) buffer.writeln('locale: ${yamlScalar(locale)}');
    final audio = exportEntry.audioRelativePath;
    if (audio != null) buffer.writeln('audio: ${yamlScalar('$audioPathPrefix$audio')}');
    buffer
      ..writeln('---')
      ..writeln()
      ..writeln('# ${entryTitle(entry, strings.untitledEntry)}');
    final text = entry.readableText;
    if (text == null || text.isEmpty) return buffer.toString();
    buffer
      ..writeln()
      ..writeln('## ${strings.transcriptHeading}')
      ..writeln()
      // The full text, never a rebuild from segments: segments are word-level
      // and drop whatever the engine could not time, so rebuilding from them
      // exports something the user never said.
      ..writeln(text);
    return buffer.toString();
  }

  String _reflectionMarkdown(Reflection reflection, ExportContext context) {
    final strings = context.strings;
    final buffer = StringBuffer()
      ..writeln('# ${strings.periodLabel(reflection.period)} ${reflection.periodKey}')
      ..writeln()
      ..writeln(reflection.text ?? strings.quietReflection);
    return buffer.toString();
  }
}
