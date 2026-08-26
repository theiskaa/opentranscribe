import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:reflections/reflections.dart';

/// One file a format export produces: a relative '/'-separated path plus its
/// bytes. Exporters emit these; the service writes them.
@immutable
final class ExportFile {
  ExportFile.text(this.path, String content) : bytes = Uint8List.fromList(utf8.encode(content));

  const ExportFile.bytes(this.path, this.bytes);

  final String path;
  final Uint8List bytes;
}

/// One entry as an exporter sees it: the model plus, when audio rides along,
/// the relative path the SERVICE will place the m4a at in the output tree.
/// Null means audio is not part of this export (user choice, or a
/// transcript-only entry); the exporter must not reference audio then.
@immutable
final class ExportEntry {
  const ExportEntry({required this.entry, this.audioRelativePath});

  final Entry entry;
  final String? audioRelativePath;
}

/// The localized scaffold strings an export needs, built by the caller from
/// AppLocalizations and passed through, so exporters never touch l10n.
@immutable
final class ExportStrings {
  const ExportStrings({
    required this.untitledEntry,
    required this.transcriptHeading,
    required this.quietReflection,
    required this.periodLabels,
  });

  final String untitledEntry;
  final String transcriptHeading;

  /// How a silent reflection reads; silence is a stored result, not an absence.
  final String quietReflection;

  final Map<ReflectionPeriod, String> periodLabels;

  /// Falls back to the period's wire word, so an under-filled map degrades to
  /// something legible instead of throwing; full coverage is on the caller.
  String periodLabel(ReflectionPeriod period) => periodLabels[period] ?? period.wire;
}

/// Facts every export shares: the strings, the moment it was made, and the app
/// version that made it. Exporters read the moment from here, never a clock,
/// so the same context always produces the same bytes.
@immutable
final class ExportContext {
  const ExportContext({required this.strings, required this.generatedAt, required this.appVersion});

  final ExportStrings strings;
  final DateTime generatedAt;
  final String appVersion;
}

/// Everything a whole-journal export covers: entries newest first, as the
/// store orders them, and the stored reflections.
@immutable
final class ExportSnapshot {
  ExportSnapshot({required List<ExportEntry> entries, List<Reflection> reflections = const []})
    : entries = List.unmodifiable(entries),
      reflections = List.unmodifiable(reflections);

  final List<ExportEntry> entries;
  final List<Reflection> reflections;
}

/// A one-way format plugin: models in, files out. Pure Dart, no I/O, no
/// clock reads, no l10n; the same inputs always produce the same bytes. Two
/// methods, not one, because a lone note and a journal tree are different
/// shapes, and an exporter must never sniff intent from a list length.
/// Nothing outside Deps.init() and the ExporterDescriptor list it builds may
/// name an implementation, mirroring the engine rule.
abstract interface class JournalExporter {
  /// Stable and unique across the registry: it becomes the stored format
  /// preference and must match the descriptor's exporterId built in
  /// Deps.init(), so renaming a shipped id is a breaking change.
  String get id;

  /// Must return at least one file; the service packages what it gets and has
  /// nothing to share otherwise. Paths are unique within one call only; two
  /// different entries may export to the same path across calls, and batching
  /// multiple single-entry exports into one tree is the service's collision
  /// to resolve.
  List<ExportFile> exportEntry(ExportEntry entry, ExportContext context);

  List<ExportFile> exportJournal(ExportSnapshot snapshot, ExportContext context);
}
