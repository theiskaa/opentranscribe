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

  ReflectionService build({Duration? reflectTimeout}) => ReflectionService(
    engine: engine,
    store: store,
    settings: settings,
    entries: () => entries,
    language: () => 'en',
    clock: () => now,
    weekOf: mondayStart,
    reflectTimeout: reflectTimeout,
  );

  Future<void> untilParkedInReflect() async {
    var spins = 0;
    while (engine.reflectCalls == 0) {
      expect(++spins, lessThan(1000), reason: 'never reached reflect');
      await Future<void>.delayed(Duration.zero);
    }
  }

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
    // The feature has been present since long before the test weeks, so the
    // no-backfill floor never interferes; the floor group covers it directly.
    await settings.setFloor(DateTime(2026, 6, 8));
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

    test('caps a heavy Thai week as tight as CJK, near one token per character', () async {
      final big = 'ก' * 3000;
      entries = [
        withText('a', DateTime(2026, 7, 20, 9), text: big),
        withText('b', DateTime(2026, 7, 22, 9), text: big),
      ];
      await service.catchUp();

      final sent = engine.lastEntries!;
      expect(sent.length, 2);
      final total = sent.fold<int>(0, (sum, e) => sum + e.text.length);
      expect(total, lessThanOrEqualTo(2000));
    });

    test('caps a heavy Cyrillic week near two characters per token', () async {
      final big = 'д' * 5000;
      entries = [
        withText('a', DateTime(2026, 7, 20, 9), text: big),
        withText('b', DateTime(2026, 7, 22, 9), text: big),
      ];
      await service.catchUp();

      final sent = engine.lastEntries!;
      expect(sent.length, 2);
      final total = sent.fold<int>(0, (sum, e) => sum + e.text.length);
      expect(total, lessThanOrEqualTo(4000));
    });

    test('titles spend from the prompt budget too, since the prompt carries them', () async {
      final text = 'x' * 2600;
      final title = 't' * 400;
      entries = [
        withText('a', DateTime(2026, 7, 20, 9), text: text, title: title),
        withText('b', DateTime(2026, 7, 22, 9), text: text, title: title),
        withText('c', DateTime(2026, 7, 24, 9), text: text, title: title),
      ];
      await service.catchUp();

      final sent = engine.lastEntries!;
      expect(sent.length, 3);
      expect(sent.map((e) => e.title), everyElement(title));
      final total = sent.fold<int>(0, (sum, e) => sum + e.text.length + e.title!.length);
      expect(total, lessThanOrEqualTo(8000));
      expect(sent.first.text.length, lessThan(text.length));
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
      await untilParkedInReflect();
      await settings.setVoice(ReflectionVoice.sparse); // change mid-generation
      gate.complete();
      await run;

      // The captured style wins: the text was generated as literary.
      expect(store.read(lastWeek)!.voice, ReflectionVoice.literary);
    });

    test('a generation that never returns times out, freeing the next run to retry', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.gate = Completer<void>().future;
      service = build(reflectTimeout: const Duration(milliseconds: 20));

      await service.catchUp();
      expect(store.read(lastWeek), isNull);

      engine.gate = null;
      await service.catchUp();
      expect(store.read(lastWeek), isNotNull);
    });

    test('disabling mid-run stops the remaining backlog', () async {
      entries = [
        withText('a', DateTime(2026, 7, 22, 12), text: 'last week'),
        withText('b', DateTime(2026, 7, 15, 12), text: 'two weeks ago'),
      ];
      final gate = Completer<void>();
      engine.gate = gate.future;

      final run = service.catchUp();
      await untilParkedInReflect();
      await settings.setEnabled(false);
      gate.complete();
      await run;

      expect(engine.reflectCalls, 1);
      expect(store.read(twoWeeksAgo), isNull);
    });

    test('a regenerate finishing mid-catch-up is not overwritten by the loop', () async {
      entries = [
        withText('a', DateTime(2026, 7, 22, 12), text: 'last week'),
        withText('b', DateTime(2026, 7, 15, 12), text: 'two weeks ago'),
      ];
      final gate = Completer<void>();
      engine.gate = gate.future;

      final run = service.catchUp();
      await untilParkedInReflect();
      engine.gate = null;
      engine.output = 'the user version';
      await service.regenerate(twoWeeksAgo);
      engine.output = 'the loop version';
      gate.complete();
      await run;

      expect(engine.reflectCalls, 2);
      expect(store.read(twoWeeksAgo)!.text, 'the user version');
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

  group('deletion interplay', () {
    // The decided story: a reflection is an immutable record of the week as it
    // was heard, and the user's per-week delete is the only eraser, in BOTH
    // directions: deleting entries never erases the reflection, and deleting
    // the reflection is never undone by the next catch-up.

    test('a deleted reflection stays deleted while its entries live on', () async {
      // The confirm sheet says "cannot be undone"; without the tombstone the
      // next catch-up would see an uncovered week with material and quietly
      // write a fresh reflection the user never asked for.
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      await service.catchUp();
      expect(store.read(lastWeek), isNotNull);

      await service.deleteReflection(lastWeek);
      engine.reflectCalls = 0;
      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.read(lastWeek), isNull);
    });

    test('a language change cannot resurrect a deleted week', () async {
      // Deleted under a Sunday-first boundary; a Monday-first catch-up must
      // not treat the shifted candidate as a fresh, uncovered week.
      final sundayWeek = DateTime(2026, 7, 19);
      await store.save(Reflection(weekStart: sundayWeek, generatedAt: now, text: 'x'));
      await service.deleteReflection(sundayWeek);
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
      expect(store.all(), isEmpty);
    });

    test('a delete landed mid-generation wins over the in-flight save', () async {
      await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'old'));
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      final gate = Completer<void>();
      engine.gate = gate.future;

      final run = service.regenerate(lastWeek);
      await untilParkedInReflect();
      await service.deleteReflection(lastWeek);
      gate.complete();
      await run;

      expect(store.read(lastWeek), isNull);
      expect(store.deletedWeeks(), [lastWeek]);
    });

    test('regenerating an erased week saves through its own tombstone', () async {
      await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'old'));
      await service.deleteReflection(lastWeek);
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.output = 'fresh';

      await service.regenerate(lastWeek);

      expect(store.read(lastWeek)!.text, 'fresh');
      expect(store.deletedWeeks(), isEmpty);
    });

    test('deleting a reflected week\'s entries later leaves its reflection untouched', () async {
      await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'as heard'));
      // That week's own entries are gone, but another week still has material,
      // so the pin survives a real catch-up pass rather than an empty loop.
      entries = [withText('b', DateTime(2026, 7, 15, 12), text: 'two weeks ago')];

      await service.catchUp();

      expect(engine.reflectCalls, 1);
      expect(store.read(twoWeeksAgo), isNotNull);
      expect(store.read(lastWeek)!.text, 'as heard');
    });

    test('a week emptied to zero regenerates to an honest silence, without the model', () async {
      await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'as heard'));
      entries = []; // the user asked to re-run a week that no longer holds anything

      await service.regenerate(lastWeek);

      expect(engine.reflectCalls, 0);
      expect(store.read(lastWeek)!.isSilent, isTrue);
    });

    test('an unreflected week whose entries were all deleted simply never reflects', () async {
      entries = []; // material existed once, gone before any catch-up ran

      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.all(), isEmpty);
    });
  });

  group('no-backfill floor', () {
    test('weeks that closed before the feature first ran are never reflected', () async {
      await settings.setFloor(DateTime(2026, 7, 27)); // first run in the current week
      entries = [
        withText('a', DateTime(2026, 7, 22, 12), text: 'last week'),
        withText('b', DateTime(2026, 7, 15, 12), text: 'two weeks ago'),
      ];

      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.all(), isEmpty);
    });

    test('the feature-start week itself reflects once it closes', () async {
      await settings.setFloor(lastWeek); // first run during the now-closed week
      entries = [
        withText('a', DateTime(2026, 7, 22, 12), text: 'that week'),
        withText('b', DateTime(2026, 7, 15, 12), text: 'before the feature'),
      ];

      await service.catchUp();

      expect(engine.reflectCalls, 1);
      expect(store.read(lastWeek), isNotNull);
      expect(store.read(twoWeeksAgo), isNull);
    });

    test('the floor is recorded on first run, once, and holds fresh installs to it', () async {
      // A fresh install: no stored floor, but older weeks already hold entries.
      SharedPreferences.setMockInitialValues({});
      storage = LocalService();
      await storage.init(encryptionKey: key);
      store = ReflectionStore(storage);
      settings = ReflectionSettings(storage: storage);
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'pre-feature week')];
      service = build();

      await service.catchUp();

      // First run recorded the current week as the floor and reflected nothing.
      expect(settings.floor, DateTime(2026, 7, 27));
      expect(engine.reflectCalls, 0);
      expect(store.all(), isEmpty);

      // A later run (clock a week on) leaves the recorded floor untouched.
      final later = ReflectionService(
        engine: engine,
        store: store,
        settings: settings,
        entries: () => entries,
        language: () => 'en',
        clock: () => DateTime(2026, 8, 5, 12),
        weekOf: mondayStart,
      );
      await later.catchUp();
      expect(settings.floor, DateTime(2026, 7, 27));
    });

    test('the floor is recorded even while Apple Intelligence is unavailable', () async {
      // The floor marks when the FEATURE first ran, not when the model first
      // answered: a user journaling with AI off must still get those weeks
      // filled once it comes on, not floored away at the first answer.
      SharedPreferences.setMockInitialValues({});
      storage = LocalService();
      await storage.init(encryptionKey: key);
      store = ReflectionStore(storage);
      settings = ReflectionSettings(storage: storage);
      engine.availabilityResult = const ReflectionAvailability(
        ReflectionAvailabilityStatus.notEnabled,
      );
      entries = [withText('a', DateTime(2026, 7, 29, 12), text: 'with AI off')];
      service = build();

      await service.catchUp();
      expect(settings.floor, DateTime(2026, 7, 27)); // recorded despite the gate

      // The week journaled in the gap fills once the model answers.
      engine.availabilityResult = const ReflectionAvailability.available();
      final later = ReflectionService(
        engine: engine,
        store: store,
        settings: settings,
        entries: () => entries,
        language: () => 'en',
        clock: () => DateTime(2026, 8, 5, 12),
        weekOf: mondayStart,
      );
      await later.catchUp();
      expect(store.read(DateTime(2026, 7, 27)), isNotNull);
    });

    test('a first-day-of-week shift cannot pull a pre-feature week over the floor', () async {
      await settings.setFloor(DateTime(2026, 7, 19)); // Sunday-first floor (en)
      entries = [
        withText('a', DateTime(2026, 7, 8, 12), text: 'fully before the floor'),
        withText('b', DateTime(2026, 7, 15, 12), text: 'week straddling the floor day'),
      ];
      // Monday-first bucketing (de): weeks Jul 6-12 (ends before the floor day,
      // skipped) and Jul 13-19 (overlaps the floor day, in-feature).
      final deService = ReflectionService(
        engine: engine,
        store: store,
        settings: settings,
        entries: () => entries,
        language: () => 'de',
        clock: () => now,
      );

      await deService.catchUp();

      expect(engine.reflectCalls, 1);
      expect(store.read(DateTime(2026, 7, 13)), isNotNull);
      expect(store.read(DateTime(2026, 7, 6)), isNull);
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

    test('a timed-out regenerate surfaces as unavailable, so the caller can retry', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.gate = Completer<void>().future;
      service = build(reflectTimeout: const Duration(milliseconds: 20));

      await expectLater(service.regenerate(lastWeek), throwsA(isA<ReflectionUnavailable>()));
      expect(store.read(lastWeek), isNull);
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

  group('surface pass-throughs', () {
    test('journaledWeekStarts buckets by the injected week boundary', () {
      entries = [
        withText('a', DateTime(2026, 7, 22, 9), text: 'x'),
        withText('b', DateTime(2026, 7, 15, 9), text: 'y'),
      ];
      expect(service.journaledWeekStarts(), {lastWeek, twoWeeksAgo});
    });

    test('journaledWeekStarts ignores weeks holding only untranscribed entries', () {
      // The catch-up has nothing to read there (_inputsFor drops empty
      // transcripts), so a waiting page would promise a fill that never comes.
      entries = [
        withText('a', DateTime(2026, 7, 22, 9), text: 'x'),
        withText('b', DateTime(2026, 7, 15, 9)),
      ];
      expect(service.journaledWeekStarts(), {lastWeek});
    });

    test('currentWeekStart is the open week under the same boundary', () {
      expect(service.currentWeekStart(), DateTime(2026, 7, 27));
    });

    test('deletedWeeks mirrors the store tombstones', () async {
      await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'x'));
      await service.deleteReflection(lastWeek);
      expect(service.deletedWeeks(), [lastWeek]);
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
