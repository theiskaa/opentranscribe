import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:opentranscribe/core/app/local_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
  });

  test('encrypts and round-trips a string value', () async {
    await storage.write('language', 'ka');
    expect(storage.readString('language'), 'ka');
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
