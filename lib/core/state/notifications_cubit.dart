import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';

// The collaborators are private (a cubit owns them) and named parameters cannot
// be private, so initializing formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// One period's chip on the notifications screen: whether that period's
/// reflections generate at all (the chip exists only when true, because a
/// nudge for a period that never produces is noise) and whether it is selected
/// under the reminders master switch (see [ReflectionNotifier.selectedFor]:
/// a lone shown period always is).
@immutable
final class NotificationSlot {
  const NotificationSlot({this.reflectionEnabled = false, this.selected = false});

  final bool reflectionEnabled;
  final bool selected;

  @override
  bool operator ==(Object other) =>
      other is NotificationSlot &&
      other.reflectionEnabled == reflectionEnabled &&
      other.selected == selected;

  @override
  int get hashCode => Object.hash(reflectionEnabled, selected);
}

/// What the notifications screen renders: the reminders master switch, a slot
/// per reflection period, the one fire time they all share, the OS permission
/// (so a denied grant can be surfaced with a deep-link to Settings rather than
/// a switch that silently does nothing), and whether the on-device model can
/// produce anything at all - the nudges are pointless when it cannot, exactly
/// the case the [ReflectionNotifier] cancels for.
@immutable
final class NotificationsState {
  const NotificationsState({
    this.master = false,
    this.slots = const {},
    this.hour = NotificationSettings.defaultHour,
    this.minute = NotificationSettings.defaultMinute,
    this.permission = NotificationPermission.notDetermined,
    this.reflectionsAvailable = true,
  });

  /// The one switch that turns reflection reminders on or off; the period
  /// capsules under it pick WHICH reflections nudge and keep their mix while
  /// it is off.
  final bool master;

  final Map<ReflectionPeriod, NotificationSlot> slots;
  final int hour;
  final int minute;
  final NotificationPermission permission;

  /// Whether the on-device model can generate a reflection at all.
  /// Optimistically true until probed, so the surface never flashes blocked.
  final bool reflectionsAvailable;

  NotificationSlot slotOf(ReflectionPeriod period) => slots[period] ?? const NotificationSlot();

  /// The chips the screen renders, in enum order (daily, weekly, monthly).
  List<ReflectionPeriod> get shownPeriods =>
      ReflectionPeriod.values.where((p) => slotOf(p).reflectionEnabled).toList();

  bool get anySelected =>
      ReflectionPeriod.values.map(slotOf).any((slot) => slot.reflectionEnabled && slot.selected);

  /// The user wants a nudge but iOS notifications are off: the switch stays on
  /// (honest to the stored intent) and the surface shows the needs-permission
  /// affordance, because the OS will fire nothing until permission is restored.
  bool get permissionBlocked =>
      master && anySelected && permission == NotificationPermission.denied;

