import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_exception.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';

// The collaborators are private (a cubit owns them) and named parameters cannot
// be private, so initializing formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// What the reflection surfaces render: whether the feature runs here, the
/// preferences, and the history of past weeks.
@immutable
final class ReflectionsState {
  const ReflectionsState({
    this.availability = const ReflectionAvailability.unsupported(),
    this.enabled = true,
    this.style = ReflectionStyle.defaults,
    this.history = const [],
    this.regenerating,
    this.regenerateFailed = false,
  });

  final ReflectionAvailability availability;
  final bool enabled;
  final ReflectionStyle style;

  /// Past weeks, newest first. Includes silent weeks (a quiet week).
  final List<Reflection> history;

  /// The week whose regenerate is in flight, or null.
  final DateTime? regenerating;

  /// True when the last regenerate could not run (model unavailable), so a
  /// surface can offer a retry. Cleared on the next action.
  final bool regenerateFailed;

  /// The feature actually runs here.
  bool get available => availability.isAvailable;

  /// Eligible hardware: it can run, even if the user must still enable Apple
  /// Intelligence or wait for the model. deviceNotEligible/unsupported are not
  /// eligible and stay invisible.
  bool get eligible =>
      availability.status != ReflectionAvailabilityStatus.deviceNotEligible &&
      availability.status != ReflectionAvailabilityStatus.unsupported;

  ReflectionsState copyWith({
    ReflectionAvailability? availability,
    bool? enabled,
    ReflectionStyle? style,
    List<Reflection>? history,
    DateTime? regenerating,
    bool clearRegenerating = false,
    bool? regenerateFailed,
  }) => ReflectionsState(
    availability: availability ?? this.availability,
    enabled: enabled ?? this.enabled,
    style: style ?? this.style,
    history: history ?? this.history,
    regenerating: clearRegenerating ? null : (regenerating ?? this.regenerating),
    regenerateFailed: regenerateFailed ?? this.regenerateFailed,
  );
}

/// Drives the reflection surfaces over the [ReflectionService]. Probes
/// availability and reads settings + history on load and on each change; a
/// generated reflection (from the foreground catch-up) refreshes the history
/// through [ReflectionService.reflectionsChanged].
class ReflectionsCubit extends Cubit<ReflectionsState> {
  ReflectionsCubit({
    required ReflectionService service,
    required ReflectionSettings settings,
    required ReflectionStore store,
    required ReflectionEngine engine,
  }) : _service = service,
       _settings = settings,
       _store = store,
       _engine = engine,
       super(const ReflectionsState()) {
    _changedSub = _service.reflectionsChanged.listen((_) => _loadHistory());
    unawaited(load());
  }

  final ReflectionService _service;
  final ReflectionSettings _settings;
  final ReflectionStore _store;
  final ReflectionEngine _engine;

  StreamSubscription<void>? _changedSub;

  /// Re-probes availability and re-reads settings + history. Call on build and
  /// on resume, so enabling Apple Intelligence or a fresh reflection is picked up.
  Future<void> load() async {
    final availability = await _engine.availability();
    if (isClosed) return;
    emit(
      state.copyWith(
        availability: availability,
        enabled: _settings.enabled,
        style: _settings.style,
        history: _store.all(),
      ),
    );
  }

  void _loadHistory() {
    if (isClosed) return;
    emit(state.copyWith(history: _store.all()));
  }

  /// Turns reflections on or off. Enabling kicks a catch-up so a due week lands
  /// without waiting for the next launch.
  Future<void> setEnabled(bool value) async {
    await _settings.setEnabled(value);
    if (isClosed) return;
    emit(state.copyWith(enabled: _settings.enabled));
    if (value) unawaited(_service.catchUp());
  }

  Future<void> setVoice(ReflectionVoice value) async {
    await _settings.setVoice(value);
    if (!isClosed) emit(state.copyWith(style: _settings.style));
  }

  Future<void> setLength(ReflectionLength value) async {
    await _settings.setLength(value);
    if (!isClosed) emit(state.copyWith(style: _settings.style));
  }

  Future<void> setSpecificity(ReflectionSpecificity value) async {
    await _settings.setSpecificity(value);
    if (!isClosed) emit(state.copyWith(style: _settings.style));
  }

  /// Re-runs one week in the current style, replacing its stored result. Marks
  /// [ReflectionsState.regenerateFailed] when the model could not run, rather
  /// than throwing at the UI.
  Future<void> regenerate(DateTime weekStart) async {
    emit(state.copyWith(regenerating: weekStart, regenerateFailed: false));
    try {
      await _service.regenerate(weekStart);
      if (isClosed) return;
      emit(state.copyWith(history: _store.all(), clearRegenerating: true));
    } on ReflectionUnavailable {
      if (isClosed) return;
      emit(state.copyWith(clearRegenerating: true, regenerateFailed: true));
    }
  }

  Future<void> delete(DateTime weekStart) async {
    await _service.deleteReflection(weekStart);
    // The changed stream refreshes history; nothing more to do.
  }

  @override
  Future<void> close() async {
    await _changedSub?.cancel();
    return super.close();
  }
}
