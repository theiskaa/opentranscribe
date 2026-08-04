import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';

// The collaborators are private (a cubit owns them) and named parameters cannot
// be private, so initializing formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// What the reflection surfaces render for the [viewedPeriod]: whether the
/// feature runs here, that period's preferences, and its history of past
/// periods. [ReflectionsCubit.setViewedPeriod] changes [viewedPeriod]; every
/// other field is that period's view.
@immutable
final class ReflectionsState {
  const ReflectionsState({
    this.availability = const ReflectionAvailability.unsupported(),
    this.viewedPeriod = ReflectionPeriod.weekly,
    this.periods = const [ReflectionPeriod.weekly],
    this.enabledByPeriod = const {},
    this.enabled = true,
    this.style = ReflectionStyle.defaults,
    this.history = const [],
    this.homeReflections = const [],
    this.timeline = const [],
    this.regenerating,
    this.regenerateFailed = false,
    this.loaded = false,
  });

  final ReflectionAvailability availability;

  /// The period the surfaces show; defaults to weekly.
  final ReflectionPeriod viewedPeriod;

  /// The periods the switcher offers, in Day/Week/Month order: those enabled OR
  /// holding stored reflections, so a period turned off after use stays
  /// browsable. A single entry means no switcher (nothing to switch between).
  final List<ReflectionPeriod> periods;

  /// Each period's enabled flag, for the menu's per-period toggles.
  final Map<ReflectionPeriod, bool> enabledByPeriod;

  /// Whether the [viewedPeriod] generates.
  final bool enabled;

  /// The [viewedPeriod]'s style.
  final ReflectionStyle style;

  /// The viewed period's past reflections, newest first. Includes silences.
  final List<Reflection> history;

  /// The reflections the HOME timeline cards read: every ENABLED period's,
  /// independent of [viewedPeriod], so paging the reflections screen never
  /// disturbs home's cards. A period turned off drops its cards from home while
  /// keeping them browsable on the screen.
  final List<Reflection> homeReflections;

  /// The pager's spine for the viewed period: every closed period worth a page,
  /// OLDEST first (index 0 = oldest, last = the newest closed one, the landing
  /// page).
  final List<ReflectionPage> timeline;

  /// The period start whose regenerate is in flight, or null.
  final DateTime? regenerating;

  /// True when the last regenerate could not run (model unavailable), so a
  /// surface can offer a retry. Cleared on the next action.
  final bool regenerateFailed;

  /// True once [history] reflects a real read of the store. Before that it is
  /// only the initial empty placeholder, and a surface diffing arrivals
  /// against it would mark the entire history as newly arrived.
  final bool loaded;

  /// The feature actually runs here. Surfaces stay visible regardless (the
  /// screen explains an unavailable state); this gates only generation.
  bool get available => availability.isAvailable;

  ReflectionsState copyWith({
    ReflectionAvailability? availability,
    ReflectionPeriod? viewedPeriod,
    List<ReflectionPeriod>? periods,
    Map<ReflectionPeriod, bool>? enabledByPeriod,
    bool? enabled,
    ReflectionStyle? style,
    List<Reflection>? history,
    List<Reflection>? homeReflections,
    List<ReflectionPage>? timeline,
    DateTime? regenerating,
    bool clearRegenerating = false,
    bool? regenerateFailed,
    bool? loaded,
  }) => ReflectionsState(
    availability: availability ?? this.availability,
    viewedPeriod: viewedPeriod ?? this.viewedPeriod,
    periods: periods ?? this.periods,
    enabledByPeriod: enabledByPeriod ?? this.enabledByPeriod,
    enabled: enabled ?? this.enabled,
    style: style ?? this.style,
    history: history ?? this.history,
    homeReflections: homeReflections ?? this.homeReflections,
    timeline: timeline ?? this.timeline,
    regenerating: clearRegenerating ? null : (regenerating ?? this.regenerating),
    regenerateFailed: regenerateFailed ?? this.regenerateFailed,
    loaded: loaded ?? this.loaded,
  );
}

/// Drives the reflection surfaces over the [ReflectionService]. Probes
/// availability and reads settings + history on load; a generated reflection
/// (from the foreground catch-up) refreshes the history through
/// [ReflectionService.reflectionsChanged]. The app's lifecycle observer calls
/// [load] on resume, so making the on-device model available in Settings is
/// picked up without a relaunch.
class ReflectionsCubit extends Cubit<ReflectionsState> {
  ReflectionsCubit({
    required ReflectionService service,
    required ReflectionSettings settings,
    ReflectionNotifier? notifier,
  }) : _service = service,
       _settings = settings,
       _notifier = notifier,
       super(const ReflectionsState()) {
    _changedSub = _service.reflectionsChanged.listen((_) => _loadHistory());
    unawaited(load());
  }

  final ReflectionService _service;
  final ReflectionSettings _settings;

  /// Reconciles the weekly notification when reflections are turned on or off:
  /// disabling the feature must also drop its nudge. Optional so tests without a
  /// notification stack still build the cubit.
  final ReflectionNotifier? _notifier;

