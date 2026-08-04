import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DeleteFails extends LocalService {
  @override
  Future<bool> delete(String key) async => throw StateError('delete refused');
}

void main() {
  const key = 'test-encryption-key-0123456789ab';

  late LocalService storage;
  late ReflectionStore store;

  Reflection reflection(DateTime periodStart, {String? text}) => Reflection(
    periodStart: periodStart,
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

    final weeks = store.all().map((r) => r.periodKey).toList();

    expect(weeks, ['2026-07-20', '2026-07-13', '2026-07-06']);
  });

  test('delete removes a week and leaves a tombstone', () async {
    await store.save(reflection(DateTime(2026, 7, 20), text: 'gone'));
    await store.delete(DateTime(2026, 7, 20));

    expect(store.read(DateTime(2026, 7, 20)), isNull);
    expect(store.all(), isEmpty);
    expect(store.deletedWeeks(), [DateTime(2026, 7, 20)]);
  });

  test('save clears a week\'s tombstone, so marker and row never coexist', () async {
    await store.save(reflection(DateTime(2026, 7, 20), text: 'first'));
    await store.delete(DateTime(2026, 7, 20));
    await store.save(reflection(DateTime(2026, 7, 20), text: 'again'));

    expect(store.deletedWeeks(), isEmpty);
    expect(store.read(DateTime(2026, 7, 20))!.text, 'again');
  });

  test(
    'save writes the row before clearing the tombstone, so a failure cannot erase both',
    () async {
      await store.save(reflection(DateTime(2026, 7, 20), text: 'first'));
      await store.delete(DateTime(2026, 7, 20));
      final failing = _DeleteFails();
      await failing.init(encryptionKey: key);
      final failingStore = ReflectionStore(failing);

      await expectLater(
        failingStore.save(reflection(DateTime(2026, 7, 20), text: 'again')),
        throwsStateError,
      );

      expect(store.read(DateTime(2026, 7, 20))!.text, 'again');
      expect(store.deletedWeeks(), [DateTime(2026, 7, 20)]);
    },
  );

  test('all() skips a corrupt record and keeps the valid ones', () async {
    await store.save(reflection(DateTime(2026, 7, 20), text: 'good'));
    await storage.writeJson('reflection:bad', {'nope': 1});

    expect(store.all().map((r) => r.periodKey).toList(), ['2026-07-20']);
    expect(store.read(DateTime(2026, 7, 20)), isNotNull);
  });

  test('an undecryptable raw value under the prefix is skipped, not fatal', () async {
    SharedPreferences.setMockInitialValues({'reflection:junk': 'not-ciphertext'});
    storage = LocalService();
    await storage.init(encryptionKey: key);
    store = ReflectionStore(storage);
    await store.save(reflection(DateTime(2026, 7, 20), text: 'good'));

    expect(store.all().map((r) => r.periodKey).toList(), ['2026-07-20']);
  });

  Reflection periodReflection(DateTime start, ReflectionPeriod period, {String? text}) =>
      Reflection(
        periodStart: start,
        generatedAt: DateTime.utc(2026, 8, 3),
        period: period,
        text: text,
      );

  test('a day, its week, and its month on the same start do not collide', () async {
    final start = DateTime(2026, 8, 3);
    await store.save(periodReflection(start, ReflectionPeriod.daily, text: 'day'));
    await store.save(periodReflection(start, ReflectionPeriod.weekly, text: 'week'));
    await store.save(periodReflection(start, ReflectionPeriod.monthly, text: 'month'));

    expect(store.read(start, period: ReflectionPeriod.daily)!.text, 'day');
    expect(store.read(start)!.text, 'week');
    expect(store.read(start, period: ReflectionPeriod.monthly)!.text, 'month');
    expect(store.all().length, 3);
  });

  test('deleting one period leaves the others and tombstones only that period', () async {
    final start = DateTime(2026, 8, 3);
    await store.save(periodReflection(start, ReflectionPeriod.daily, text: 'day'));
    await store.save(periodReflection(start, ReflectionPeriod.weekly, text: 'week'));

    await store.delete(start, period: ReflectionPeriod.daily);

    expect(store.read(start, period: ReflectionPeriod.daily), isNull);
    expect(store.read(start)!.text, 'week');
    expect(store.deletedWeeks(), isEmpty);
    expect(store.deletedRefs().single, (period: ReflectionPeriod.daily, start: start));
  });
}
