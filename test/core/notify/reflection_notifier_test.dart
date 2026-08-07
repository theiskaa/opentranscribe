import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
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
  const allKeys = ['reflect.daily', 'reflect.weekly', 'reflect.monthly'];

  Future<({NotificationSettings notify, ReflectionSettings reflect})> settings() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
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
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.weekly), true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.lastScheduled!['method'], 'scheduleWeekly');
      expect(scheduler.lastScheduled!['id'], 'reflect.weekly');
    });

    test('the weekday is the app-language week boundary', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.weekly), true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.lastScheduled!['weekday'], startOfWeek(clock, localeId: 'en').weekday);
    });

    test('a daily nudge repeats on time alone, with no weekday', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.reflect.setEnabledFor(ReflectionPeriod.daily, true);
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.daily), true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      final daily = scheduler.scheduled.singleWhere((m) => m['id'] == 'reflect.daily');
      expect(daily['method'], 'scheduleDaily');
      expect(daily.containsKey('weekday'), isFalse);
      expect(daily.containsKey('day'), isFalse);
    });

    test('a monthly nudge fires on the first of the month', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.reflect.setEnabledFor(ReflectionPeriod.monthly, true);
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.monthly), true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      final monthly = scheduler.scheduled.singleWhere((m) => m['id'] == 'reflect.monthly');
      expect(monthly['method'], 'scheduleMonthly');
      expect(monthly['day'], 1);
    });

    test('every enabled period schedules under its own identifier', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      for (final period in ReflectionPeriod.values) {
        await s.reflect.setEnabledFor(period, true);
        await s.notify.setEnabled(ReflectionNotifier.keyFor(period), true);
      }
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.scheduled.map((m) => m['id']), allKeys);
      expect(scheduler.cancelled, isEmpty);
    });

    test('the shared time drives every period', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      for (final period in ReflectionPeriod.values) {
        await s.reflect.setEnabledFor(period, true);
        await s.notify.setEnabled(ReflectionNotifier.keyFor(period), true);
      }
      await s.notify.setTime(ReflectionNotifier.timeKey, hour: 7, minute: 5);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.scheduled, hasLength(3));
      for (final scheduled in scheduler.scheduled) {
        expect(scheduled['hour'], 7);
        expect(scheduled['minute'], 5);
      }
    });

    test('each period carries its own generic app-language strings', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      for (final period in ReflectionPeriod.values) {
        await s.reflect.setEnabledFor(period, true);
        await s.notify.setEnabled(ReflectionNotifier.keyFor(period), true);
      }
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final byId = {for (final m in scheduler.scheduled) m['id']: m};
      expect(byId['reflect.daily']!['title'], l10n.notifyDailyTitle);
      expect(byId['reflect.daily']!['body'], l10n.notifyDailyBody);
      expect(byId['reflect.weekly']!['title'], l10n.notifyWeeklyTitle);
      expect(byId['reflect.weekly']!['body'], l10n.notifyWeeklyBody);
      expect(byId['reflect.monthly']!['title'], l10n.notifyMonthlyTitle);
      expect(byId['reflect.monthly']!['body'], l10n.notifyMonthlyBody);
    });

    test('a changed time reschedules under the same identifier', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      final key = ReflectionNotifier.keyFor(ReflectionPeriod.weekly);
      await s.notify.setEnabled(key, true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();
      await s.notify.setTime(ReflectionNotifier.timeKey, hour: 21, minute: 0);
      await notifier.sync();

      expect(scheduler.scheduled.map((m) => m['id']), everyElement('reflect.weekly'));
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
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.weekly), weeklyOn);
      await s.reflect.setEnabledFor(ReflectionPeriod.weekly, reflectionsOn);
      final notifier = await build(
        scheduler: scheduler,
        notify: s.notify,
        reflect: s.reflect,
        availability: availability,
      );
      await notifier.sync();
      return scheduler;
    }

    test('cancels every period when the only enabled toggle turns off', () async {
      final scheduler = await syncWith(weeklyOn: false);
      expect(scheduler.cancelled, allKeys);
      expect(scheduler.scheduled, isEmpty);
    });

    test('cancels every period when reflections are disabled', () async {
      final scheduler = await syncWith(reflectionsOn: false);
      expect(scheduler.cancelled, allKeys);
      expect(scheduler.scheduled, isEmpty);
    });

    test('cancels every period when notification permission is not granted', () async {
      final scheduler = await syncWith(permission: NotificationPermission.denied);
      expect(scheduler.cancelled, allKeys);
      expect(scheduler.scheduled, isEmpty);
    });

    test('cancels every period when the on-device model cannot run', () async {
      final scheduler = await syncWith(availability: const ReflectionAvailability.unsupported());
      expect(scheduler.cancelled, allKeys);
      expect(scheduler.scheduled, isEmpty);
    });

    test('a not-determined permission does not schedule', () async {
      final scheduler = await syncWith(permission: NotificationPermission.notDetermined);
      expect(scheduler.scheduled, isEmpty);
    });

    test('a period with its nudge on but reflections off cancels only that period', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.reflect.setEnabledFor(ReflectionPeriod.daily, false);
      await s.reflect.setEnabledFor(ReflectionPeriod.monthly, false);
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.daily), true);
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.weekly), true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.scheduled.map((m) => m['id']), ['reflect.weekly']);
      expect(scheduler.cancelled, ['reflect.daily', 'reflect.monthly']);
    });

    test('a stored-off master cancels every period despite selections', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.weekly), true);
      await s.notify.setEnabled(ReflectionNotifier.timeKey, false);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, allKeys);
    });

    test('an unset master falls back to the stored selections', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.weekly), true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.scheduled.map((m) => m['id']), ['reflect.weekly']);
    });

    test('a lone enabled period nudges under the master alone, unpicked', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.reflect.setEnabledFor(ReflectionPeriod.daily, false);
      await s.reflect.setEnabledFor(ReflectionPeriod.monthly, false);
      await s.notify.setEnabled(ReflectionNotifier.timeKey, true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.scheduled.map((m) => m['id']), ['reflect.weekly']);
    });

    test('a stored-on master with nothing selected schedules nothing', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.timeKey, true);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, allKeys);
    });

    test('a toggle-off that lands during the async probes cancels, never schedules', () async {
      final scheduler = FakeNotificationScheduler();
      final s = await settings();
      await s.notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.weekly), true);
      scheduler.onPermissionProbe = () => s.reflect.setEnabledFor(ReflectionPeriod.weekly, false);
      final notifier = await build(scheduler: scheduler, notify: s.notify, reflect: s.reflect);

      await notifier.sync();

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, contains('reflect.weekly'));
    });
  });
}
