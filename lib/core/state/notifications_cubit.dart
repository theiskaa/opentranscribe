import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';

// The collaborators are private (a cubit owns them) and named parameters cannot
// be private, so initializing formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// What the notifications screen renders: whether the weekly reflection nudge is
/// on, the fire time, and the OS permission (so a denied grant can be surfaced
/// with a deep-link to Settings rather than a toggle that silently does
/// nothing).
@immutable
final class NotificationsState {
  const NotificationsState({
    this.weeklyEnabled = false,
    this.hour = NotificationSettings.defaultHour,
    this.minute = NotificationSettings.defaultMinute,
    this.permission = NotificationPermission.notDetermined,
  });

  final bool weeklyEnabled;
  final int hour;
  final int minute;
  final NotificationPermission permission;

  /// The user wants the nudge but iOS notifications are off: the toggle stays on
  /// (honest to the stored intent) and the surface shows the needs-permission
  /// affordance, because the OS will fire nothing until permission is restored.
  bool get permissionBlocked => weeklyEnabled && permission == NotificationPermission.denied;

  NotificationsState copyWith({
    bool? weeklyEnabled,
    int? hour,
    int? minute,
    NotificationPermission? permission,
  }) => NotificationsState(
    weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    permission: permission ?? this.permission,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationsState &&
      other.weeklyEnabled == weeklyEnabled &&
      other.hour == hour &&
      other.minute == minute &&
      other.permission == permission;

  @override
  int get hashCode => Object.hash(weeklyEnabled, hour, minute, permission);
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
  }) : _scheduler = scheduler,
       _settings = settings,
       _notifier = notifier,
       super(const NotificationsState()) {
    unawaited(load());
  }

  final NotificationScheduler _scheduler;
  final NotificationSettings _settings;
  final ReflectionNotifier _notifier;

  static const _key = ReflectionNotifier.key;

  /// Re-reads the settings and re-probes permission. Call on build and on
  /// resume, so a grant the user changed in iOS Settings is reflected without a
  /// relaunch.
  Future<void> load() async {
    final permission = await _scheduler.permissionStatus();
    if (isClosed) return;
    emit(
      state.copyWith(
        weeklyEnabled: _settings.enabled(_key),
        hour: _settings.hour(_key),
        minute: _settings.minute(_key),
        permission: permission,
      ),
    );
  }

  Future<void> setWeeklyEnabled(bool value) async {
    if (value) {
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
