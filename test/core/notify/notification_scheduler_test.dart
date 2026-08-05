import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('opentranscribe/notify');

  late PlatformNotificationScheduler scheduler;

  setUp(() {
    scheduler = PlatformNotificationScheduler();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mock(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  group('requestPermission', () {
    test('returns the native grant', () async {
      mock((call) async {
        expect(call.method, 'requestPermission');
        return true;
      });
      expect(await scheduler.requestPermission(), isTrue);
    });

    test('a null native answer reads as not granted', () async {
      mock((call) async => null);
      expect(await scheduler.requestPermission(), isFalse);
    });

    test('a channel error reads as not granted, not a throw', () async {
      mock((call) async => throw PlatformException(code: 'boom'));
      expect(await scheduler.requestPermission(), isFalse);
    });

    test('a missing plugin reads as not granted', () async {
      expect(await scheduler.requestPermission(), isFalse);
    });
  });

  group('permissionStatus', () {
    Future<void> expectStatus(String? wire, NotificationPermission expected) async {
      mock((call) async {
        expect(call.method, 'authorizationStatus');
        return wire;
      });
      expect(await scheduler.permissionStatus(), expected);
    }

    test('maps the native authorization strings to the enum', () async {
      await expectStatus('authorized', NotificationPermission.authorized);
      await expectStatus('denied', NotificationPermission.denied);
      await expectStatus('notDetermined', NotificationPermission.notDetermined);
    });

    test('provisional and ephemeral both count as authorized', () async {
      await expectStatus('provisional', NotificationPermission.authorized);
      await expectStatus('ephemeral', NotificationPermission.authorized);
    });

    test('an unknown status reads as not determined', () async {
      await expectStatus('something_new', NotificationPermission.notDetermined);
    });

    test('a channel error reads as not determined', () async {
      mock((call) async => throw PlatformException(code: 'boom'));
      expect(await scheduler.permissionStatus(), NotificationPermission.notDetermined);
    });

    test('a missing plugin reads as not determined', () async {
      expect(await scheduler.permissionStatus(), NotificationPermission.notDetermined);
    });
  });

  group('scheduleDaily', () {
    test('sends the identifier, time, and generic strings, with no day fields', () async {
      Map<String, Object?>? sent;
      mock((call) async {
        expect(call.method, 'scheduleDaily');
        sent = (call.arguments as Map).cast<String, Object?>();
        return null;
      });

      await scheduler.scheduleDaily(
        id: 'reflect.daily',
        hour: 9,
        minute: 30,
        title: 'Your day is ready',
        body: 'Open to read it.',
      );

      expect(sent, {
        'identifier': 'reflect.daily',
        'hour': 9,
        'minute': 30,
        'title': 'Your day is ready',
        'body': 'Open to read it.',
      });
    });

    test('a channel error is swallowed, not thrown', () async {
      mock((call) async => throw PlatformException(code: 'schedule_failed'));
      await scheduler.scheduleDaily(id: 'reflect.daily', hour: 9, minute: 0, title: 't', body: 'b');
    });

    test('a missing plugin is a silent no-op', () async {
      await scheduler.scheduleDaily(id: 'reflect.daily', hour: 9, minute: 0, title: 't', body: 'b');
    });
  });

  group('scheduleWeekly', () {
    test('sends the identifier, weekday, time, and generic strings', () async {
      Map<String, Object?>? sent;
      mock((call) async {
        expect(call.method, 'scheduleWeekly');
        sent = (call.arguments as Map).cast<String, Object?>();
        return null;
      });

      await scheduler.scheduleWeekly(
        id: 'reflect.weekly',
        weekday: 7,
        hour: 9,
        minute: 30,
        title: 'Your week is ready',
        body: 'Open to read it.',
      );

      expect(sent, {
        'identifier': 'reflect.weekly',
        'weekday': 7,
        'hour': 9,
        'minute': 30,
        'title': 'Your week is ready',
        'body': 'Open to read it.',
      });
    });

    test('a channel error is swallowed, not thrown', () async {
      mock((call) async => throw PlatformException(code: 'schedule_failed'));
      await scheduler.scheduleWeekly(
        id: 'reflect.weekly',
        weekday: 1,
        hour: 9,
        minute: 0,
        title: 't',
        body: 'b',
      );
    });

    test('a missing plugin is a silent no-op', () async {
      await scheduler.scheduleWeekly(
        id: 'reflect.weekly',
        weekday: 1,
        hour: 9,
        minute: 0,
        title: 't',
        body: 'b',
      );
    });
  });

  group('scheduleMonthly', () {
    test('sends the identifier, day of month, time, and generic strings', () async {
      Map<String, Object?>? sent;
      mock((call) async {
        expect(call.method, 'scheduleMonthly');
        sent = (call.arguments as Map).cast<String, Object?>();
        return null;
      });

      await scheduler.scheduleMonthly(
        id: 'reflect.monthly',
        day: 1,
        hour: 9,
        minute: 30,
        title: 'Your month is ready',
        body: 'Open to read it.',
      );

      expect(sent, {
        'identifier': 'reflect.monthly',
        'day': 1,
        'hour': 9,
        'minute': 30,
        'title': 'Your month is ready',
        'body': 'Open to read it.',
      });
    });

    test('a channel error is swallowed, not thrown', () async {
      mock((call) async => throw PlatformException(code: 'schedule_failed'));
      await scheduler.scheduleMonthly(
        id: 'reflect.monthly',
        day: 1,
        hour: 9,
        minute: 0,
        title: 't',
        body: 'b',
      );
    });

    test('a missing plugin is a silent no-op', () async {
      await scheduler.scheduleMonthly(
        id: 'reflect.monthly',
        day: 1,
        hour: 9,
        minute: 0,
        title: 't',
        body: 'b',
      );
    });
  });

  group('cancel', () {
    test('sends the identifier', () async {
      Map<String, Object?>? sent;
      mock((call) async {
        expect(call.method, 'cancel');
        sent = (call.arguments as Map).cast<String, Object?>();
        return null;
      });
      await scheduler.cancel('reflect.weekly');
      expect(sent, {'identifier': 'reflect.weekly'});
    });

    test('a channel error is swallowed, not thrown', () async {
      mock((call) async => throw PlatformException(code: 'boom'));
      await scheduler.cancel('reflect.weekly');
    });

    test('a missing plugin is a silent no-op', () async {
      await scheduler.cancel('reflect.weekly');
    });
  });
}
