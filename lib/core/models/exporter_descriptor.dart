import 'package:flutter/foundation.dart';

/// A format this build ships, as a surface has to talk about it. Naming a
/// value here is the composition root's job, the one place allowed to know
/// which exporters exist; a surface pairs the value with its own copy instead
/// of matching on an exporter id.
enum ExportFormat { markdown, obsidian, web }

/// Presentation facts about one export format the build ships, for surfaces
/// that list formats (the entry export sheet, the Backup screen). Built at
/// the composition root, the one place allowed to name an exporter;
/// everything downstream renders descriptors without knowing what is behind
/// them.
@immutable
final class ExporterDescriptor {
  const ExporterDescriptor({required this.exporterId, required this.format, required this.logo});

  final String exporterId;

  /// Which format this is, so a surface can look up its name and its note.
  final ExportFormat format;

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
