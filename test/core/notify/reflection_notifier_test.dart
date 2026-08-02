import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting();
  });

  final clock = DateTime(2026, 8, 2, 10);

  Future<({NotificationSettings notify, ReflectionSettings reflect})> settings() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    return (
      notify: NotificationSettings(storage: storage),
      reflect: ReflectionSettings(storage: storage),
    );
  }

  Future<ReflectionNotifier> build({
    required FakeNotificationScheduler scheduler,
    required NotificationSettings notify,
    required ReflectionSettings reflect,
    ReflectionAvailability availability = const ReflectionAvailability.available(),
    String language = 'en',
  }) async {
    return ReflectionNotifier(
      scheduler: scheduler,
      notifySettings: notify,
      reflectionSettings: reflect,
      availability: () async => availability,
      language: () => language,
      clock: () => clock,
    );
  }

  group('scheduling', () {
    test('schedules the weekly nudge when everything lines up', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.key, true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.cancelled, isEmpty);
      expect(scheduler.lastScheduled!['id'], 'reflect.weekly');
    });

    test('the weekday is the app-language week boundary', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.key, true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.lastScheduled!['weekday'], startOfWeek(clock, localeId: 'en').weekday);
    });

    test('the hour and minute follow the notification settings', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.key, true);
      await s.notify.setTime(ReflectionNotifier.key, hour: 7, minute: 15);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.lastScheduled!['hour'], 7);
      expect(scheduler.lastScheduled!['minute'], 15);
    });

    test('the title and body are the generic app-language strings', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.key, true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(scheduler.lastScheduled!['title'], l10n.notifyWeeklyTitle);
      expect(scheduler.lastScheduled!['body'], l10n.notifyWeeklyBody);
    });

    test('a changed time reschedules under the same identifier', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.key, true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();
      await s.notify.setTime(ReflectionNotifier.key, hour: 21, minute: 0);
      await notifier.sync();

      expect(scheduler.scheduled.map((s) => s['id']), everyElement('reflect.weekly'));
      expect(scheduler.lastScheduled!['hour'], 21);
    });
  });

  group('cancelling', () {
    Future<FakeNotificationScheduler> syncWith({
      bool weeklyOn = true,
      bool reflectionsOn = true,
      NotificationPermission permission = NotificationPermission.authorized,
      ReflectionAvailability availability = const ReflectionAvailability.available(),
    }) async {
      final scheduler = FakeNotificationScheduler(permission: permission);
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.key, weeklyOn);
      await s.reflect.setEnabled(reflectionsOn);
      final notifier = await build(
        scheduler: scheduler,
        notify: s.notify,
        reflect: s.reflect,
        availability: availability,
      );
      await notifier.sync();
      return scheduler;
    }

    test('cancels when the weekly toggle is off', () async {
      final scheduler = await syncWith(weeklyOn: false);
      expect(scheduler.cancelled, ['reflect.weekly']);
      expect(scheduler.scheduled, isEmpty);
    });

    test('cancels when reflections are disabled', () async {
      final scheduler = await syncWith(reflectionsOn: false);
      expect(scheduler.cancelled, ['reflect.weekly']);
      expect(scheduler.scheduled, isEmpty);
    });

    test('cancels when notification permission is not granted', () async {
      final scheduler = await syncWith(permission: NotificationPermission.denied);
      expect(scheduler.cancelled, ['reflect.weekly']);
      expect(scheduler.scheduled, isEmpty);
    });

    test('cancels when the on-device model cannot run', () async {
      final scheduler = await syncWith(availability: const ReflectionAvailability.unsupported());
      expect(scheduler.cancelled, ['reflect.weekly']);
      expect(scheduler.scheduled, isEmpty);
    });

    test('a not-determined permission does not schedule', () async {
      final scheduler = await syncWith(permission: NotificationPermission.notDetermined);
      expect(scheduler.scheduled, isEmpty);
    });

    test('a toggle-off that lands during the async probes cancels, never schedules', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.key, true);
      scheduler.onPermissionProbe = () => s.reflect.setEnabled(false);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, contains('reflect.weekly'));
    });
  });
}
