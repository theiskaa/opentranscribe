import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'weekly';

  Future<({LocalService storage, NotificationSettings settings})> build() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    return (storage: storage, settings: NotificationSettings(storage: storage));
  }

  group('defaults', () {
    test('a notification is off until the user opts in', () async {
      final built = await build();
      expect(built.settings.enabled(key), isFalse);
    });

    test('the fire time defaults to a civil morning hour', () async {
      final built = await build();
      expect(built.settings.hour(key), 9);
      expect(built.settings.minute(key), 0);
    });
  });

  group('enabled', () {
    test('persists per key across a fresh read', () async {
      final settings = (await build()).settings;
      await settings.setEnabled(key, true);
      expect(settings.enabled(key), isTrue);
      await settings.setEnabled(key, false);
      expect(settings.enabled(key), isFalse);
    });

    test('keys are independent', () async {
      final settings = (await build()).settings;
      await settings.setEnabled('a', true);
      expect(settings.enabled('a'), isTrue);
      expect(settings.enabled('b'), isFalse);
    });
  });

  group('setTime', () {
    test('persists the chosen hour and minute per key', () async {
      final settings = (await build()).settings;
      await settings.setTime(key, hour: 21, minute: 45);
      expect(settings.hour(key), 21);
      expect(settings.minute(key), 45);
    });

    test('clamps an out-of-range hour and minute into the valid day', () async {
      final settings = (await build()).settings;
      await settings.setTime(key, hour: 30, minute: 90);
      expect(settings.hour(key), 23);
      expect(settings.minute(key), 59);
    });
  });

  group('defensive reads', () {
    test('a stored hour outside the day falls back to the default, not a clamp', () async {
      final built = await build();
      await built.storage.write('notify.$key.hour', '47');
      expect(built.settings.hour(key), 9);
    });

    test('a non-numeric stored minute falls back to the default', () async {
      final built = await build();
      await built.storage.write('notify.$key.minute', 'oops');
      expect(built.settings.minute(key), 0);
    });
  });
}
