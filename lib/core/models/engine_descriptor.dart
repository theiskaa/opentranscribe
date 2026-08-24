import 'package:flutter/widgets.dart';

/// Presentation facts about one transcription engine the build ships, for
/// surfaces that list engines (the engine picker). Built at the composition
/// root, the one place allowed to name an engine; everything downstream
/// renders descriptors without knowing what is behind them.
@immutable
final class EngineDescriptor {
  const EngineDescriptor({required this.engineId, required this.displayName, required this.logo});

  final String engineId;
  final String displayName;
  final IconData logo;
}

/// Why an engine cannot run on this device, as a kind the UI words.
enum EngineUnavailability { needsNewerDevice }
