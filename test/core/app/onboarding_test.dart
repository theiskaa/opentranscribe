import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/app/onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  late LocalService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
  });

  test('defaults to not done', () {
    expect(Onboarding.isDone(storage), isFalse);
  });

  test('markDone persists across a fresh reader', () async {
    await Onboarding.markDone(storage);
    expect(Onboarding.isDone(storage), isTrue);

    final reopened = LocalService();
    await reopened.init(encryptionKey: key);
    expect(Onboarding.isDone(reopened), isTrue);
  });

  test('an undecryptable stored value fails safe to not done', () async {
    await Onboarding.markDone(storage);
    final other = LocalService();
    await other.init(encryptionKey: 'a-completely-different-key-000000');
    expect(Onboarding.isDone(other), isFalse);
  });
}
