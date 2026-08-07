import 'package:flutter/foundation.dart';

/// Presentation facts about one export format the build ships, for surfaces
/// that list formats (the entry export sheet, the Backup screen). Built at
/// the composition root, the one place allowed to name an exporter;
/// everything downstream renders descriptors without knowing what is behind
/// them. Display names are product names, not l10n.
@immutable
final class ExporterDescriptor {
  const ExporterDescriptor({required this.exporterId, required this.displayName});

  final String exporterId;
  final String displayName;
}

/// A stored format id resolved against what this build actually ships: an id
/// whose exporter is gone falls back to the first descriptor rather than
/// exporting nothing.
String resolveFormatId(String stored, List<ExporterDescriptor> descriptors) =>
    descriptors.any((d) => d.exporterId == stored) ? stored : descriptors.first.exporterId;
