import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:opentranscribe/core/app/local_service.dart';

const _key = 'test-encryption-key-0123456789ab';

Uint8List _deviceKey() => Uint8List.fromList(List.generate(32, (i) => i + 1));

String _v2Record(String plaintext) {
  final derived = Key.fromUtf8(_key.substring(0, 32));
  final iv = IV.fromSecureRandom(16);
  final aes = Encrypter(AES(derived, mode: AESMode.cbc));
  return 'v2:${iv.base64}:${aes.encrypt(plaintext, iv: iv).base64}';
}

String _fernetRecord(String plaintext) {
  final derived = Key.fromUtf8(_key.substring(0, 32));
  final fernet = Encrypter(Fernet(Key.fromUtf8(base64Url.encode(derived.bytes).substring(0, 32))));
  return fernet.encrypt(plaintext).base64;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('legacy mode (no device key)', () {
    late LocalService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalService();
      await storage.init(legacyKey: _key);
    });

    test('encrypts and round-trips a string value', () async {
      await storage.write('language', 'ka');
      expect(storage.readString('language'), 'ka');
    });

    test('the stored form is the versioned ciphertext, not plaintext', () async {
      await storage.write('language', 'a-plaintext-marker-no-ciphertext-contains');
      final raw = (await SharedPreferences.getInstance()).getString('language');
      expect(raw, isNotNull);
      expect(raw, startsWith('v2:'));
      expect(raw, isNot(contains('a-plaintext-marker-no-ciphertext-contains')));
    });

    test('an empty string round-trips (padding cannot encrypt zero bytes)', () async {
      await storage.write('empty', '');
      expect(storage.readString('empty'), '');
    });

    test('legacy Fernet records remain readable after the format change', () async {
      // Reconstruct exactly what the old code wrote: Fernet over the derived key.
      final legacy = _fernetRecord('old value');
      SharedPreferences.setMockInitialValues({'legacy': legacy});
      final reopened = LocalService();
      await reopened.init(legacyKey: _key);

      expect(reopened.readString('legacy'), 'old value');
    });

    test('round-trips a JSON object', () async {
      await storage.writeJson('profile', {'name': 'slate', 'count': 3});
      final read = storage.readJson('profile', (json) => json);
      expect(read, {'name': 'slate', 'count': 3});
    });

    test('returns null for missing keys', () {
      expect(storage.readString('missing'), isNull);
      expect(storage.containsKey('missing'), isFalse);
    });

    test('deletes values', () async {
      await storage.write('temp', 'value');
      await storage.delete('temp');
      expect(storage.containsKey('temp'), isFalse);
    });

    test('a v2 record with no second separator throws a format error', () async {
      SharedPreferences.setMockInitialValues({'bad': 'v2:only-one-part'});
      final reopened = LocalService();
      await reopened.init(legacyKey: _key);

      expect(() => reopened.readString('bad'), throwsA(isA<FormatException>()));
    });

    test('a v2 record with garbage ciphertext throws', () async {
      final validIv = IV.fromSecureRandom(16).base64;

      SharedPreferences.setMockInitialValues({'nonBase64': 'v2:$validIv:not-base64!!'});
      final nonBase64 = LocalService();
      await nonBase64.init(legacyKey: _key);
      expect(() => nonBase64.readString('nonBase64'), throwsA(isA<FormatException>()));

      final shortBlock = base64.encode(utf8.encode('short'));
      SharedPreferences.setMockInitialValues({'wrongBlock': 'v2:$validIv:$shortBlock'});
      final wrongBlock = LocalService();
      await wrongBlock.init(legacyKey: _key);
      expect(() => wrongBlock.readString('wrongBlock'), throwsA(isA<ArgumentError>()));
    });

    test('a v2 record that does not decrypt under the current key throws', () async {
      const fixedIv = 'AAECAwQFBgcICQoLDA0ODw==';
      const fixedCiphertext = 'EBESExQVFhcYGRobHB0eHw==';
      SharedPreferences.setMockInitialValues({'undecryptable': 'v2:$fixedIv:$fixedCiphertext'});
      final reopened = LocalService();
      await reopened.init(legacyKey: _key);

      expect(() => reopened.readString('undecryptable'), throwsA(isA<ArgumentError>()));
    });

    test('a legacy record that is not valid Fernet throws', () async {
      SharedPreferences.setMockInitialValues({'legacyBad': 'not-fernet-ciphertext-at-all'});
      final reopened = LocalService();
      await reopened.init(legacyKey: _key);

      expect(() => reopened.readString('legacyBad'), throwsA(isA<StateError>()));
    });

    test('readJson on an encrypted non-JSON payload throws a format error', () async {
      await storage.write('notJson', 'a-plain-string-not-json');

      expect(() => storage.readJson('notJson', (json) => json), throwsA(isA<FormatException>()));
    });

    test('a string list persists as per-element ciphertext', () async {
      await storage.write('tags', ['alpha', 'beta']);

      final raw = (await SharedPreferences.getInstance()).getStringList('tags');

      expect(raw, hasLength(2));
      expect(raw![0], startsWith('v2:'));
      expect(raw[1], startsWith('v2:'));
      expect(raw.join(), isNot(contains('alpha')));
      expect(raw.join(), isNot(contains('beta')));
    });

    group('a refusing platform store', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        SharedPreferencesStorePlatform.instance = _RefusingStore();
        storage = LocalService();
        await storage.init(legacyKey: _key);
      });

      test('a refused platform write surfaces as a StateError', () async {
        expect(storage.write('k', 'v'), throwsA(isA<StateError>()));
      });

      test('a refused platform delete surfaces as a StateError', () async {
        expect(storage.delete('k'), throwsA(isA<StateError>()));
      });
    });
  });

  group('v3 authenticated records (device key present)', () {
    late LocalService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalService();
      await storage.init(legacyKey: _key, deviceKey: _deviceKey());
    });

    test('encrypts and round-trips a string value under the device key', () async {
      await storage.write('language', 'ka');
      expect(storage.readString('language'), 'ka');
    });

    test('the stored form is v3 ciphertext, not plaintext', () async {
      await storage.write('language', 'a-plaintext-marker-no-ciphertext-contains');
      final raw = (await SharedPreferences.getInstance()).getString('language');
      expect(raw, isNotNull);
      expect(raw, startsWith('v3:'));
      expect(raw, isNot(contains('a-plaintext-marker-no-ciphertext-contains')));
    });

    test('a tampered v3 ciphertext byte fails authentication and throws', () async {
      await storage.write('language', 'ka');
      final raw = (await SharedPreferences.getInstance()).getString('language')!;
      final parts = raw.split(':');
      final cipherBytes = base64.decode(parts[2]);
      cipherBytes[0] ^= 0xff;
      final tampered = '${parts[0]}:${parts[1]}:${base64.encode(cipherBytes)}';

      SharedPreferences.setMockInitialValues({'language': tampered});
      final reopened = LocalService();
      await reopened.init(legacyKey: _key, deviceKey: _deviceKey());

      expect(() => reopened.readString('language'), throwsA(anything));
    });

    test('reading a v3 record without a device key throws StateError', () async {
      await storage.write('language', 'ka');
      final raw = (await SharedPreferences.getInstance()).getString('language')!;

      SharedPreferences.setMockInitialValues({'language': raw});
      final legacyOnly = LocalService();
      await legacyOnly.init(legacyKey: _key);

      expect(() => legacyOnly.readString('language'), throwsA(isA<StateError>()));
    });
  });

  group('migration', () {
    test('a v2 record and a legacy Fernet record both migrate to v3 and read back', () async {
      SharedPreferences.setMockInitialValues({
        'v2key': _v2Record('v2 value'),
        'fernetKey': _fernetRecord('fernet value'),
      });
      final storage = LocalService();
      await storage.init(legacyKey: _key, deviceKey: _deviceKey());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('v2key'), startsWith('v3:'));
      expect(prefs.getString('fernetKey'), startsWith('v3:'));
      expect(storage.readString('v2key'), 'v2 value');
      expect(storage.readString('fernetKey'), 'fernet value');
    });

    test('a corrupt v2 record survives migration untouched and still throws on read', () async {
      final validIv = IV.fromSecureRandom(16).base64;
      final corrupt = 'v2:$validIv:not-base64!!';
      SharedPreferences.setMockInitialValues({'bad': corrupt});
      final storage = LocalService();
      await storage.init(legacyKey: _key, deviceKey: _deviceKey());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bad'), corrupt);
      expect(() => storage.readString('bad'), throwsA(isA<FormatException>()));
    });

    test('running init twice migrates once, leaving the raw record unchanged', () async {
      SharedPreferences.setMockInitialValues({'v2key': _v2Record('value')});
      final deviceKey = _deviceKey();

      final first = LocalService();
      await first.init(legacyKey: _key, deviceKey: deviceKey);
      final afterFirst = (await SharedPreferences.getInstance()).getString('v2key');

      final second = LocalService();
      await second.init(legacyKey: _key, deviceKey: deviceKey);
      final afterSecond = (await SharedPreferences.getInstance()).getString('v2key');

      expect(afterSecond, afterFirst);
    });

    test('bools, ints, and doubles are untouched by migration', () async {
      SharedPreferences.setMockInitialValues({'flag': true, 'count': 3, 'ratio': 1.5});
      final storage = LocalService();
      await storage.init(legacyKey: _key, deviceKey: _deviceKey());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('flag'), isTrue);
      expect(prefs.getInt('count'), 3);
      expect(prefs.getDouble('ratio'), 1.5);
    });
  });
}

class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => false;

  @override
  Future<bool> remove(String key) async => false;
}
