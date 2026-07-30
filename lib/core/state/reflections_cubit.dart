import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';

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

  /// The feature actually runs here. Surfaces stay visible regardless (the
  /// screen explains an unavailable state); this gates only generation.
  bool get available => availability.isAvailable;

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
/// availability and reads settings + history on load; a generated reflection
/// (from the foreground catch-up) refreshes the history through
/// [ReflectionService.reflectionsChanged]. The app's lifecycle observer calls
/// [load] on resume, so an Apple Intelligence toggle made in Settings is
/// picked up without a relaunch.
class ReflectionsCubit extends Cubit<ReflectionsState> {
  ReflectionsCubit({required ReflectionService service, required ReflectionSettings settings})
    : _service = service,
      _settings = settings,
      super(const ReflectionsState()) {
    _changedSub = _service.reflectionsChanged.listen((_) => _loadHistory());
    unawaited(load());
  }

  final ReflectionService _service;
  final ReflectionSettings _settings;

  StreamSubscription<void>? _changedSub;

  /// Re-probes availability and re-reads settings + history. Call on build and
  /// on resume, so enabling Apple Intelligence or a fresh reflection is picked up.
  Future<void> load() async {
    final availability = await _service.availability();
    if (isClosed) return;
    emit(
      state.copyWith(
        availability: availability,
        enabled: _settings.enabled,
        style: _settings.style,
        history: _service.history(),
      ),
    );
  }

  void _loadHistory() {
    if (isClosed) return;
    emit(state.copyWith(history: _service.history()));
  }

  /// Turns reflections on or off. Enabling kicks a catch-up so a due week lands
  /// without waiting for the next launch.
  Future<void> setEnabled(bool value) async {
    await _settings.setEnabled(value);
    if (isClosed) return;
    emit(state.copyWith(enabled: _settings.enabled));
    if (value) unawaited(_service.catchUp());
  }

  Future<void> setVoice(ReflectionVoice value) => _setStyle(() => _settings.setVoice(value));

  Future<void> setLength(ReflectionLength value) => _setStyle(() => _settings.setLength(value));

  Future<void> setSpecificity(ReflectionSpecificity value) =>
      _setStyle(() => _settings.setSpecificity(value));

  Future<void> _setStyle(Future<void> Function() write) async {
    await write();
    if (!isClosed) emit(state.copyWith(style: _settings.style));
  }

  /// Re-runs one week in the current style, replacing its stored result. Marks
  /// [ReflectionsState.regenerateFailed] on any failure rather than throwing at
  /// the UI. One at a time: a second week's regenerate while one is in flight
  /// would hijack the shared in-flight marker.
  Future<void> regenerate(DateTime weekStart) async {
    if (isClosed || state.regenerating != null) return;
    emit(state.copyWith(regenerating: weekStart, regenerateFailed: false));
    try {
      await _service.regenerate(weekStart);
    } catch (_) {
      // Model unavailable or an unexpected failure (a storage write): either
      // way the week kept its previous result, so surface the retry notice.
      if (!isClosed) emit(state.copyWith(regenerateFailed: true));
    } finally {
      // Always clears, so no failure path can leave the row spinning forever.
      if (!isClosed) emit(state.copyWith(history: _service.history(), clearRegenerating: true));
    }
  }

  Future<void> delete(DateTime weekStart) async {
    await _service.deleteReflection(weekStart);
    // The changed stream refreshes history; nothing more to do.
  }

  /// Clears the regenerate-failed flag once its notice has been shown.
  void clearRegenerateFailed() {
    if (!isClosed && state.regenerateFailed) emit(state.copyWith(regenerateFailed: false));
  }

  @override
  Future<void> close() async {
    await _changedSub?.cancel();
    return super.close();
  }
}
