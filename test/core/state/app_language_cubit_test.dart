import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/app/app_language.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/state/app_language_cubit.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:reflections/reflections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_notification_scheduler.dart';

class _FailingLanguageWrites extends LocalService {
  @override
  Future<void> write<T>(String key, T value) async {
    if (key == AppLanguage.key) throw StateError('no disk');
    return super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting();
  });

  final clock = DateTime(2026, 8, 2, 10);

  Future<({LocalService storage, FakeNotificationScheduler scheduler, ReflectionNotifier notifier})>
  build({LocalService? storage}) async {
    SharedPreferences.setMockInitialValues({});
    final local = storage ?? LocalService();
    await local.init(legacyKey: 'test-encryption-key-0123456789ab');
    final notify = NotificationSettings(storage: local);
    await notify.setEnabled(ReflectionNotifier.keyFor(ReflectionPeriod.weekly), true);
    final scheduler = FakeNotificationScheduler();
    final notifier = ReflectionNotifier(
      scheduler: scheduler,
      notifySettings: notify,
      reflectionSettings: ReflectionSettings(storage: local),
      availability: () async => const ReflectionAvailability.available(),
      language: () => AppLanguage.of(local),
      clock: () => clock,
    );
    return (storage: local, scheduler: scheduler, notifier: notifier);
  }

  Iterable<Map<String, Object?>> weekly(FakeNotificationScheduler scheduler) =>
      scheduler.scheduled.where((s) => s['method'] == 'scheduleWeekly');

  test(
    'switching the language moves the weekly nudge to the new week boundary, in its words',
    () async {
      final s = await build();
      await s.notifier.sync();
      expect(weekly(s.scheduler).last['weekday'], startOfWeek(clock, localeId: 'en').weekday);

      final cubit = AppLanguageCubit(storage: s.storage, notifier: s.notifier);
      await cubit.setLanguage('de');
      await pumpEventQueue();

      expect(cubit.state, 'de');
      final nudge = weekly(s.scheduler).last;
      expect(nudge['weekday'], startOfWeek(clock, localeId: 'de').weekday);
      expect(nudge['weekday'], isNot(startOfWeek(clock, localeId: 'en').weekday));
      expect(nudge['title'], lookupAppLocalizations(const Locale('de')).notifyWeeklyTitle);
      await cubit.close();
    },
  );

  test('a language that failed to save neither emits nor resyncs', () async {
    final s = await build(storage: _FailingLanguageWrites());
    final cubit = AppLanguageCubit(storage: s.storage, notifier: s.notifier);

    await expectLater(cubit.setLanguage('de'), throwsStateError);
    await pumpEventQueue();

    expect(cubit.state, 'en');
    expect(s.scheduler.scheduled, isEmpty);
    await cubit.close();
  });
}
