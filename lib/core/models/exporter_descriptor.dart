import 'package:flutter/foundation.dart';

/// Presentation facts about one export format the build ships, for surfaces
/// that list formats (the entry export sheet, the Backup screen). Built at
/// the composition root, the one place allowed to name an exporter;
/// everything downstream renders descriptors without knowing what is behind
/// them.
@immutable
final class ExporterDescriptor {
  const ExporterDescriptor({
    required this.exporterId,
    required this.displayName,
    required this.logo,
  });

  final String exporterId;

  /// The format's own name (Markdown, Obsidian), shown verbatim in every
  /// locale: a format is named by its makers, not translated.
  final String displayName;

  /// Bundle path of the format's mark, an SVG. A branded mark carries its own
  /// colors; a monochrome one paints in `currentColor` so the surface can
  /// resolve it against the theme.
  final String logo;
}

/// A stored format id resolved against what this build actually ships: an id
/// whose exporter is gone falls back to the first descriptor rather than
/// exporting nothing. [descriptors] must not be empty; a build ships at least
/// one format.
String resolveFormatId(String stored, List<ExporterDescriptor> descriptors) =>
    descriptors.any((d) => d.exporterId == stored) ? stored : descriptors.first.exporterId;
