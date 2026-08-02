import 'package:flutter/services.dart';

// Channel identifier. Must match Notifications.swift.
const _channel = 'opentranscribe/notify';

/// Whether the OS lets the app post local notifications. The provisional and
/// ephemeral grants collapse into [authorized]: both can post, and nothing here
/// treats them differently. [notDetermined] is the pre-prompt state.
enum NotificationPermission { notDetermined, denied, authorized }

/// Schedules and cancels LOCAL, on-device notifications. Generic on purpose: it
/// names no feature, so any future weekly nudge reuses it unchanged. Nothing
/// here reaches the network - UNUserNotificationCenter fires on the device, so
/// airplane mode is unaffected.
abstract interface class NotificationScheduler {
  /// Asks the OS for permission, prompting once when undetermined, and returns
  /// whether posting is now allowed. Safe once already decided: it returns the
  /// standing answer without a second prompt.
  Future<bool> requestPermission();

  /// The current authorization, without prompting.
  Future<NotificationPermission> permissionStatus();

  /// (Re)schedules a repeating weekly notification under [id]. A later call with
  /// the same [id] REPLACES the pending one, so a changed time or weekday never
  /// stacks a second notification. [weekday] is 1=Mon..7=Sun (the DateTime
  /// convention); the native side maps it to the platform's numbering.
  Future<void> scheduleWeekly({
    required String id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  });

  /// Cancels the pending notification under [id]. A no-op if none is scheduled.
  Future<void> cancel(String id);
}

/// The [NotificationScheduler] over a MethodChannel to the native plugin.
/// Preflight-safe: a missing plugin (a non-iOS host, a test harness) never
/// throws - permission reads as [NotificationPermission.notDetermined] and
/// scheduling is a silent no-op, so a caller wires this in everywhere without
/// guarding.
class PlatformNotificationScheduler implements NotificationScheduler {
  PlatformNotificationScheduler({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel(_channel);

  final MethodChannel _methods;

  @override
  Future<bool> requestPermission() async {
    try {
      return await _methods.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<NotificationPermission> permissionStatus() async {
    try {
      return _permissionFrom(await _methods.invokeMethod<String>('authorizationStatus'));
    } on PlatformException {
      return NotificationPermission.notDetermined;
    } on MissingPluginException {
      return NotificationPermission.notDetermined;
    }
  }

  @override
  Future<void> scheduleWeekly({
    required String id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) => _quietInvoke('scheduleWeekly', {
    'identifier': id,
    'weekday': weekday,
    'hour': hour,
    'minute': minute,
    'title': title,
    'body': body,
  });

  @override
  Future<void> cancel(String id) => _quietInvoke('cancel', {'identifier': id});

  /// A fire-and-forget write: the nudge is a bonus, so a failed schedule or
  /// cancel is swallowed rather than surfaced, and the next sync retries.
  Future<void> _quietInvoke(String method, Map<String, Object?> args) async {
    try {
      await _methods.invokeMethod<void>(method, args);
    } on PlatformException {
      // Nothing to surface.
    } on MissingPluginException {
      // No native side; nothing to do.
    }
  }

  NotificationPermission _permissionFrom(String? status) => switch (status) {
    'authorized' => NotificationPermission.authorized,
    'provisional' => NotificationPermission.authorized,
    'ephemeral' => NotificationPermission.authorized,
    'denied' => NotificationPermission.denied,
    _ => NotificationPermission.notDetermined,
  };
}
