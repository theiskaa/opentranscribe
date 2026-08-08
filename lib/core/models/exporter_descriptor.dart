import 'package:flutter/foundation.dart';

/// Presentation facts about one export format the build ships, for surfaces
/// that list formats (the entry export sheet, the Backup screen). Built at
/// the composition root, the one place allowed to name an exporter;
/// everything downstream renders descriptors without knowing what is behind
/// them.
@immutable
final class ExporterDescriptor {
  const ExporterDescriptor({required this.exporterId, required this.logo, this.displayName});

  final String exporterId;

  /// The format's product name (Obsidian), shown verbatim in every locale.
  /// Null for the unbranded format; surfaces label that one in the app
  /// language.
  final String? displayName;

  /// Bundle path of the format's mark, kept in its own colors.
  final String logo;
}

/// A stored format id resolved against what this build actually ships: an id
/// whose exporter is gone falls back to the first descriptor rather than
/// exporting nothing. [descriptors] must not be empty; a build ships at least
/// one format.
String resolveFormatId(String stored, List<ExporterDescriptor> descriptors) =>
    descriptors.any((d) => d.exporterId == stored) ? stored : descriptors.first.exporterId;