  NotificationsState copyWith({
    bool? master,
    Map<ReflectionPeriod, NotificationSlot>? slots,
    int? hour,
    int? minute,
    NotificationPermission? permission,
    bool? reflectionsAvailable,
  }) => NotificationsState(
    master: master ?? this.master,
    slots: slots ?? this.slots,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    permission: permission ?? this.permission,
    reflectionsAvailable: reflectionsAvailable ?? this.reflectionsAvailable,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationsState &&
      other.master == master &&
      mapEquals(other.slots, slots) &&
      other.hour == hour &&
      other.minute == minute &&
      other.permission == permission &&
      other.reflectionsAvailable == reflectionsAvailable;

  @override
  int get hashCode => Object.hash(
    master,
    // MapEntry hashes by identity and entries are minted fresh per call, so
    // hash the pairs' contents to stay consistent with mapEquals.
    Object.hashAllUnordered(slots.entries.map((e) => Object.hash(e.key, e.value))),
    hour,
    minute,
    permission,
    reflectionsAvailable,
  );
}

/// Drives the notifications screen. Turning the master switch on requests
/// notification permission contextually (never in onboarding). The switch and
/// the capsules store the user's INTENT: a denied grant leaves them on but
/// surfaces the block (the notifier cancels the OS notification meanwhile), so
/// permission can be restored in Settings without re-toggling. Every change
/// re-runs [ReflectionNotifier.sync] so the OS's pending notifications track
/// the settings at once, not on the next launch.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required NotificationScheduler scheduler,
    required NotificationSettings settings,
    required ReflectionNotifier notifier,
    required ReflectionSettings reflectionSettings,
    required Future<ReflectionAvailability> Function() availability,
  }) : _scheduler = scheduler,
       _settings = settings,
       _notifier = notifier,
       _reflectionSettings = reflectionSettings,
       _availability = availability,
       // Both settings holders read synchronously, so the surface is right from
       // the first frame; only permission and availability need the async load.
       super(
         NotificationsState(
           master: ReflectionNotifier.masterEnabled(settings),
           slots: _readSlots(settings, reflectionSettings),
           hour: settings.hour(ReflectionNotifier.timeKey),
           minute: settings.minute(ReflectionNotifier.timeKey),
         ),
       ) {
    unawaited(load());
  }

  final NotificationScheduler _scheduler;
  final NotificationSettings _settings;
  final ReflectionNotifier _notifier;
  final ReflectionSettings _reflectionSettings;
  final Future<ReflectionAvailability> Function() _availability;

  static Map<ReflectionPeriod, NotificationSlot> _readSlots(
    NotificationSettings settings,
    ReflectionSettings reflectionSettings,
  ) => {
    for (final period in ReflectionPeriod.values)
      period: NotificationSlot(
        reflectionEnabled: reflectionSettings.enabledFor(period),
        selected: ReflectionNotifier.selectedFor(period, settings, reflectionSettings),
      ),
  };

  /// Re-reads the settings and re-probes permission and reflection availability.
  /// Call on build, on resume, and on returning from the reflections screen, so
  /// a grant changed in iOS Settings or a period switched on elsewhere is
  /// reflected without a relaunch.
  Future<void> load() async {
    final permission = await _scheduler.permissionStatus();
    final availability = await _availability();
    if (isClosed) return;
    emit(
      state.copyWith(
        master: ReflectionNotifier.masterEnabled(_settings),
        slots: _readSlots(_settings, _reflectionSettings),
        hour: _settings.hour(ReflectionNotifier.timeKey),
        minute: _settings.minute(ReflectionNotifier.timeKey),
        permission: permission,
        reflectionsAvailable: availability.isAvailable,
      ),
    );
  }

  /// Flips the reminders master switch. Turning it on with nothing selected
  /// seeds every shown period, so the first flip delivers full value in one
  /// gesture; a mix picked later survives off-and-on untouched.
  Future<void> setMaster(bool value) async {
    if (!value) {
      await _settings.setEnabled(ReflectionNotifier.timeKey, false);
      unawaited(_notifier.sync());
      if (isClosed) return;
      emit(state.copyWith(master: false));
      return;
    }
    // Authoritative usability recheck before doing anything user-visible: the
    // model may have become unavailable since this screen was built, and a tap
    // then must not fire an iOS permission prompt or store an intent the
    // notifier will only cancel.
    final available = (await _availability()).isAvailable;
    if (isClosed) return;
    final anyPeriod = ReflectionPeriod.values.any(_reflectionSettings.enabledFor);
    if (!available || !anyPeriod) {
      emit(
        state.copyWith(
          slots: _readSlots(_settings, _reflectionSettings),
          reflectionsAvailable: available,
        ),
      );
      return;
    }
    // Ask for permission if it was never decided; a denial does not stop
    // storing the intent, only the OS from firing (the notifier cancels), and
    // the screen surfaces the block so the user can fix it in Settings.
    var permission = await _scheduler.permissionStatus();
    if (permission == NotificationPermission.notDetermined) {
      await _scheduler.requestPermission();
      permission = await _scheduler.permissionStatus();
    }
    await _settings.setEnabled(ReflectionNotifier.timeKey, true);
    // Against the stored truth, not the state snapshot: a selection changed
    // elsewhere since this screen was built must not be seeded over.
    final anyStored = ReflectionPeriod.values.any(
      (p) => _reflectionSettings.enabledFor(p) && _settings.enabled(ReflectionNotifier.keyFor(p)),
    );
    if (!anyStored) {
      for (final period in ReflectionPeriod.values) {
        if (_reflectionSettings.enabledFor(period)) {
          await _settings.setEnabled(ReflectionNotifier.keyFor(period), true);
        }
      }
    }
    unawaited(_notifier.sync());
    if (isClosed) return;
    emit(
      state.copyWith(
        master: true,
        slots: _readSlots(_settings, _reflectionSettings),
        permission: permission,
      ),
    );
  }

  /// Selects or deselects one period's nudge under the master switch.
  /// Deselecting the last one turns the master itself off: reminders with
  /// nothing to remind about are not a state worth keeping open.
  Future<void> setSelected(ReflectionPeriod period, bool value) async {
    if (value) {
      // The same usability recheck as the master's: the period's reflections
      // may have been switched off elsewhere since this screen was built, and
      // a tap then must not store an intent the notifier will only cancel. No
      // permission prompt here; turning the master on already settled it.
      final reflectionEnabled = _reflectionSettings.enabledFor(period);
      final available = (await _availability()).isAvailable;
      if (isClosed) return;
      if (!reflectionEnabled || !available) {
        emit(
          state.copyWith(
            slots: _readSlots(_settings, _reflectionSettings),
            reflectionsAvailable: available,
          ),
        );
        return;
      }
    }
    await _settings.setEnabled(ReflectionNotifier.keyFor(period), value);
    if (!value) {
      final anyLeft = ReflectionPeriod.values.any(
        (p) => _reflectionSettings.enabledFor(p) && _settings.enabled(ReflectionNotifier.keyFor(p)),
      );
      if (!anyLeft) await _settings.setEnabled(ReflectionNotifier.timeKey, false);
    }
    unawaited(_notifier.sync());
    if (isClosed) return;
    emit(
      state.copyWith(
        master: ReflectionNotifier.masterEnabled(_settings),
        slots: _readSlots(_settings, _reflectionSettings),
      ),
    );
  }

  Future<void> setTime({required int hour, required int minute}) async {
    await _settings.setTime(ReflectionNotifier.timeKey, hour: hour, minute: minute);
    // Reschedule regardless of the cubit's lifetime: the notifier is app-scoped,
    // and a persisted time change must move the pending nudges even if the
    // screen has already closed.
    unawaited(_notifier.sync());
    if (isClosed) return;
    emit(
      state.copyWith(
        hour: _settings.hour(ReflectionNotifier.timeKey),
        minute: _settings.minute(ReflectionNotifier.timeKey),
      ),
    );
  }
}
