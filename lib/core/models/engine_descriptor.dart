import 'package:flutter/widgets.dart';

import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// Presentation facts about one transcription engine the build ships, for
/// surfaces that list engines (the engine picker). Built at the composition
/// root, the one place allowed to name an engine; everything downstream
/// renders descriptors without knowing what is behind them.
@immutable
final class EngineDescriptor {
  const EngineDescriptor({
    required this.engineId,
    required this.displayName,
    required this.blurb,
    required this.logo,
  });

  final String engineId;
  final String displayName;

  /// One line saying what this engine is. A function because descriptors are
  /// built at the composition root, before any locale is current.
  final String Function(AppLocalizations) blurb;

  final IconData logo;
}

/// Why an engine cannot run on this device, as a kind the UI words.
enum EngineUnavailability { needsNewerDevice }
