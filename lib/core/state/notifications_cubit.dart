import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';

// The collaborators are private (a cubit owns them) and named parameters cannot
// be private, so initializing formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// What the notifications screen renders: whether the weekly reflection nudge is
/// on, the fire time, the OS permission (so a denied grant can be surfaced with
/// a deep-link to Settings rather than a toggle that silently does nothing), and
/// whether reflections can produce anything at all - the nudge is pointless when
/// reflections are switched off or the on-device model is unavailable, exactly
/// the cases the [ReflectionNotifier] cancels for.
@immutable
final class NotificationsState {
  const NotificationsState({
    this.weeklyEnabled = false,
    this.hour = NotificationSettings.defaultHour,
    this.minute = NotificationSettings.defaultMinute,
    this.permission = NotificationPermission.notDetermined,
    this.reflectionsEnabled = true,
    this.reflectionsAvailable = true,
  });

  final bool weeklyEnabled;
  final int hour;
  final int minute;
  final NotificationPermission permission;

  /// Whether the user has reflections switched on. Optimistically true until the
  /// first [NotificationsCubit.load], so the card never flashes blocked.
  final bool reflectionsEnabled;

  /// Whether the on-device model can generate a reflection at all. Optimistically
  /// true until probed, for the same reason.
  final bool reflectionsAvailable;

  /// Whether a weekly nudge could ever fire: reflections are on AND the device
  /// can produce one. When false the toggle is inert and the surface explains
  /// why instead of offering a switch that does nothing.
  bool get nudgeUsable => reflectionsEnabled && reflectionsAvailable;

  /// The user wants the nudge but iOS notifications are off: the toggle stays on
  /// (honest to the stored intent) and the surface shows the needs-permission
  /// affordance, because the OS will fire nothing until permission is restored.
  /// Only meaningful while [nudgeUsable]; a reflections block takes precedence.
  bool get permissionBlocked => weeklyEnabled && permission == NotificationPermission.denied;

  NotificationsState copyWith({
    bool? weeklyEnabled,
    int? hour,
    int? minute,
    NotificationPermission? permission,
    bool? reflectionsEnabled,
    bool? reflectionsAvailable,
  }) => NotificationsState(
    weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    permission: permission ?? this.permission,
    reflectionsEnabled: reflectionsEnabled ?? this.reflectionsEnabled,
    reflectionsAvailable: reflectionsAvailable ?? this.reflectionsAvailable,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationsState &&
      other.weeklyEnabled == weeklyEnabled &&
      other.hour == hour &&
      other.minute == minute &&
      other.permission == permission &&
      other.reflectionsEnabled == reflectionsEnabled &&
      other.reflectionsAvailable == reflectionsAvailable;

  @override
  int get hashCode => Object.hash(
    weeklyEnabled,
    hour,
    minute,
    permission,
    reflectionsEnabled,
    reflectionsAvailable,
  );
}

/// Drives the notifications screen. Turning the weekly nudge on requests
/// notification permission contextually (never in onboarding). The toggle stores
/// the user's INTENT: a denied grant leaves it on but surfaces the block (the
/// notifier cancels the OS notification meanwhile), so permission can be restored
/// in Settings without re-toggling. Every change re-runs [ReflectionNotifier.sync]
/// so the OS's pending notification tracks the settings at once, not on the next
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
       super(const NotificationsState()) {
    unawaited(load());
  }

  final NotificationScheduler _scheduler;
  final NotificationSettings _settings;
  final ReflectionNotifier _notifier;
  final ReflectionSettings _reflectionSettings;
  final Future<ReflectionAvailability> Function() _availability;

  static const _key = ReflectionNotifier.key;

  /// Re-reads the settings and re-probes permission and reflection availability.
  /// Call on build, on resume, and on returning from the reflections screen, so
  /// a grant changed in iOS Settings or reflections switched on elsewhere is
  /// reflected without a relaunch.
  Future<void> load() async {
    final permission = await _scheduler.permissionStatus();
    final availability = await _availability();
    if (isClosed) return;
    emit(
      state.copyWith(
        weeklyEnabled: _settings.enabled(_key),
        hour: _settings.hour(_key),
        minute: _settings.minute(_key),
        permission: permission,
        reflectionsEnabled: _reflectionSettings.enabled,
        reflectionsAvailable: availability.isAvailable,
      ),
    );
  }

  Future<void> setWeeklyEnabled(bool value) async {
    if (value) {
      // Authoritative usability recheck before doing anything user-visible: the
      // toggle renders optimistically enabled for the frames before the first
      // load resolves, so a tap in that window must not fire an iOS permission
      // prompt or store an intent the notifier will only cancel. Re-read the
      // pref (sync) and re-probe availability, correct the state, and bail if a
      // nudge could not fire.
      final reflectionsEnabled = _reflectionSettings.enabled;
      final available = (await _availability()).isAvailable;
      if (isClosed) return;
      if (!reflectionsEnabled || !available) {
        emit(
          state.copyWith(reflectionsEnabled: reflectionsEnabled, reflectionsAvailable: available),
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
      await _settings.setEnabled(_key, true);
      unawaited(_notifier.sync());
      if (isClosed) return;
      emit(state.copyWith(weeklyEnabled: true, permission: permission));
      return;
    }
    await _settings.setEnabled(_key, false);
    unawaited(_notifier.sync());
    if (isClosed) return;
    emit(state.copyWith(weeklyEnabled: false));
  }

  Future<void> setTime({required int hour, required int minute}) async {
    await _settings.setTime(_key, hour: hour, minute: minute);
    // Reschedule regardless of the cubit's lifetime: the notifier is app-scoped,
    // and a persisted time change must move the pending nudge even if the screen
    // has already closed.
    unawaited(_notifier.sync());
    if (isClosed) return;
    emit(state.copyWith(hour: _settings.hour(_key), minute: _settings.minute(_key)));
  }
}
