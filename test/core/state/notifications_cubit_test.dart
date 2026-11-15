import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/state/notifications_cubit.dart';
import 'package:reflections/reflections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_notification_scheduler.dart';

class _FailableWrites extends LocalService {
  bool failing = false;
  Completer<void>? gate;
  void Function(String key, Object? value)? onWrite;

  @override
  Future<void> write<T>(String key, T value) async {
    onWrite?.call(key, value);
    final held = gate;
    if (held != null) await held.future;
    if (failing) throw StateError('no disk');
    return super.write(key, value);
  }
}

typedef _Built = ({
  NotificationsCubit cubit,
  FakeNotificationScheduler scheduler,
  NotificationSettings notify,
  ReflectionSettings reflect,
  _FailableWrites storage,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting();
  });

  const weekly = ReflectionPeriod.weekly;
  final weeklyKey = ReflectionNotifier.keyFor(weekly);

  Future<_Built> build({
    NotificationPermission permission = NotificationPermission.authorized,
    bool grant = true,
    bool reflectionsEnabled = true,
    bool available = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FailableWrites();
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
    );
    final cubit = NotificationsCubit(
      scheduler: scheduler,
      settings: notify,
      notifier: notifier,
      reflectionSettings: reflect,
      availability: availability,
    );
    await cubit.load();
    return (cubit: cubit, scheduler: scheduler, notify: notify, reflect: reflect, storage: storage);
  }

  NotificationsCubit reopen(
    _Built b, {
    bool available = true,
    Future<ReflectionAvailability> Function()? probe,
  }) {
    final availability =
        probe ??
        () async => available
            ? const ReflectionAvailability.available()
            : const ReflectionAvailability.unsupported();
    return NotificationsCubit(
      scheduler: b.scheduler,
      settings: b.notify,
      notifier: ReflectionNotifier(
        scheduler: b.scheduler,
        notifySettings: b.notify,
        reflectionSettings: b.reflect,
        availability: availability,
        language: () => 'en',
      ),
      reflectionSettings: b.reflect,
      availability: availability,
    );
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
      ),
      reflectionSettings: reflect,
      availability: () async => const ReflectionAvailability.available(),
    );

    expect(cubit.state.shownPeriods, [weekly]);
    expect(cubit.state.slotOf(weekly).selected, isTrue);
    expect(cubit.state.master, isTrue);
  });

  test('load reflects the persisted toggle, time, and permission', () async {
    final b = await build();
    await b.notify.setEnabled(weeklyKey, true);
    await b.notify.setTime(ReflectionNotifier.timeKey, hour: 7, minute: 15);
    await b.cubit.load();

    expect(b.cubit.state.slotOf(weekly).selected, isTrue);
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

  test('turning the master on seeds every shown period and persists', () async {
    final b = await build();
    await b.cubit.setMaster(true);

    expect(b.cubit.state.master, isTrue);
    expect(b.cubit.state.slotOf(weekly).selected, isTrue);
    expect(b.notify.enabled(weeklyKey), isTrue);
    expect(b.notify.enabled(ReflectionNotifier.timeKey), isTrue);
    expect(b.scheduler.permissionRequests, 0);
  });

  test('the seed covers every shown period, not only one', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();

    await b.cubit.setMaster(true);

    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).selected, isTrue);
    expect(b.cubit.state.slotOf(weekly).selected, isTrue);
  });

  test('a lone shown period counts selected with nothing stored', () async {
    final b = await build();

    expect(b.cubit.state.slotOf(weekly).selected, isTrue);
    expect(b.notify.enabledOrNull(weeklyKey), isNull);
  });

  test('a picked mix survives the master going off and on', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();
    await b.cubit.setMaster(true);
    await b.cubit.setSelected(weekly, false);

    await b.cubit.setMaster(false);
    await b.cubit.setMaster(true);

    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).selected, isTrue);
    expect(b.cubit.state.slotOf(weekly).selected, isFalse);
  });

  test('turning the master on from undecided requests permission once', () async {
    final b = await build(permission: NotificationPermission.notDetermined);
    await b.cubit.setMaster(true);

    expect(b.scheduler.permissionRequests, 1);
    expect(b.cubit.state.master, isTrue);
    expect(b.cubit.state.permission, NotificationPermission.authorized);
  });

  test('selecting a period never prompts; the master already settled it', () async {
    final b = await build(permission: NotificationPermission.notDetermined);
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();

    await b.cubit.setMaster(true);
    await b.cubit.setSelected(ReflectionPeriod.daily, true);

    expect(b.scheduler.permissionRequests, 1);
    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).selected, isTrue);
  });

  test('a denied prompt keeps the master on and surfaces the block', () async {
    final b = await build(permission: NotificationPermission.notDetermined, grant: false);
    await b.cubit.setMaster(true);

    expect(b.cubit.state.master, isTrue);
    expect(b.cubit.state.permission, NotificationPermission.denied);
    expect(b.cubit.state.permissionBlocked, isTrue);
    expect(b.notify.enabled(ReflectionNotifier.timeKey), isTrue);
  });

  test('an already-denied permission persists the intent without prompting again', () async {
    final b = await build(permission: NotificationPermission.denied);
    await b.cubit.setMaster(true);

    expect(b.scheduler.permissionRequests, 0);
    expect(b.cubit.state.master, isTrue);
    expect(b.cubit.state.permissionBlocked, isTrue);
  });

  test('an enabled nudge whose permission was revoked surfaces the block on load', () async {
    final b = await build(permission: NotificationPermission.denied);
    await b.notify.setEnabled(weeklyKey, true);
    await b.cubit.load();

    expect(b.cubit.state.slotOf(weekly).selected, isTrue);
    expect(b.cubit.state.permissionBlocked, isTrue);
  });

  test('turning the master off persists and keeps the selection stored', () async {
    final b = await build();
    await b.cubit.setMaster(true);
    await b.cubit.setMaster(false);

    expect(b.cubit.state.master, isFalse);
    expect(b.notify.enabled(ReflectionNotifier.timeKey), isFalse);
    expect(b.notify.enabled(weeklyKey), isTrue);
    expect(b.cubit.state.permissionBlocked, isFalse);
  });

  test('deselecting the last period turns the master off with it', () async {
    final b = await build();
    await b.cubit.setMaster(true);

    await b.cubit.setSelected(weekly, false);

    expect(b.cubit.state.master, isFalse);
    expect(b.notify.enabled(ReflectionNotifier.timeKey), isFalse);
    expect(b.notify.enabled(weeklyKey), isFalse);
  });

  test('deselecting one period leaves the others intact', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();
    await b.cubit.setMaster(true);

    await b.cubit.setSelected(ReflectionPeriod.daily, false);

    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).selected, isFalse);
    expect(b.cubit.state.slotOf(weekly).selected, isTrue);
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

  test('the master with every period off neither prompts nor stores', () async {
    final b = await build(
      permission: NotificationPermission.notDetermined,
      reflectionsEnabled: false,
    );
    await b.cubit.setMaster(true);

    expect(b.scheduler.permissionRequests, 0);
    expect(b.cubit.state.master, isFalse);
    expect(b.notify.enabledOrNull(ReflectionNotifier.timeKey), isNull);
  });

  test('selecting a period switched off elsewhere drops its tile on the recheck', () async {
    final b = await build();
    await b.cubit.setMaster(true);
    await b.cubit.setSelected(weekly, false);
    await b.reflect.setEnabledFor(weekly, false);

    await b.cubit.setSelected(weekly, true);

    expect(b.cubit.state.shownPeriods, isEmpty);
    expect(b.notify.enabled(weeklyKey), isFalse);
  });

  test('the master while the model is unavailable neither prompts nor stores', () async {
    final b = await build(permission: NotificationPermission.notDetermined, available: false);
    await b.cubit.setMaster(true);

    expect(b.scheduler.permissionRequests, 0);
    expect(b.cubit.state.master, isFalse);
    expect(b.notify.enabledOrNull(ReflectionNotifier.timeKey), isNull);
  });

  test('nothing selected means a denied permission is not a block', () async {
    final b = await build(permission: NotificationPermission.denied);

    expect(b.cubit.state.permissionBlocked, isFalse);
  });

  test('a reopened screen starts on the last probed permission and availability', () async {
    final b = await build(permission: NotificationPermission.denied, available: false);

    final reopened = reopen(b, available: false);

    expect(reopened.state.permission, NotificationPermission.denied);
    expect(reopened.state.reflectionsAvailable, isFalse);
    await reopened.close();
  });

  test('a first load that finds nothing changed lands on the state it opened on', () async {
    final b = await build(permission: NotificationPermission.denied);
    await b.notify.setEnabled(weeklyKey, true);
    await b.notify.setEnabled(ReflectionNotifier.timeKey, true);
    await b.cubit.load();

    final reopened = reopen(b);
    final opened = reopened.state;
    final emitted = <NotificationsState>[];
    final sub = reopened.stream.listen(emitted.add);

    await reopened.load();
    await pumpEventQueue();

    expect(opened.permissionBlocked, isTrue);
    expect(emitted, everyElement(opened));
    await sub.cancel();
    await reopened.close();
  });

  test('a never-probed device opens undecided and optimistic about the model', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final notify = NotificationSettings(storage: storage);
    final reflect = ReflectionSettings(storage: storage);
    final scheduler = FakeNotificationScheduler();
    availability() async => const ReflectionAvailability.available();
    final cubit = NotificationsCubit(
      scheduler: scheduler,
      settings: notify,
      notifier: ReflectionNotifier(
        scheduler: scheduler,
        notifySettings: notify,
        reflectionSettings: reflect,
        availability: availability,
        language: () => 'en',
      ),
      reflectionSettings: reflect,
      availability: availability,
    );

    expect(cubit.state.permission, NotificationPermission.notDetermined);
    expect(cubit.state.reflectionsAvailable, isTrue);
    await cubit.close();
  });

  test('turning the master on answers before any probe, seeding the tiles with it', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();

    final turning = b.cubit.setMaster(true);

    expect(b.cubit.state.master, isTrue);
    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).selected, isTrue);
    expect(b.cubit.state.slotOf(weekly).selected, isTrue);
    await turning;
    expect(b.cubit.state.master, isTrue);
  });

  test('turning the master off answers before the write lands', () async {
    final b = await build();
    await b.cubit.setMaster(true);

    final turning = b.cubit.setMaster(false);

    expect(b.cubit.state.master, isFalse);
    await turning;
    expect(b.notify.enabled(ReflectionNotifier.timeKey), isFalse);
  });

  test('a turn-on the model refuses takes the switch back', () async {
    final b = await build(available: false);
    final emitted = <bool>[];
    final sub = b.cubit.stream.listen((state) => emitted.add(state.master));

    await b.cubit.setMaster(true);
    await pumpEventQueue();

    expect(emitted, [true, false]);
    expect(b.cubit.state.master, isFalse);
    await sub.cancel();
  });

  test('a load landing while a turn-on waits on permission keeps the switch on', () async {
    final b = await build(permission: NotificationPermission.notDetermined);
    var resumed = false;
    b.scheduler.onPermissionProbe = () async {
      if (resumed) return;
      resumed = true;
      unawaited(b.cubit.load());
    };
    final masters = <bool>[];
    final sub = b.cubit.stream.listen((state) => masters.add(state.master));

    await b.cubit.setMaster(true);
    await pumpEventQueue();

    expect(resumed, isTrue);
    expect(masters, isNotEmpty);
    expect(masters, everyElement(isTrue));
    expect(b.cubit.state.master, isTrue);
    await sub.cancel();
  });

  test('a fast on then off ends off, with nothing seeded behind it', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();

    final on = b.cubit.setMaster(true);
    final off = b.cubit.setMaster(false);
    await Future.wait([on, off]);
    await pumpEventQueue();

    expect(b.cubit.state.master, isFalse);
    expect(b.notify.enabled(ReflectionNotifier.timeKey), isFalse);
    expect(b.notify.enabled(weeklyKey), isFalse);
    expect(b.notify.enabled(ReflectionNotifier.keyFor(ReflectionPeriod.daily)), isFalse);
  });

  test('a tile deselected while the switch arms lands as seen: on, with the rest', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();

    final on = b.cubit.setMaster(true);
    final deselect = b.cubit.setSelected(ReflectionPeriod.daily, false);
    await Future.wait([on, deselect]);
    await pumpEventQueue();

    expect(b.cubit.state.master, isTrue);
    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).selected, isFalse);
    expect(b.cubit.state.slotOf(weekly).selected, isTrue);
    expect(b.notify.enabled(ReflectionNotifier.keyFor(ReflectionPeriod.daily)), isFalse);
    expect(b.notify.enabled(weeklyKey), isTrue);
    expect(b.notify.enabled(ReflectionNotifier.timeKey), isTrue);
  });

  test('deselecting the only armed tile while the switch arms turns it off unseeded', () async {
    final b = await build();

    final on = b.cubit.setMaster(true);
    final deselect = b.cubit.setSelected(weekly, false);
    await Future.wait([on, deselect]);
    await pumpEventQueue();

    expect(b.cubit.state.master, isFalse);
    expect(b.notify.enabled(weeklyKey), isFalse);
  });

  test('an off overtaken by a refused on still clears the scheduled nudge', () async {
    final b = await build();
    var available = true;
    final cubit = reopen(
      b,
      probe: () async => available
          ? const ReflectionAvailability.available()
          : const ReflectionAvailability.unsupported(),
    );
    await cubit.setMaster(true);
    await pumpEventQueue();
    expect(b.scheduler.scheduled, isNotEmpty);
    b.scheduler.cancelled.clear();
    available = false;

    final off = cubit.setMaster(false);
    final on = cubit.setMaster(true);
    await Future.wait([off, on]);
    await pumpEventQueue();

    expect(cubit.state.master, isFalse);
    expect(b.scheduler.cancelled, contains(weeklyKey));
    await cubit.close();
  });

  test('a probe that throws mid turn-on lands on storage, with nothing thrown', () async {
    final b = await build();
    var throwing = false;
    final cubit = reopen(
      b,
      probe: () async {
        if (throwing) throw StateError('no model service');
        return const ReflectionAvailability.available();
      },
    );
    await pumpEventQueue();
    throwing = true;

    await cubit.setMaster(true);
    expect(cubit.state.master, isFalse);

    await cubit.load();
    throwing = false;
    await cubit.load();
    expect(cubit.state.master, isFalse);
    await cubit.close();
  });

  test('a tile deselected after the turn-on began writing still lands as seen', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();
    const masterKey = 'notify.${ReflectionNotifier.timeKey}.enabled';
    Future<void>? deselect;
    b.storage.onWrite = (key, value) {
      if (key == masterKey && value == 'true' && deselect == null) {
        deselect = b.cubit.setSelected(ReflectionPeriod.daily, false);
      }
    };

    await b.cubit.setMaster(true);
    await deselect;
    await pumpEventQueue();

    expect(deselect, isNotNull);
    expect(b.cubit.state.master, isTrue);
    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).selected, isFalse);
    expect(b.cubit.state.slotOf(weekly).selected, isTrue);
    expect(b.notify.enabled(ReflectionNotifier.keyFor(ReflectionPeriod.daily)), isFalse);
    expect(b.notify.enabled(weeklyKey), isTrue);
  });

  test('an arming overtaken by an off while its writes queue ends off, stored and shown', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();
    var holding = false;
    final probe = Completer<ReflectionAvailability>();
    final cubit = reopen(
      b,
      probe: () => holding ? probe.future : Future.value(const ReflectionAvailability.available()),
    );
    await pumpEventQueue();
    holding = true;

    final on = cubit.setMaster(true);
    b.storage.gate = Completer<void>();
    final deselect = cubit.setSelected(ReflectionPeriod.daily, false);
    probe.complete(const ReflectionAvailability.available());
    await pumpEventQueue();
    final off = cubit.setMaster(false);
    final writes = b.storage.gate!;
    b.storage.gate = null;
    writes.complete();
    await Future.wait([on, deselect, off]);
    await pumpEventQueue();

    expect(cubit.state.master, isFalse);
    expect(b.notify.enabled(ReflectionNotifier.timeKey), isFalse);
    expect(b.notify.enabledOrNull(ReflectionNotifier.timeKey), isFalse);
    await cubit.close();
  });

  test('a refused turn-on lands after a tile tap still draining, never before it', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();
    var holding = false;
    final probe = Completer<ReflectionAvailability>();
    final cubit = reopen(
      b,
      probe: () => holding ? probe.future : Future.value(const ReflectionAvailability.available()),
    );
    await pumpEventQueue();
    holding = true;

    final on = cubit.setMaster(true);
    b.storage.gate = Completer<void>();
    final deselect = cubit.setSelected(ReflectionPeriod.daily, false);
    final weeklyShown = <bool>[];
    final sub = cubit.stream.listen((state) => weeklyShown.add(state.slotOf(weekly).selected));
    probe.complete(const ReflectionAvailability.unsupported());
    await pumpEventQueue();
    final writes = b.storage.gate!;
    b.storage.gate = null;
    writes.complete();
    await Future.wait([on, deselect]);
    await pumpEventQueue();

    expect(cubit.state.master, isFalse);
    expect(weeklyShown, isNotEmpty);
    expect(weeklyShown, everyElement(isTrue));
    await sub.cancel();
    await cubit.close();
  });

  test('a tile whose write fails lands back on storage, with nothing thrown', () async {
    final b = await build();
    await b.reflect.setEnabledFor(ReflectionPeriod.daily, true);
    await b.cubit.load();
    await b.cubit.setMaster(true);
    b.storage.failing = true;

    await b.cubit.setSelected(ReflectionPeriod.daily, false);

    expect(b.cubit.state.slotOf(ReflectionPeriod.daily).selected, isTrue);
    expect(b.cubit.state.master, isTrue);
  });

  test('a time whose write fails lands back on the stored time, with nothing thrown', () async {
    final b = await build();
    b.storage.failing = true;

    await b.cubit.setTime(hour: 21, minute: 45);

    expect(b.cubit.state.hour, NotificationSettings.defaultHour);
    expect(b.cubit.state.minute, NotificationSettings.defaultMinute);
  });

  test('a turn-off whose write fails lands back on, with nothing thrown', () async {
    final b = await build();
    await b.cubit.setMaster(true);
    b.storage.failing = true;

    await b.cubit.setMaster(false);

    expect(b.cubit.state.master, isTrue);
  });

  test('a turn-on whose write fails lands back off, with nothing thrown', () async {
    final b = await build();
    b.storage.failing = true;

    await b.cubit.setMaster(true);

    expect(b.cubit.state.master, isFalse);
  });

  group('where a turn-on lands', () {
    test('nothing picked yet picks every shown period', () {
      const state = NotificationsState(
        slots: {
          ReflectionPeriod.daily: NotificationSlot(reflectionEnabled: true),
          ReflectionPeriod.weekly: NotificationSlot(reflectionEnabled: true),
          ReflectionPeriod.monthly: NotificationSlot(),
        },
      );
      final armed = state.armed;
      expect(armed.master, isTrue);
      expect(armed.slotOf(ReflectionPeriod.daily).selected, isTrue);
      expect(armed.slotOf(ReflectionPeriod.weekly).selected, isTrue);
      expect(armed.slotOf(ReflectionPeriod.monthly).selected, isFalse);
    });

    test('a mix picked earlier survives untouched', () {
      const state = NotificationsState(
        slots: {
          ReflectionPeriod.daily: NotificationSlot(reflectionEnabled: true, selected: true),
          ReflectionPeriod.weekly: NotificationSlot(reflectionEnabled: true),
        },
      );
      final armed = state.armed;
      expect(armed.slotOf(ReflectionPeriod.daily).selected, isTrue);
      expect(armed.slotOf(ReflectionPeriod.weekly).selected, isFalse);
    });
  });

  group('what will actually nudge', () {
    const slots = {
      ReflectionPeriod.daily: NotificationSlot(reflectionEnabled: true, selected: true),
      ReflectionPeriod.weekly: NotificationSlot(reflectionEnabled: true),
      ReflectionPeriod.monthly: NotificationSlot(selected: true),
    };

    test('only enabled, selected periods nudge once iOS lets the app notify', () {
      const state = NotificationsState(
        master: true,
        slots: slots,
        permission: NotificationPermission.authorized,
      );
      expect(state.nudgingPeriods, [ReflectionPeriod.daily]);
    });

    test('nothing nudges while iOS has not been asked yet', () {
      const state = NotificationsState(master: true, slots: slots);
      expect(state.nudgingPeriods, isEmpty);
    });

    test('nothing nudges with the switch off', () {
      const state = NotificationsState(slots: slots, permission: NotificationPermission.authorized);
      expect(state.nudgingPeriods, isEmpty);
    });
  });
}
