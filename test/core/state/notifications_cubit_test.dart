import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
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

  const weekly = ReflectionPeriod.weekly;
  final weeklyKey = ReflectionNotifier.keyFor(weekly);

  Future<
    ({
      NotificationsCubit cubit,
      FakeNotificationScheduler scheduler,
      NotificationSettings notify,
      ReflectionSettings reflect,
    })
  >
  build({
    NotificationPermission permission = NotificationPermission.authorized,
    bool grant = true,
    bool reflectionsEnabled = true,
    bool available = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final notify = NotificationSettings(storage: storage);
    final reflect = ReflectionSettings(storage: storage);
    await reflect.setEnabledFor(weekly, reflectionsEnabled);
    await reflect.setEnabledFor(ReflectionPeriod.monthly, false);
    await reflect.setEnabledFor(ReflectionPeriod.daily, false);
    availability() async => available
        ? const ReflectionAvailability.available()
        : const ReflectionAvailability.unsupported();
    final scheduler = FakeNotificationScheduler(permission: permission, grant: grant);
    final notifier = ReflectionNotifier(
      scheduler: scheduler,
      notifySettings: notify,
      reflectionSettings: reflect,
      availability: availability,
      language: () => 'en',
      clock: () => DateTime(2026, 8, 2, 10),
    );
    final cubit = NotificationsCubit(
      scheduler: scheduler,
      settings: notify,
      notifier: notifier,
      reflectionSettings: reflect,
      availability: availability,
    );
    await cubit.load();
    return (cubit: cubit, scheduler: scheduler, notify: notify, reflect: reflect);
  }

  test('the initial state reads the slots synchronously, before any load', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final notify = NotificationSettings(storage: storage);
    final reflect = ReflectionSettings(storage: storage);
    await reflect.setEnabledFor(ReflectionPeriod.monthly, false);
    await reflect.setEnabledFor(ReflectionPeriod.daily, false);
    await notify.setEnabled(ReflectionNotifier.keyFor(weekly), true);
    final scheduler = FakeNotificationScheduler();
    final cubit = NotificationsCubit(
      scheduler: scheduler,
      settings: notify,
      notifier: ReflectionNotifier(
        scheduler: scheduler,
        notifySettings: notify,
        reflectionSettings: reflect,
        availability: () async => const ReflectionAvailability.available(),
        language: () => 'en',
        clock: () => DateTime(2026, 8, 2, 10),
      ),
      reflectionSettings: reflect,
      availability: () async => const ReflectionAvailability.available(),
    );

    expect(cubit.state.shownPeriods, [weekly]);
    expect(cubit.state.slotOf(weekly).enabled, isTrue);
  });

  test('load reflects the persisted toggle, time, and permission', () async {
    final b = await build();
    await b.notify.setEnabled(weeklyKey, true);
    await b.notify.setTime(ReflectionNotifier.timeKey, hour: 7, minute: 15);
    await b.cubit.load();

    expect(b.cubit.state.slotOf(weekly).enabled, isTrue);
    expect(b.cubit.state.hour, 7);
    expect(b.cubit.state.minute, 15);
    expect(b.cubit.state.permission, NotificationPermission.authorized);
  });

  test('shown periods are the reflection-enabled ones, in enum order', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.monthly, true);
    await b.cubit.load();

    expect(b.cubit.state.shownPeriods, [ReflectionPeriod.weekly, ReflectionPeriod.monthly]);

    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();

    expect(b.cubit.state.shownPeriods, ReflectionPeriod.values);
  });

  test('enabling with permission already granted persists and turns on', () async {
    final b = await build();
    await b.cubit.setEnabled(weekly, true);

    expect(b.cubit.state.slotOf(weekly).enabled, isTrue);
    expect(b.notify.enabled(weeklyKey), isTrue);
    expect(b.scheduler.permissionRequests, 0);
  });

  test('enabling from undecided requests permission, then turns on when granted', () async {
    final b = await build(permission: NotificationPermission.notDetermined);
    await b.cubit.setEnabled(weekly, true);

    expect(b.scheduler.permissionRequests, 1);
    expect(b.cubit.state.slotOf(weekly).enabled, isTrue);
    expect(b.cubit.state.permission, NotificationPermission.authorized);
    expect(b.notify.enabled(weeklyKey), isTrue);
  });

  test('a second period enabled after the prompt settled does not re-prompt', () async {
    final b = await build(permission: NotificationPermission.notDetermined);
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();

    await b.cubit.setEnabled(weekly, true);
    await b.cubit.setEnabled(ReflectionPeriod.daily, true);

    expect(b.scheduler.permissionRequests, 1);
    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).enabled, isTrue);
  });

  test('a denied prompt keeps the intent on and surfaces the block', () async {
    final b = await build(permission: NotificationPermission.notDetermined, grant: false);
    await b.cubit.setEnabled(weekly, true);

    expect(b.cubit.state.slotOf(weekly).enabled, isTrue);
    expect(b.cubit.state.permission, NotificationPermission.denied);
    expect(b.cubit.state.permissionBlocked, isTrue);
    expect(b.notify.enabled(weeklyKey), isTrue);
  });

  test('an already-denied permission persists the intent without prompting again', () async {
    final b = await build(permission: NotificationPermission.denied);
    await b.cubit.setEnabled(weekly, true);

    expect(b.scheduler.permissionRequests, 0);
    expect(b.cubit.state.slotOf(weekly).enabled, isTrue);
    expect(b.cubit.state.permissionBlocked, isTrue);
  });

  test('an enabled nudge whose permission was revoked surfaces the block on load', () async {
    final b = await build(permission: NotificationPermission.denied);
    await b.notify.setEnabled(weeklyKey, true);
    await b.cubit.load();

    expect(b.cubit.state.slotOf(weekly).enabled, isTrue);
    expect(b.cubit.state.permissionBlocked, isTrue);
  });

  test('disabling turns off and persists', () async {
    final b = await build();
    await b.cubit.setEnabled(weekly, true);
    await b.cubit.setEnabled(weekly, false);

    expect(b.cubit.state.slotOf(weekly).enabled, isFalse);
    expect(b.notify.enabled(weeklyKey), isFalse);
    expect(b.cubit.state.permissionBlocked, isFalse);
  });

  test('disabling one period leaves the others intact', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();
    await b.cubit.setEnabled(weekly, true);
    await b.cubit.setEnabled(ReflectionPeriod.daily, true);

    await b.cubit.setEnabled(ReflectionPeriod.daily, false);

    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).enabled, isFalse);
    expect(b.cubit.state.slotOf(weekly).enabled, isTrue);
    expect(b.notify.enabled(weeklyKey), isTrue);
  });

  test('setTime persists the shared time and updates the state', () async {
    final b = await build();

    await b.cubit.setTime(hour: 21, minute: 45);

    expect(b.cubit.state.hour, 21);
    expect(b.cubit.state.minute, 45);
    expect(b.notify.hour(ReflectionNotifier.timeKey), 21);
    expect(b.notify.minute(ReflectionNotifier.timeKey), 45);
  });

  test('reflections on and available keep the rows shown and operable', () async {
    final b = await build();

    expect(b.cubit.state.shownPeriods, isNotEmpty);
    expect(b.cubit.state.reflectionsAvailable, isTrue);
  });

  test('every period switched off leaves no rows to show', () async {
    final b = await build(reflectionsEnabled: false);

    expect(b.cubit.state.shownPeriods, isEmpty);
  });

  test('an unavailable model is surfaced while the rows stay listed', () async {
    final b = await build(available: false);

    expect(b.cubit.state.reflectionsAvailable, isFalse);
    expect(b.cubit.state.shownPeriods, [weekly]);
  });

  test('enabling while that period\'s reflections are off neither prompts nor stores', () async {
    final b = await build(
      permission: NotificationPermission.notDetermined,
      reflectionsEnabled: false,
    );
    await b.cubit.setEnabled(weekly, true);

    expect(b.scheduler.permissionRequests, 0);
    expect(b.cubit.state.slotOf(weekly).enabled, isFalse);
    expect(b.notify.enabled(weeklyKey), isFalse);
  });

  test('enabling a period switched off elsewhere drops its row on the recheck', () async {
    final b = await build();
    await b.reflect.setEnabledFor(weekly, false);

    await b.cubit.setEnabled(weekly, true);

    expect(b.cubit.state.shownPeriods, isEmpty);
    expect(b.notify.enabled(weeklyKey), isFalse);
  });

  test('enabling while the model is unavailable neither prompts nor stores the intent', () async {
    final b = await build(permission: NotificationPermission.notDetermined, available: false);
    await b.cubit.setEnabled(weekly, true);

    expect(b.scheduler.permissionRequests, 0);
    expect(b.cubit.state.slotOf(weekly).enabled, isFalse);
    expect(b.notify.enabled(weeklyKey), isFalse);
  });

  test('no enabled nudge means a denied permission is not a block', () async {
    final b = await build(permission: NotificationPermission.denied);

    expect(b.cubit.state.permissionBlocked, isFalse);
  });
}
