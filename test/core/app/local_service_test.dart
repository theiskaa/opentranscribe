import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
