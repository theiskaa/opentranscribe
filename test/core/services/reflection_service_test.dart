import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/reflect/fake_reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_exception.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Monday-first week boundary, injected so the service tests never depend on
/// the ambient Intl locale (utils/week has its own coverage).
DateTime mondayStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// An engine that fails the on-device guard, to prove the service refuses it.
class _OffDeviceEngine implements ReflectionEngine {
  @override
  String get id => 'off.device';
  @override
  bool get onDeviceOnly => false;
  @override
  Future<ReflectionAvailability> availability() async => const ReflectionAvailability.available();
  @override
  Future<String?> reflect({
    required List<ReflectionEntryInput> entries,
    required ReflectionStyle style,
    required String localeId,
  }) async => null;
}

void main() {
  const key = 'test-encryption-key-0123456789ab';
  // now is a Wednesday; the current week is 2026-07-27..08-02 (Monday-first).
  final now = DateTime(2026, 7, 29, 12);
  final lastWeek = DateTime(2026, 7, 20); // Monday of the just-closed week
  final twoWeeksAgo = DateTime(2026, 7, 13);

  late LocalService storage;
  late ReflectionStore store;
  late ReflectionSettings settings;
  late FakeReflectionEngine engine;
  late List<Entry> entries;
  late ReflectionService service;

  Entry withText(String id, DateTime createdAt, {String? text, String? title}) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: null,
    duration: const Duration(seconds: 1),
    title: title,
    transcript: text == null
        ? null
        : Transcript(
            fullText: text,
            segments: [
              TranscriptSegment(text: text, start: Duration.zero, end: const Duration(seconds: 1)),
            ],
            localeId: 'en-US',
            engineId: 'fake',
            createdAt: createdAt,
          ),
  );

  ReflectionService build() => ReflectionService(
    engine: engine,
    store: store,
    settings: settings,
    entries: () => entries,
    language: () => 'en',
    clock: () => now,
    weekOf: mondayStart,
  );

  setUpAll(() async {
    await initializeDateFormatting();
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
    store = ReflectionStore(storage);
    settings = ReflectionSettings(storage: storage);
    engine = FakeReflectionEngine();
    entries = [];
    service = build();
  });

  test('refuses an engine that is not on-device', () {
    expect(
      () => ReflectionService(
        engine: _OffDeviceEngine(),
        store: store,
        settings: settings,
        entries: () => entries,
        language: () => 'en',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  group('catchUp', () {
    test('reflects a closed week and stores its text, with the week material', () async {
      entries = [
        withText('a', DateTime(2026, 7, 22, 12), text: 'shipped the migration', title: 'log'),
      ];
      engine.output = 'a week about the migration';

      await service.catchUp();

      final r = store.read(lastWeek);
      expect(r, isNotNull);
      expect(r!.text, 'a week about the migration');
      expect(r.isSilent, isFalse);
      expect(r.voice, ReflectionVoice.literary);
      // The week's material crossed intact: weekday (Wed=3), title, text, style.
      expect(engine.lastEntries, [
        const ReflectionEntryInput(weekday: 3, text: 'shipped the migration', title: 'log'),
      ]);
      expect(engine.lastStyle, ReflectionStyle.defaults);
      expect(engine.lastLocaleId, 'en');
    });

    test('silence is stored as a quiet week and never re-run', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'groceries')];
      engine.silent = true;

      await service.catchUp();
      expect(store.read(lastWeek)!.isSilent, isTrue);

      // A second pass must not reflect a week already answered (even with silence).
      engine.silent = false;
      engine.reflectCalls = 0;
      await service.catchUp();
      expect(engine.reflectCalls, 0);
      expect(store.read(lastWeek)!.isSilent, isTrue);
    });

    test('an unavailable model leaves the week unreflected and does not throw', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.failReflect = true;

      await service.catchUp();

      expect(store.read(lastWeek), isNull); // retried next time, not a false silence
      expect(engine.reflectCalls, 1);
    });

    test('does nothing when Apple Intelligence is unavailable', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.availabilityResult = const ReflectionAvailability(
        ReflectionAvailabilityStatus.notEnabled,
      );

      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.all(), isEmpty);
    });

    test('does nothing when reflections are disabled', () async {
      await settings.setEnabled(false);
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];

      await service.catchUp();

      expect(engine.reflectCalls, 0);
    });

    test('does not reflect the current, still-open week', () async {
      entries = [withText('a', DateTime(2026, 7, 28, 12), text: 'today')]; // current week
      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.read(DateTime(2026, 7, 27)), isNull);
    });

    test('a closed week with no transcribed entries is skipped, not silenced', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12))]; // no transcript yet
      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.read(lastWeek), isNull); // still eligible once transcribed
    });

    test('an already-reflected week is left untouched', () async {
      await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'kept'));
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];

      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.read(lastWeek)!.text, 'kept');
    });

    test('catches up every missed closed week', () async {
      entries = [
        withText('a', DateTime(2026, 7, 22, 12), text: 'last week'),
        withText('b', DateTime(2026, 7, 15, 12), text: 'two weeks ago'),
      ];

      await service.catchUp();

      expect(engine.reflectCalls, 2);
      expect(store.read(lastWeek), isNotNull);
      expect(store.read(twoWeeksAgo), isNotNull);
    });

    test('is single-flighted: a concurrent call is a no-op', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      final gate = Completer<void>();
      engine.gate = gate.future;

      final first = service.catchUp(); // parks in reflect on the gate
      final second = service.catchUp(); // guard bails synchronously
      gate.complete();
      await Future.wait([first, second]);

      expect(engine.reflectCalls, 1);
    });

    test('emits reflectionsChanged when a reflection is written', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      final events = <void>[];
      final sub = service.reflectionsChanged.listen(events.add);

      await service.catchUp();
      await Future<void>.delayed(Duration.zero);

      expect(events, isNotEmpty);
      await sub.cancel();
    });

    test('caps a heavy week under the model context window, keeping every day', () async {
      final big = 'x' * 5000;
      entries = [
        withText('a', DateTime(2026, 7, 20, 9), text: big),
        withText('b', DateTime(2026, 7, 22, 9), text: big),
        withText('c', DateTime(2026, 7, 24, 9), text: big),
      ]; // 15000 Latin chars (~3750 tokens), over the ~2000-token budget
      await service.catchUp();

      final sent = engine.lastEntries!;
      expect(sent.length, 3); // no day dropped
      final total = sent.fold<int>(0, (sum, e) => sum + e.text.length);
      expect(total, lessThanOrEqualTo(8000)); // 2000 tokens at ~4 chars each
    });

    test('caps a heavy CJK week far tighter, near one token per character', () async {
      // A character cap sized for Latin would pass ~8000 CJK chars straight
      // into a context overflow, which the engine would report as silence and
      // the service would store as a permanent false quiet week.
      final big = '日' * 3000;
      entries = [
        withText('a', DateTime(2026, 7, 20, 9), text: big),
        withText('b', DateTime(2026, 7, 22, 9), text: big),
      ]; // ~6000 tokens, over budget despite being under 8000 chars
      await service.catchUp();

      final sent = engine.lastEntries!;
      expect(sent.length, 2);
      final total = sent.fold<int>(0, (sum, e) => sum + e.text.length);
      expect(total, lessThanOrEqualTo(2000)); // 2000 tokens at ~1 char each
    });

    test('the cap trims on a code-point boundary, never through a surrogate pair', () async {
      final big = '😀' * 9000; // 2 UTF-16 units per emoji, over the token budget
      entries = [withText('a', DateTime(2026, 7, 20, 9), text: big)];
      await service.catchUp();

      final sent = engine.lastEntries!.single.text;
      expect(sent.length, lessThan(big.length)); // actually trimmed
      expect(sent.length.isEven, isTrue); // whole emoji only
      // A split pair would leave an unpaired surrogate at the cut, which a
      // decode-encode round trip would rewrite; intact text round-trips as-is.
      final last = sent.codeUnitAt(sent.length - 1);
      expect(last >= 0xDC00 && last <= 0xDFFF, isTrue); // a proper trail unit
      expect(String.fromCharCodes(sent.runes), sent);
    });

    test('a language change that shifts the week boundary does not re-reflect history', () async {
      // Ten Sunday-keyed weeks reflected under en; the user switches to de
      // (Monday-first). The done-check must match by range overlap, or every
      // stored week re-reflects into overlapping duplicates.
      final sundayWeek = DateTime(2026, 7, 19);
      await store.save(Reflection(weekStart: sundayWeek, generatedAt: now, text: 'kept'));
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      final deService = ReflectionService(
        engine: engine,
        store: store,
        settings: settings,
        entries: () => entries,
        language: () => 'de',
        clock: () => now,
      );

      await deService.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.all().length, 1); // no Monday-keyed duplicate
      expect(store.read(sundayWeek)!.text, 'kept');
    });

    test('stores the voice from generation start, not a change made mid-run', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      final gate = Completer<void>();
      engine.gate = gate.future;

      final run = service.catchUp();
      // Bounded so a regression fails fast instead of riding the suite timeout.
      var spins = 0;
      while (engine.reflectCalls == 0) {
        expect(++spins, lessThan(1000), reason: 'catchUp never reached reflect');
        await Future<void>.delayed(Duration.zero); // wait until parked in reflect
      }
      await settings.setVoice(ReflectionVoice.sparse); // change mid-generation
      gate.complete();
      await run;

      // The captured style wins: the text was generated as literary.
      expect(store.read(lastWeek)!.voice, ReflectionVoice.literary);
    });

    test('buckets by the app language week, not the ambient Intl locale', () async {
      // No injected weekOf: the service resolves the boundary from `language`.
      Intl.defaultLocale = 'en_US'; // ambient would bucket Sunday-first
      final deService = ReflectionService(
        engine: engine,
        store: store,
        settings: settings,
        entries: () => entries,
        language: () => 'de', // Monday-first
        clock: () => now,
      );
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];

      await deService.catchUp();

      expect(store.read(DateTime(2026, 7, 20)), isNotNull); // Monday-first week
      expect(store.read(DateTime(2026, 7, 19)), isNull); // not the Sunday-first week
    });
  });

  group('regenerate', () {
    test('replaces a stored reflection in the current style', () async {
      await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'old'));
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.output = 'new';

      await service.regenerate(lastWeek);

      expect(store.read(lastWeek)!.text, 'new');
      expect(engine.reflectCalls, 1);
    });

    test('a week with no material regenerates to an honest silence', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12))]; // no transcript
      await service.regenerate(lastWeek);

      expect(engine.reflectCalls, 0);
      expect(store.read(lastWeek)!.isSilent, isTrue);
    });

    test('an unavailable model surfaces, so the caller can retry', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.failReflect = true;

      await expectLater(service.regenerate(lastWeek), throwsA(isA<ReflectionUnavailable>()));
    });

    test('keys off the stored week, not the current locale boundary', () async {
      // A reflection stored under a Sunday-first week (07-19..07-25).
      final sundayWeek = DateTime(2026, 7, 19);
      await store.save(Reflection(weekStart: sundayWeek, generatedAt: now, text: 'old'));
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')]; // in that range
      engine.output = 'new';
      // A service whose locale (de) buckets Monday-first: regenerate must NOT
      // re-key the stored Sunday week to a Monday one.
      final deService = ReflectionService(
        engine: engine,
        store: store,
        settings: settings,
        entries: () => entries,
        language: () => 'de',
        clock: () => now,
      );

      await deService.regenerate(sundayWeek);

      expect(store.read(sundayWeek)!.text, 'new'); // replaced in place
      expect(store.read(DateTime(2026, 7, 20)), isNull); // not re-bucketed to Monday
    });
  });

  test('deleteReflection removes a week and emits', () async {
    await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'x'));
    final events = <void>[];
    final sub = service.reflectionsChanged.listen(events.add);

    await service.deleteReflection(lastWeek);
    await Future<void>.delayed(Duration.zero);

    expect(store.read(lastWeek), isNull);
    expect(events, isNotEmpty);
    await sub.cancel();
  });

  test('deleteReflection keys off the stored week, not the current locale boundary', () async {
    // A Sunday-keyed reflection (stored under en) deleted after a switch to de
    // (Monday-first): re-bucketing would target the previous Monday's key and
    // silently miss, leaving the row undeletable.
    final sundayWeek = DateTime(2026, 7, 19);
    await store.save(Reflection(weekStart: sundayWeek, generatedAt: now, text: 'x'));
    final deService = ReflectionService(
      engine: engine,
      store: store,
      settings: settings,
      entries: () => entries,
      language: () => 'de',
      clock: () => now,
    );

    await deService.deleteReflection(sundayWeek);

    expect(store.read(sundayWeek), isNull);
    expect(store.all(), isEmpty);
  });
}