  StreamSubscription<void>? _changedSub;

  /// Re-probes availability and re-reads the viewed period's settings + history.
  /// Call on build and on resume, so an enabled model or a fresh reflection is
  /// picked up.
  Future<void> load() async {
    final availability = await _service.availability();
    if (isClosed) return;
    emit(_deriveView(state.copyWith(availability: availability)));
  }

  void _loadHistory() {
    if (isClosed) return;
    emit(_deriveView(state));
  }

  /// Switches which period the surfaces show, re-reading that period's enabled
  /// flag, style, and timeline. No generation: a period that is off shows its
  /// stored history and the off notice, exactly like weekly does today. Any
  /// regenerate marker belongs to the period left behind, so it is dropped: its
  /// stored start could collide with a same-dated page under the new period.
  void setViewedPeriod(ReflectionPeriod period) {
    if (isClosed || period == state.viewedPeriod) return;
    emit(
      _deriveView(
        state.copyWith(viewedPeriod: period, clearRegenerating: true, regenerateFailed: false),
      ),
    );
  }

  /// Everything derived from the viewed period, computed in one place so every
  /// refresh path (load, a period switch, an enable, the changed stream, a
  /// regenerate) agrees: the switcher's period set, each period's enabled flag,
  /// and the viewed period's style, history, and timeline. If the viewed period
  /// left the set (turned off with no history), the view falls to the first one
  /// offered so the surfaces never point at a period the switcher cannot reach.
  ReflectionsState _deriveView(ReflectionsState s) {
    final histories = _service.historiesByPeriod();
    final enabledByPeriod = {for (final p in ReflectionPeriod.values) p: _settings.enabledFor(p)};
    final periods = [
      for (final p in ReflectionPeriod.values)
        if (enabledByPeriod[p]! || histories[p]!.isNotEmpty) p,
    ];
    final period = periods.contains(s.viewedPeriod) || periods.isEmpty
        ? s.viewedPeriod
        : periods.first;
    final history = histories[period]!;
    return s.copyWith(
      loaded: true,
      viewedPeriod: period,
      periods: periods,
      enabledByPeriod: enabledByPeriod,
      enabled: enabledByPeriod[period]!,
      style: _settings.styleFor(period),
      history: history,
      homeReflections: [
        for (final p in ReflectionPeriod.values)
          if (enabledByPeriod[p]!) ...histories[p]!,
      ],
      timeline: reflectionTimeline(
        period: period,
        history: history,
        journaledStarts: _service.journaledStartsFor(period),
        deletedStarts: _service.deletedStartsFor(period),
        floor: _settings.floorFor(period),
        currentStart: _service.currentStartFor(period),
      ),
    );
  }

  /// Turns the viewed period's reflections on or off (the disabled-page button).
  Future<void> setEnabled(bool value) => setPeriodEnabled(state.viewedPeriod, value);

  /// Turns one [period] on or off (the menu's per-period toggles). Enabling
  /// kicks a catch-up so a due period lands without waiting for the next launch.
  Future<void> setPeriodEnabled(ReflectionPeriod period, bool value) async {
    await _settings.setEnabledFor(period, value);
    if (isClosed) return;
    emit(_deriveView(state));
    if (value) unawaited(_service.catchUp());
    // Enabling may make the nudge eligible; disabling must cancel it.
    unawaited(_notifier?.sync());
  }

  Future<void> setVoice(ReflectionVoice value) => _setStyle((p) => _settings.setVoiceFor(p, value));

  Future<void> setLength(ReflectionLength value) =>
      _setStyle((p) => _settings.setLengthFor(p, value));

  Future<void> setSpecificity(ReflectionSpecificity value) =>
      _setStyle((p) => _settings.setSpecificityFor(p, value));

  Future<void> _setStyle(Future<void> Function(ReflectionPeriod) write) async {
    final period = state.viewedPeriod;
    await write(period);
    if (!isClosed) emit(state.copyWith(style: _settings.styleFor(period)));
  }

  /// Re-runs one period start in its current style, replacing the stored result.
  /// Marks [ReflectionsState.regenerateFailed] on any failure rather than
  /// throwing at the UI. One at a time: a second regenerate while one is in
  /// flight would hijack the shared in-flight marker.
  Future<void> regenerate(DateTime start) async {
    if (isClosed || state.regenerating != null) return;
    emit(state.copyWith(regenerating: start, regenerateFailed: false));
    try {
      await _service.regenerate(start, period: state.viewedPeriod);
    } catch (_) {
      // Model unavailable or an unexpected failure (a storage write): either way
      // the period kept its previous result, so surface the retry notice.
      if (!isClosed) emit(state.copyWith(regenerateFailed: true));
    } finally {
      // Always clears, so no failure path can leave the page spinning forever.
      if (!isClosed) emit(_deriveView(state.copyWith(clearRegenerating: true)));
    }
  }

  Future<void> delete(DateTime start) async {
    await _service.deleteReflection(start, period: state.viewedPeriod);
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
