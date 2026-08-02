import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/state/notifications_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting();
  });

  const key = ReflectionNotifier.key;

  Future<
    ({NotificationsCubit cubit, FakeNotificationScheduler scheduler, NotificationSettings notify})
  >
  build({
    NotificationPermission permission = NotificationPermission.authorized,
    bool grant = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    final notify = NotificationSettings(storage: storage);
    final reflect = ReflectionSettings(storage: storage);
    final scheduler = FakeNotificationScheduler(permission: permission, grant: grant);
    final notifier = ReflectionNotifier(
      scheduler: scheduler,
      notifySettings: notify,
      reflectionSettings: reflect,
      availability: () async => const ReflectionAvailability.available(),
      language: () => 'en',
      clock: () => DateTime(2026, 8, 2, 10),
    );
    final cubit = NotificationsCubit(scheduler: scheduler, settings: notify, notifier: notifier);
    await cubit.load();
    return (cubit: cubit, scheduler: scheduler, notify: notify);
  }

  test('load reflects the persisted toggle, time, and permission', () async {
    final b = await build();
    await b.notify.setEnabled(key, true);
    await b.notify.setTime(key, hour: 7, minute: 15);
    await b.cubit.load();

    expect(b.cubit.state.weeklyEnabled, isTrue);
    expect(b.cubit.state.hour, 7);
    expect(b.cubit.state.minute, 15);
    expect(b.cubit.state.permission, NotificationPermission.authorized);
  });

  test('enabling with permission already granted persists and turns on', () async {
    final b = await build();
    await b.cubit.setWeeklyEnabled(true);

    expect(b.cubit.state.weeklyEnabled, isTrue);
    expect(b.notify.enabled(key), isTrue);
    expect(b.scheduler.permissionRequests, 0);
  });

  test('enabling from undecided requests permission, then turns on when granted', () async {
    final b = await build(permission: NotificationPermission.notDetermined);
    await b.cubit.setWeeklyEnabled(true);

    expect(b.scheduler.permissionRequests, 1);
    expect(b.cubit.state.weeklyEnabled, isTrue);
    expect(b.cubit.state.permission, NotificationPermission.authorized);
    expect(b.notify.enabled(key), isTrue);
  });

  test('a denied prompt keeps the intent on and surfaces the block', () async {
    final b = await build(permission: NotificationPermission.notDetermined, grant: false);
    await b.cubit.setWeeklyEnabled(true);

    expect(b.cubit.state.weeklyEnabled, isTrue);
    expect(b.cubit.state.permission, NotificationPermission.denied);
    expect(b.cubit.state.permissionBlocked, isTrue);
    expect(b.notify.enabled(key), isTrue);
  });

  test('an already-denied permission persists the intent without prompting again', () async {
    final b = await build(permission: NotificationPermission.denied);
    await b.cubit.setWeeklyEnabled(true);

    expect(b.scheduler.permissionRequests, 0);
    expect(b.cubit.state.weeklyEnabled, isTrue);
    expect(b.cubit.state.permissionBlocked, isTrue);
  });

  test('an enabled nudge whose permission was revoked surfaces the block on load', () async {
    final b = await build(permission: NotificationPermission.denied);
    await b.notify.setEnabled(key, true);
    await b.cubit.load();

    expect(b.cubit.state.weeklyEnabled, isTrue);
    expect(b.cubit.state.permissionBlocked, isTrue);
  });

  test('disabling turns off and persists', () async {
    final b = await build();
    await b.cubit.setWeeklyEnabled(true);
    await b.cubit.setWeeklyEnabled(false);

    expect(b.cubit.state.weeklyEnabled, isFalse);
    expect(b.notify.enabled(key), isFalse);
    expect(b.cubit.state.permissionBlocked, isFalse);
  });

  test('setTime persists and updates the state', () async {
    final b = await build();
    await b.cubit.setTime(hour: 21, minute: 45);

    expect(b.cubit.state.hour, 21);
    expect(b.cubit.state.minute, 45);
    expect(b.notify.hour(key), 21);
    expect(b.notify.minute(key), 45);
  });
}
