import 'dart:convert';

import 'package:opentranscribe/core/export/export_helpers.dart';
import 'package:opentranscribe/core/export/file_names.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/models/reflection.dart';

/// The app's own export language: plain markdown for humans next to plain
/// JSON for machines. A single entry becomes `<date>-<title>.md` plus a
/// sibling `.json` carrying [Entry.toJson]; a journal becomes `entries/*.md`,
/// one `journal.json` with every entry, and the reflections as
/// `reflections/*.md` plus `reflections.json`. Markdown carries the transcript
/// as timestamped segment lines so the text stays seekable next to its audio.
final class DefaultExporter implements JournalExporter {
  const DefaultExporter();

  static const _jsonIndent = JsonEncoder.withIndent('  ');

  @override
  String get id => 'default';

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
        ExportFile.text('entries/$name', _entryMarkdown(entry, context, audioLinkPrefix: '../')),
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

  /// [audioLinkPrefix] climbs out of the md file's own directory: journal
  /// notes live under entries/ while audio lives under audio/, and a
  /// markdown link resolves relative to the FILE, not the zip root.
  String _entryMarkdown(
    ExportEntry exportEntry,
    ExportContext context, {
    String audioLinkPrefix = '',
  }) {
    final entry = exportEntry.entry;
    final strings = context.strings;
    final buffer = StringBuffer()
      ..writeln('# ${flattenTitle(entry.title ?? strings.untitledEntry)}')
      ..writeln()
      ..writeln('- ${strings.recordedLabel}: ${entry.createdAt.toUtc().toIso8601String()}')
      ..writeln('- ${strings.durationLabel}: ${exportClock(entry.duration)}');
    final locale = entry.effectiveLocaleId;
    if (locale != null) buffer.writeln('- ${strings.languageLabel}: $locale');
    final audio = exportEntry.audioRelativePath;
    if (audio != null) {
      buffer.writeln('- ${strings.audioLabel}: [${baseName(audio)}]($audioLinkPrefix$audio)');
    }
    final transcript = entry.transcript;
    if (transcript == null || transcript.isEmpty) return buffer.toString();
    buffer
      ..writeln()
      ..writeln('## ${strings.transcriptHeading}')
      ..writeln();
    if (transcript.segments.isEmpty) {
      buffer.writeln(transcript.fullText);
      return buffer.toString();
    }
    for (final segment in transcript.segments) {
      buffer.writeln('[${exportClock(segment.start)}] ${segment.text}');
    }
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
