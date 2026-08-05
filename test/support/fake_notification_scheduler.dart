import 'package:opentranscribe/core/notify/notification_scheduler.dart';

/// A recording [NotificationScheduler] for the notifier and cubit suites: it
/// captures every schedule and cancel, and answers permission from a settable
/// field, so a test drives the decision without a platform channel.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({
    this.permission = NotificationPermission.authorized,
    this.grant = true,
  });

  NotificationPermission permission;
  bool grant;

  /// Awaited inside [permissionStatus], so a test can flip a setting mid-probe
  /// to exercise the notifier's re-check-after-await path.
  Future<void> Function()? onPermissionProbe;

  final List<Map<String, Object?>> scheduled = [];
  final List<String> cancelled = [];
  int permissionRequests = 0;

  Map<String, Object?>? get lastScheduled => scheduled.isEmpty ? null : scheduled.last;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    // Model the OS settling the status once the user answers the prompt.
    permission = grant ? NotificationPermission.authorized : NotificationPermission.denied;
    return grant;
  }

  @override
  Future<NotificationPermission> permissionStatus() async {
    await onPermissionProbe?.call();
    return permission;
  }

  @override
  Future<void> scheduleDaily({
    required String id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    scheduled.add({
      'method': 'scheduleDaily',
      'id': id,
      'hour': hour,
      'minute': minute,
      'title': title,
      'body': body,
    });
  }

  @override
  Future<void> scheduleWeekly({
    required String id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    scheduled.add({
      'method': 'scheduleWeekly',
      'id': id,
      'weekday': weekday,
      'hour': hour,
      'minute': minute,
      'title': title,
      'body': body,
    });
  }

  @override
  Future<void> scheduleMonthly({
    required String id,
    required int day,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    scheduled.add({
      'method': 'scheduleMonthly',
      'id': id,
      'day': day,
      'hour': hour,
      'minute': minute,
      'title': title,
      'body': body,
    });
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
  }
}
