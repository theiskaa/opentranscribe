import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opentranscribe/core/app/engine_registry.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/services/engine_settings.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';

/// One engine as the picker renders it.
@immutable
final class EngineRowState {
  const EngineRowState({
    required this.descriptor,
    required this.available,
    required this.isActive,
    this.unavailability,
  });

  final EngineDescriptor descriptor;
  final bool available;
  final bool isActive;
  final EngineUnavailability? unavailability;
}

/// The picker's answer to a tap, for the surface to word (or ignore).
enum EnginePickOutcome { switched, busy, unavailable, unchanged }

@immutable
final class EnginesState {
  const EnginesState({this.rows = const []});

  final List<EngineRowState> rows;
}

/// Drives the engine picker over the registry: one row per shipped engine in
/// registry order, the active one marked. Picking swaps the service's engine,
/// persists the choice, and re-resolves the language default against the new
/// engine; an engine this device cannot run is never switched to.
// ignore_for_file: prefer_initializing_formals
// Public parameters assigned to private fields, matching the sibling cubits'
// constructor shape.
class EnginesCubit extends Cubit<EnginesState> {
  EnginesCubit({
    required List<EngineEntry> registry,
    required TranscriptionService service,
    required EngineSettings engineSettings,
    required TranscriptionSettings transcriptionSettings,
  }) : _registry = registry,
       _service = service,
       _engineSettings = engineSettings,
       _transcriptionSettings = transcriptionSettings,
       super(EnginesState(rows: _rows(registry, service.engineId)));

  final List<EngineEntry> _registry;
  final TranscriptionService _service;
  final EngineSettings _engineSettings;
  final TranscriptionSettings _transcriptionSettings;

  static List<EngineRowState> _rows(List<EngineEntry> registry, String activeId) => [
    for (final entry in registry)
      EngineRowState(
        descriptor: entry.descriptor,
        available: entry.available,
        isActive: entry.descriptor.engineId == activeId,
        unavailability: entry.unavailability,
      ),
  ];

  EnginesState _derive() => EnginesState(rows: _rows(_registry, _service.engineId));

  EngineEntry? _entry(String engineId) {
    for (final entry in _registry) {
      if (entry.descriptor.engineId == engineId) return entry;
    }
    return null;
  }

  /// One pick at a time: a second tap racing the first's persist could
  /// otherwise interleave, and the loser's revert would clobber the winner's
  /// completed switch.
  bool _picking = false;

  /// Switches to the named engine. Swap first (cheap, and refusable while a
  /// take is in flight), then persist; a failed persist attempts to revert the
  /// swap and rethrows so the surface can say the choice will not survive a
  /// relaunch. The language default re-resolves last and best-effort, in the
  /// background: a wedged or failing channel must neither hang the pick nor
  /// read as a failed switch, a late landing is dropped by apply's generation
  /// guard, and the next launch re-resolves regardless. A pick racing an
  /// in-flight pick is dropped and answers [EnginePickOutcome.unchanged].
  Future<EnginePickOutcome> pick(String engineId) async {
    if (_picking) return EnginePickOutcome.unchanged;
    _picking = true;
    try {
      return await _pick(engineId);
    } finally {
      _picking = false;
    }
  }

  Future<EnginePickOutcome> _pick(String engineId) async {
    final entry = _entry(engineId);
    if (entry == null || !entry.available) return EnginePickOutcome.unavailable;
    if (_service.engineId == engineId) {
      // Tapping the active row pins an auto-resolved choice, so a later
      // availability change cannot silently switch engines against it.
      // Best effort: nothing switched, so a failed write changes nothing.
      try {
        await _engineSettings.setEngineId(engineId);
      } catch (_) {}
      return EnginePickOutcome.unchanged;
    }
    final previous = _entry(_service.engineId);
    if (!_service.useEngine(entry.engine)) return EnginePickOutcome.busy;
    try {
      await _engineSettings.setEngineId(engineId);
    } catch (_) {
      if (isClosed) rethrow;
      // The revert itself can be refused when a take started during the await;
      // the swap then stays for the session, the rows below say so honestly,
      // and the next launch resolves the stored value.
      if (previous != null) _service.useEngine(previous.engine);
      emit(_derive());
      // A refused revert leaves the NEW engine active with the old engine's
      // locale resolution; re-resolve for it the same way a clean switch does.
      if (_service.engineId != previous?.descriptor.engineId) _reresolveLocale();
      rethrow;
    }
    if (isClosed) return EnginePickOutcome.switched;
    emit(_derive());
    _reresolveLocale();
    return EnginePickOutcome.switched;
  }

  /// The re-resolve lands a locale the model surfaces cannot see arrive
  /// (apply writes a plain field), so a landed apply pokes them explicitly.
  /// Best effort by design; see [pick].
  void _reresolveLocale() {
    unawaited(
      _transcriptionSettings.apply().then((_) => _service.notifyModelSurfaces()).catchError((_) {}),
    );
  }
}
