import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:opentranscribe/core/app/local_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'test-encryption-key-0123456789ab';

  late LocalService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
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
    final derived = Key.fromUtf8(key.substring(0, 32));
    final fernet = Encrypter(
      Fernet(Key.fromUtf8(base64Url.encode(derived.bytes).substring(0, 32))),
    );
    final legacy = fernet.encrypt('old value').base64;
    SharedPreferences.setMockInitialValues({'legacy': legacy});
    final reopened = LocalService();
    await reopened.init(encryptionKey: key);

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
    await reopened.init(encryptionKey: key);

    expect(() => reopened.readString('bad'), throwsA(isA<FormatException>()));
  });

  test('a v2 record with garbage ciphertext throws', () async {
    final validIv = IV.fromSecureRandom(16).base64;

    SharedPreferences.setMockInitialValues({'nonBase64': 'v2:$validIv:not-base64!!'});
    final nonBase64 = LocalService();
    await nonBase64.init(encryptionKey: key);
    expect(() => nonBase64.readString('nonBase64'), throwsA(isA<FormatException>()));

    final shortBlock = base64.encode(utf8.encode('short'));
    SharedPreferences.setMockInitialValues({'wrongBlock': 'v2:$validIv:$shortBlock'});
    final wrongBlock = LocalService();
    await wrongBlock.init(encryptionKey: key);
    expect(() => wrongBlock.readString('wrongBlock'), throwsA(isA<ArgumentError>()));
  });

  test('a v2 record that does not decrypt under the current key throws', () async {
    const fixedIv = 'AAECAwQFBgcICQoLDA0ODw==';
    const fixedCiphertext = 'EBESExQVFhcYGRobHB0eHw==';
    SharedPreferences.setMockInitialValues({'undecryptable': 'v2:$fixedIv:$fixedCiphertext'});
    final reopened = LocalService();
    await reopened.init(encryptionKey: key);

    expect(() => reopened.readString('undecryptable'), throwsA(isA<ArgumentError>()));
  });

  test('a legacy record that is not valid Fernet throws', () async {
    SharedPreferences.setMockInitialValues({'legacyBad': 'not-fernet-ciphertext-at-all'});
    final reopened = LocalService();
    await reopened.init(encryptionKey: key);

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
      await storage.init(encryptionKey: key);
    });

    test('a refused platform write surfaces as a StateError', () async {
      expect(storage.write('k', 'v'), throwsA(isA<StateError>()));
    });

    test('a refused platform delete surfaces as a StateError', () async {
      expect(storage.delete('k'), throwsA(isA<StateError>()));
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
