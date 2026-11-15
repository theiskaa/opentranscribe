import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:reflections/reflections.dart';

// The collaborators are private (a cubit owns them) and named parameters cannot
// be private, so initializing formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// One period's tile on the notifications screen: whether that period's
/// reflections generate at all (the tile exists only when true, because a
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
  /// tiles under it pick WHICH reflections nudge and keep their mix while it
  /// is off.
  final bool master;

  final Map<ReflectionPeriod, NotificationSlot> slots;
  final int hour;
  final int minute;
  final NotificationPermission permission;

  /// Whether the on-device model can generate a reflection at all. The last
  /// probe's answer until this one lands, and optimistically true before any,
  /// so the surface never flashes blocked.
  final bool reflectionsAvailable;

  NotificationSlot slotOf(ReflectionPeriod period) => slots[period] ?? const NotificationSlot();

  /// The tiles the screen renders, in enum order (daily, weekly, monthly).
  List<ReflectionPeriod> get shownPeriods =>
      ReflectionPeriod.values.where((p) => slotOf(p).reflectionEnabled).toList();

  bool get anySelected =>
      ReflectionPeriod.values.map(slotOf).any((slot) => slot.reflectionEnabled && slot.selected);

  /// The periods that will actually nudge: none unless the switch is on, the
  /// model can reflect and iOS lets the app notify, as the notifier requires.
  List<ReflectionPeriod> get nudgingPeriods =>
      master && reflectionsAvailable && permission == NotificationPermission.authorized
      ? shownPeriods.where((period) => slotOf(period).selected).toList()
      : const [];

  /// Where a turn-on lands before any of its checks answer: the master on and,
  /// when no shown period is picked yet, every shown one picked, the seed
  /// [ReflectionNotifier.enable] stores.
  NotificationsState get armed => copyWith(
    master: true,
    slots: anySelected
        ? slots
        : {
            for (final MapEntry(key: period, value: slot) in slots.entries)
              period: NotificationSlot(
                reflectionEnabled: slot.reflectionEnabled,
                selected: slot.selected || slot.reflectionEnabled,
              ),
          },
  );

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
/// notification permission contextually (onboarding asks once too, on phones
/// that can reflect). The switch and the tiles store the user's INTENT: a
/// denied grant leaves them on but surfaces the block (the notifier cancels
/// the OS notification meanwhile), so permission can be restored in Settings
/// without re-toggling. Every change re-runs [ReflectionNotifier.sync] so the
/// OS's pending notifications track the settings at once, not on the next
/// launch.
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
       // The probes open on their last answers, so the first frame is the
       // loaded one and the load only moves what truly changed since.
       super(
         NotificationsState(
           master: ReflectionNotifier.masterEnabled(settings),
           slots: _readSlots(settings, reflectionSettings),
           hour: settings.hour(ReflectionNotifier.timeKey),
           minute: settings.minute(ReflectionNotifier.timeKey),
           permission: settings.lastPermission ?? NotificationPermission.notDetermined,
           reflectionsAvailable: reflectionSettings.lastAvailable ?? true,
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

  /// Bumped by every turn of the master, so a turn that a newer one overtook
  /// while it awaited stops before it writes or emits.
  int _masterTurn = 0;

  /// The answer a turn in flight gave the switch, until its writes land.
  bool? _pendingMaster;

  /// The switch's and the tiles' writes, run one after the other in tap
  /// order, so racing taps land on what the screen showed last.
  Future<void> _writes = Future<void>.value();

  Future<void> _chain(Future<void> Function() write) {
    final next = _writes.then((_) => write());
    _writes = next.catchError((Object _) {});
    return next;
  }

  /// Re-reads the settings and re-probes permission and reflection availability.
  /// Call on build, on resume, and on returning from the reflections screen, so
  /// a grant changed in iOS Settings or a period switched on elsewhere is
  /// reflected without a relaunch.
  Future<void> load() async {
    final NotificationPermission permission;
    final bool available;
    try {
      permission = await _scheduler.permissionStatus();
      available = (await _availability()).isAvailable;
    } catch (e) {
      // The surface stays as it was; the next load probes again.
      if (kDebugMode) debugPrint('notifications load failed: $e');
      return;
    }
    unawaited(_settings.rememberPermission(permission));
    unawaited(_reflectionSettings.rememberAvailable(available));
    _emitStored(permission: permission, reflectionsAvailable: available);
  }

  /// Flips the reminders master switch. Turning it on stores the intent
  /// through [ReflectionNotifier.enable], which seeds every shown period when
  /// nothing was selected yet.
  ///
  /// The switch answers before any await, so the knob, a tap on its row and
  /// everything the switch opens move on the tap's own frame; a check that
  /// then refuses, or a write that fails, lands it back on what is stored.
  Future<void> setMaster(bool value) async {
    final turn = ++_masterTurn;
    _pendingMaster = value;
    try {
      if (value) {
        await _turnOn(turn);
      } else {
        await _turnOff();
      }
    } catch (e) {
      // Fired unawaited from the switch, so the finally's landing is the
      // whole handling.
      if (kDebugMode) debugPrint('notifications master turn failed: $e');
    } finally {
      // Whatever ended the turn, a probe that threw included, it lands on
      // storage rather than leaving its answer standing.
      if (turn == _masterTurn && _pendingMaster != null) {
        _pendingMaster = null;
        await _landStored(turn);
      }
    }
  }

  Future<void> _turnOff() async {
    emit(state.copyWith(master: false));
    // A failed write needs no more handling: landing on storage turns the
    // switch back on.
    try {
      await _chain(() => _settings.setEnabled(ReflectionNotifier.timeKey, false));
    } catch (e) {
      if (kDebugMode) debugPrint('notifications master off write failed: $e');
    }
    // Even when overtaken: a newer turn-on that is then refused never syncs.
    unawaited(_notifier.sync());
  }

  Future<void> _turnOn(int turn) async {
    emit(state.armed);
    // Authoritative usability recheck before doing anything lasting: the
    // model may have become unavailable since this screen was built, and a tap
    // then must not fire an iOS permission prompt or store an intent the
    // notifier will only cancel.
    final available = (await _availability()).isAvailable;
    unawaited(_reflectionSettings.rememberAvailable(available));
    if (isClosed || turn != _masterTurn) return;
    final anyPeriod = ReflectionPeriod.values.any(_reflectionSettings.enabledFor);
    if (!available || !anyPeriod) {
      _pendingMaster = null;
      await _landStored(turn, reflectionsAvailable: available);
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
    unawaited(_settings.rememberPermission(permission));
    if (turn != _masterTurn) return;
    // A failed write lands on storage below; the chain re-checks the turn,
    // since a tap may overtake it while earlier writes drain.
    try {
      await _chain(() async {
        if (turn == _masterTurn) await _notifier.enable();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('notifications master on write failed: $e');
    }
    // A tile tapped meanwhile chained its writes behind; land after them.
    await _writes;
    if (turn != _masterTurn) return;
    _pendingMaster = null;
    _emitStored(permission: permission);
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
      final bool available;
      try {
        available = (await _availability()).isAvailable;
      } catch (e) {
        if (kDebugMode) debugPrint('notifications select probe failed: $e');
        _emitStored();
        return;
      }
      unawaited(_reflectionSettings.rememberAvailable(available));
      if (!reflectionEnabled || !available) {
        _emitStored(reflectionsAvailable: available);
        return;
      }
    }
    // Mid-arming the tiles show a seed not yet stored, so the tap applies to
    // what was seen and the whole of it is written, not the one tile alone.
    final seen = _pendingMaster == true
        ? {
            ...state.slots,
            period: NotificationSlot(
              reflectionEnabled: _reflectionSettings.enabledFor(period),
              selected: value,
            ),
          }
        : null;
    final anyLeft = seen != null
        ? seen.values.any((slot) => slot.reflectionEnabled && slot.selected)
        : value ||
              ReflectionPeriod.values.any(
                (p) =>
                    p != period &&
                    _reflectionSettings.enabledFor(p) &&
                    _settings.enabled(ReflectionNotifier.keyFor(p)),
              );
    if (!anyLeft) {
      // Turning the master off is a turn of it: an arming in flight must not
      // re-seed the tile just deselected.
      ++_masterTurn;
      _pendingMaster = null;
    }
    final turn = _masterTurn;
    if (seen != null && anyLeft) {
      if (isClosed) return;
      emit(state.copyWith(slots: seen));
    }
    try {
      await _chain(() async {
        if (seen != null && anyLeft) {
          // Periods stored under an unset master read as on through its
          // fallback; pin it off until the arming turn stores its own answer.
          if (_settings.enabledOrNull(ReflectionNotifier.timeKey) == null) {
            await _settings.setEnabled(ReflectionNotifier.timeKey, false);
          }
          for (final MapEntry(key: p, value: slot) in seen.entries) {
            if (slot.reflectionEnabled) {
              await _settings.setEnabled(ReflectionNotifier.keyFor(p), slot.selected);
            }
          }
          return;
        }
        await _settings.setEnabled(ReflectionNotifier.keyFor(period), value);
        if (!anyLeft) await _settings.setEnabled(ReflectionNotifier.timeKey, false);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('notifications select write failed: $e');
    } finally {
      unawaited(_notifier.sync());
      // A turn of the master since owns what the screen shows now.
      if (turn == _masterTurn) _emitStored();
    }
  }

  Future<void> setTime({required int hour, required int minute}) async {
    try {
      await _chain(() => _settings.setTime(ReflectionNotifier.timeKey, hour: hour, minute: minute));
    } catch (e) {
      if (kDebugMode) debugPrint('notifications time write failed: $e');
    } finally {
      // Reschedule regardless of the cubit's lifetime: the notifier is
      // app-scoped, and a persisted time change must move the pending nudges
      // even if the screen has already closed.
      unawaited(_notifier.sync());
      _emitStored();
    }
  }

  /// [_emitStored] once the queued writes land, so a turn ending while a tile
  /// tap still drains shows the tap, unless a newer turn took over meanwhile.
  Future<void> _landStored(int turn, {bool? reflectionsAvailable}) async {
    await _writes;
    if (turn == _masterTurn) _emitStored(reflectionsAvailable: reflectionsAvailable);
  }

  /// The one emit of what storage holds, every stored field re-read, with
  /// the probes' answers where a caller has them. While a turn of the master
  /// is in flight its answer stands in for the switch and the tiles, so a
  /// load landing mid-turn (the permission alert resumes the app) cannot
  /// flick them back.
  void _emitStored({NotificationPermission? permission, bool? reflectionsAvailable}) {
    if (isClosed) return;
    final pending = _pendingMaster;
    emit(
      state.copyWith(
        master: pending ?? ReflectionNotifier.masterEnabled(_settings),
        slots: pending == null ? _readSlots(_settings, _reflectionSettings) : state.slots,
        hour: _settings.hour(ReflectionNotifier.timeKey),
        minute: _settings.minute(ReflectionNotifier.timeKey),
        permission: permission,
        reflectionsAvailable: reflectionsAvailable,
      ),
    );
  }
}
