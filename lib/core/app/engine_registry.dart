import 'package:flutter/foundation.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:transcriber/transcriber.dart';

/// One shipped engine in the registry: its presentation facts, the constructed
/// instance, and whether this device can run it. Lives beside the composition
/// root, not under models, because it holds a live engine. The registry's
/// order is preference order; auto mode resolves to the first available entry,
/// so a new engine is one more entry at the composition root and nothing else.
@immutable
final class EngineEntry {
  const EngineEntry({
    required this.descriptor,
    required this.engine,
    required this.available,
    this.unavailability,
  }) : assert(available == (unavailability == null), 'unavailability iff not available');

  final EngineDescriptor descriptor;
  final TranscriptionEngine engine;
  final bool available;

  /// The reason behind an unavailable entry; null when [available].
  final EngineUnavailability? unavailability;
}
