import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';

  late LocalService storage;
  late ReflectionStore store;

  Reflection reflection(DateTime weekStart, {String? text}) => Reflection(
    weekStart: weekStart,
    generatedAt: DateTime.utc(2026, 8, 3),
    text: text,
    voice: ReflectionVoice.literary,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
    store = ReflectionStore(storage);
  });

  test('saves and reads a reflection back by its week', () async {
    final r = reflection(DateTime(2026, 7, 20), text: 'a week about work');
    await store.save(r);

    expect(store.read(DateTime(2026, 7, 20)), r);
  });

  test('read returns null for a week with no reflection', () {
    expect(store.read(DateTime(2026, 1, 5)), isNull);
  });

  test('read matches on the civil date, ignoring a time-of-day', () async {
    await store.save(reflection(DateTime(2026, 7, 20), text: 'x'));

    // A caller that hands in an instant on the same day still resolves it.
    expect(store.read(DateTime(2026, 7, 20, 14, 30)), isNotNull);
  });

  test('a silent week persists and reads back as silence', () async {
    await store.save(reflection(DateTime(2026, 7, 20)));

    final back = store.read(DateTime(2026, 7, 20));
    expect(back, isNotNull);
    expect(back!.isSilent, isTrue);
  });

  test('all returns reflections newest week first', () async {
    await store.save(reflection(DateTime(2026, 7, 6), text: 'old'));
    await store.save(reflection(DateTime(2026, 7, 20), text: 'new'));
    await store.save(reflection(DateTime(2026, 7, 13), text: 'mid'));

    final weeks = store.all().map((r) => r.weekKey).toList();

    expect(weeks, ['2026-07-20', '2026-07-13', '2026-07-06']);
  });

  test('delete removes a week', () async {
    await store.save(reflection(DateTime(2026, 7, 20), text: 'gone'));
    await store.delete(DateTime(2026, 7, 20));

    expect(store.read(DateTime(2026, 7, 20)), isNull);
    expect(store.all(), isEmpty);
  });

  test('all() skips a corrupt record and keeps the valid ones', () async {
    await store.save(reflection(DateTime(2026, 7, 20), text: 'good'));
    await storage.writeJson('reflection:bad', {'nope': 1});

    expect(store.all().map((r) => r.weekKey).toList(), ['2026-07-20']);
    expect(store.read(DateTime(2026, 7, 20)), isNotNull);
  });

  test('an undecryptable raw value under the prefix is skipped, not fatal', () async {
    SharedPreferences.setMockInitialValues({'reflection:junk': 'not-ciphertext'});
    storage = LocalService();
    await storage.init(encryptionKey: key);
    store = ReflectionStore(storage);
    await store.save(reflection(DateTime(2026, 7, 20), text: 'good'));

    expect(store.all().map((r) => r.weekKey).toList(), ['2026-07-20']);
  });
}
