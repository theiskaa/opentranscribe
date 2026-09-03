import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/hints.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  late LocalService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
  });

  test('a fresh store has seen nothing', () {
    expect(Hints.isSeen(storage, Hints.entryMenu), isFalse);
  });

  test('markSeen persists across a fresh reader', () async {
    await Hints.markSeen(storage, Hints.entryMenu);
    expect(Hints.isSeen(storage, Hints.entryMenu), isTrue);

    final reopened = LocalService();
    await reopened.init(legacyKey: key);
    expect(Hints.isSeen(reopened, Hints.entryMenu), isTrue);
  });

  test('an undecryptable stored value fails safe to not seen', () async {
    await Hints.markSeen(storage, Hints.entryMenu);
    final other = LocalService();
    await other.init(legacyKey: 'another-encryption-key-012345678');
    expect(Hints.isSeen(other, Hints.entryMenu), isFalse);
  });
}
