import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:reflections/reflections.dart';
import 'package:reflections/testing.dart';

import '../../support/reflection_fixtures.dart';

class _OffDeviceEngine implements ReflectionEngine {
  @override
  String get id => 'off.device';
  @override
  bool get onDeviceOnly => false;
  @override
  Future<ReflectionAvailability> availability() async => const ReflectionAvailability.available();
  @override
  Future<String?> reflect({
    required ReflectionPeriod period,
    required List<ReflectionEntryInput> entries,
    required ReflectionStyle style,
    required String localeId,
  }) async => null;
}

void main() {
  final now = DateTime(2026, 7, 29, 12);
  final lastWeek = DateTime(2026, 7, 20);
  final twoWeeksAgo = DateTime(2026, 7, 13);

  late LocalService storage;
  late ReflectionStore store;
  late ReflectionSettings settings;
  late FakeReflectionEngine engine;
  late List<Entry> entries;
  late ReflectionService service;

  ReflectionService build({
    String language = 'en',
    DateTime Function()? clock,
    DateTime Function(DateTime)? weekOf = mondayStart,
    Duration? reflectTimeout,
  }) => ReflectionService(
    engine: engine,
    store: store,
    settings: settings,
    entries: () => entries,
    language: () => language,
    clock: clock ?? () => now,
    weekOf: weekOf,
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
    final fresh = await reflectionStorage();
    storage = fresh.storage;
    store = fresh.store;
    settings = fresh.settings;
    await settings.setFloorFor(ReflectionPeriod.weekly, DateTime(2026, 6, 8));
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
      expect(engine.lastEntries, [
        ReflectionEntryInput(
          date: DateTime(2026, 7, 22),
          text: 'shipped the migration',
          title: 'log',
        ),
      ]);
      expect(engine.lastStyle, ReflectionStyle.defaults);
      expect(engine.lastLocaleId, 'en');
      expect(engine.lastPeriod, ReflectionPeriod.weekly);
    });

    test('inputs read the hand edit, and an edit over silence is material', () async {
      entries = [
        withText(
          'a',
          DateTime(2026, 7, 22, 12),
          text: 'wrong words',
        ).withRevisions([Revision(text: 'right words', at: now)]),
        withText(
          'b',
          DateTime(2026, 7, 23, 12),
          text: '',
        ).withRevisions([Revision(text: 'typed in', at: now)]),
      ];
      engine.output = 'a week';

      await service.catchUp();

      expect(engine.lastEntries!.map((e) => e.text), ['right words', 'typed in']);
    });

    test('silence is stored as a quiet week and never re-run', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'groceries')];
      engine.silent = true;

      await service.catchUp();
      expect(store.read(lastWeek)!.isSilent, isTrue);

      engine.silent = false;
      engine.reflectCalls = 0;
      await service.catchUp();
      expect(engine.reflectCalls, 0);
      expect(store.read(lastWeek)!.isSilent, isTrue);
    });

    test('an unavailable model leaves the week unreflected for a later retry, '
        'and does not throw', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.failReflect = true;

      await service.catchUp();

      expect(store.read(lastWeek), isNull);
      expect(engine.reflectCalls, 1);
    });

    test('does nothing when the on-device model is unavailable', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.availabilityResult = const ReflectionAvailability(
        ReflectionAvailabilityStatus.notEnabled,
      );

      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.all(), isEmpty);
    });

    test('does nothing when reflections are disabled', () async {
      await settings.setEnabledFor(ReflectionPeriod.weekly, false);
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];

      await service.catchUp();

      expect(engine.reflectCalls, 0);
    });

    test('does not reflect the current, still-open week', () async {
      entries = [withText('a', DateTime(2026, 7, 28, 12), text: 'today')];
      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.read(DateTime(2026, 7, 27)), isNull);
    });

    test('a closed week with no transcribed entries is skipped, not silenced, '
        'staying eligible once transcribed', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12))];
      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.read(lastWeek), isNull);
    });

    test('an already-reflected week is left untouched', () async {
      await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'kept'));
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

      final first = service.catchUp();
      final second = service.catchUp();
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
      ];
      await service.catchUp();

      final sent = engine.lastEntries!;
      expect(sent.length, 3);
      final total = sent.fold<int>(0, (sum, e) => sum + e.text.length);
      expect(total, lessThanOrEqualTo(8000));
    });

    test('caps a heavy CJK week far tighter, near one token per character, '
        'so an overflow cannot be stored as a permanent false quiet week', () async {
      final big = '日' * 3000;
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

    test('a title alone larger than its entry\'s whole share is trimmed too, '
        'never surviving whole into an overflowing prompt', () async {
      final title = 'a' * 5000;
      entries = [
        withText('a', DateTime(2026, 7, 20, 9), text: 'x', title: title),
        withText('b', DateTime(2026, 7, 22, 9), text: 'x', title: title),
      ];
      await service.catchUp();

      final sent = engine.lastEntries!;
      expect(sent.length, 2);
      for (final e in sent) {
        expect(e.title!.length, lessThan(title.length));
      }
      final total = sent.fold<int>(0, (sum, e) => sum + e.text.length + (e.title?.length ?? 0));
      expect(total, lessThanOrEqualTo(8000));
    });

    test('the cap trims on a code-point boundary, never through a surrogate pair', () async {
      final big = '😀' * 9000;
      entries = [withText('a', DateTime(2026, 7, 20, 9), text: big)];
      await service.catchUp();

      final sent = engine.lastEntries!.single.text;
      expect(sent.length, lessThan(big.length));
      expect(sent.length.isEven, isTrue);
      final last = sent.codeUnitAt(sent.length - 1);
      expect(last >= 0xDC00 && last <= 0xDFFF, isTrue);
      expect(String.fromCharCodes(sent.runes), sent);
    });

    test('a language change that shifts the week boundary does not re-reflect history', () async {
      final sundayWeek = DateTime(2026, 7, 19);
      await store.save(Reflection(periodStart: sundayWeek, generatedAt: now, text: 'kept'));
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      final deService = build(language: 'de', weekOf: null);

      await deService.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.all().length, 1);
      expect(store.read(sundayWeek)!.text, 'kept');
    });

    test('stores the voice from generation start, not a change made mid-run', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      final gate = Completer<void>();
      engine.gate = gate.future;

      final run = service.catchUp();
      await untilParkedInReflect();
      await settings.setVoiceFor(ReflectionPeriod.weekly, ReflectionVoice.sparse);
      gate.complete();
      await run;

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
      await settings.setEnabledFor(ReflectionPeriod.weekly, false);
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
      Intl.defaultLocale = 'en_US';
      final deService = build(language: 'de', weekOf: null);
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];

      await deService.catchUp();

      expect(store.read(DateTime(2026, 7, 20)), isNotNull);
      expect(store.read(DateTime(2026, 7, 19)), isNull);
    });
  });

  group('deletion interplay: the per-week delete is the only eraser, in either direction', () {
    test('a deleted reflection stays deleted while its entries live on', () async {
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
      final sundayWeek = DateTime(2026, 7, 19);
      await store.save(Reflection(periodStart: sundayWeek, generatedAt: now, text: 'x'));
      await service.deleteReflection(sundayWeek);
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      final deService = build(language: 'de', weekOf: null);

      await deService.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.all(), isEmpty);
    });

    test('a delete landed mid-generation wins over the in-flight save', () async {
      await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'old'));
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
      await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'old'));
      await service.deleteReflection(lastWeek);
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.output = 'fresh';

      await service.regenerate(lastWeek);

      expect(store.read(lastWeek)!.text, 'fresh');
      expect(store.deletedWeeks(), isEmpty);
    });

    test('deleting a reflected week\'s entries later leaves its reflection '
        'untouched by a real catch-up pass', () async {
      await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'as heard'));
      entries = [withText('b', DateTime(2026, 7, 15, 12), text: 'two weeks ago')];

      await service.catchUp();

      expect(engine.reflectCalls, 1);
      expect(store.read(twoWeeksAgo), isNotNull);
      expect(store.read(lastWeek)!.text, 'as heard');
    });

    test('a week emptied to zero regenerates to an honest silence, without the model', () async {
      await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'as heard'));
      entries = [];

      await service.regenerate(lastWeek);

      expect(engine.reflectCalls, 0);
      expect(store.read(lastWeek)!.isSilent, isTrue);
    });

    test('an unreflected week whose entries were all deleted simply never reflects', () async {
      entries = [];

      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.all(), isEmpty);
    });
  });

  group('no-backfill floor', () {
    test('weeks that closed before the feature first ran are never reflected', () async {
      await settings.setFloorFor(ReflectionPeriod.weekly, DateTime(2026, 7, 27));
      entries = [
        withText('a', DateTime(2026, 7, 22, 12), text: 'last week'),
        withText('b', DateTime(2026, 7, 15, 12), text: 'two weeks ago'),
      ];

      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.all(), isEmpty);
    });

    test('the feature-start week itself reflects once it closes', () async {
      await settings.setFloorFor(ReflectionPeriod.weekly, lastWeek);
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
      final fresh = await reflectionStorage();
      storage = fresh.storage;
      store = fresh.store;
      settings = fresh.settings;
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'pre-feature week')];
      service = build();

      await service.catchUp();

      expect(settings.floorFor(ReflectionPeriod.weekly), DateTime(2026, 7, 27));
      expect(engine.reflectCalls, 0);
      expect(store.all(), isEmpty);

      final later = build(clock: () => DateTime(2026, 8, 5, 12));
      await later.catchUp();
      expect(settings.floorFor(ReflectionPeriod.weekly), DateTime(2026, 7, 27));
    });

    test('the floor is recorded even while the on-device model is unavailable, '
        'so weeks journaled in the gap still fill once it answers', () async {
      final fresh = await reflectionStorage();
      storage = fresh.storage;
      store = fresh.store;
      settings = fresh.settings;
      engine.availabilityResult = const ReflectionAvailability(
        ReflectionAvailabilityStatus.notEnabled,
      );
      entries = [withText('a', DateTime(2026, 7, 29, 12), text: 'with AI off')];
      service = build();

      await service.catchUp();
      expect(settings.floorFor(ReflectionPeriod.weekly), DateTime(2026, 7, 27));

      engine.availabilityResult = const ReflectionAvailability.available();
      final later = build(clock: () => DateTime(2026, 8, 5, 12));
      await later.catchUp();
      expect(store.read(DateTime(2026, 7, 27)), isNotNull);
    });

    test('a floor record that fails to parse is preserved, never re-recorded at today', () async {
      await storage.write('reflect.weekly.floor', 'not-a-date');
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];

      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(storage.readString('reflect.weekly.floor'), 'not-a-date');
    });

    test('a first-day-of-week shift cannot pull a pre-feature week over the floor', () async {
      await settings.setFloorFor(ReflectionPeriod.weekly, DateTime(2026, 7, 19));
      entries = [
        withText('a', DateTime(2026, 7, 8, 12), text: 'fully before the floor'),
        withText('b', DateTime(2026, 7, 15, 12), text: 'week straddling the floor day'),
      ];
      final deService = build(language: 'de', weekOf: null);

      await deService.catchUp();

      expect(engine.reflectCalls, 1);
      expect(store.read(DateTime(2026, 7, 13)), isNotNull);
      expect(store.read(DateTime(2026, 7, 6)), isNull);
    });
  });

  group('regenerate', () {
    test('replaces a stored reflection in the current style', () async {
      await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'old'));
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.output = 'new';

      await service.regenerate(lastWeek);

      expect(store.read(lastWeek)!.text, 'new');
      expect(engine.reflectCalls, 1);
    });

    test('a week with no material regenerates to an honest silence', () async {
      entries = [withText('a', DateTime(2026, 7, 22, 12))];
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
      final sundayWeek = DateTime(2026, 7, 19);
      await store.save(Reflection(periodStart: sundayWeek, generatedAt: now, text: 'old'));
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
      engine.output = 'new';
      final deService = build(language: 'de', weekOf: null);

      await deService.regenerate(sundayWeek);

      expect(store.read(sundayWeek)!.text, 'new');
      expect(store.read(DateTime(2026, 7, 20)), isNull);
    });
  });

  group('periods beyond weekly', () {
    test('reflects each closed day when daily is enabled', () async {
      await settings.setEnabledFor(ReflectionPeriod.weekly, false);
      await settings.setEnabledFor(ReflectionPeriod.daily, true);
      await settings.setFloorFor(ReflectionPeriod.daily, DateTime(2026, 6, 8));
      entries = [
        withText('a', DateTime(2026, 7, 27, 9), text: 'monday'),
        withText('b', DateTime(2026, 7, 28, 9), text: 'tuesday'),
      ];

      await service.catchUp();

      expect(engine.reflectCalls, 2);
      expect(engine.lastPeriod, ReflectionPeriod.daily);
      expect(store.read(DateTime(2026, 7, 27), period: ReflectionPeriod.daily), isNotNull);
      expect(store.read(DateTime(2026, 7, 28), period: ReflectionPeriod.daily), isNotNull);
    });

    test('does not reflect the current, still-open day', () async {
      await settings.setEnabledFor(ReflectionPeriod.weekly, false);
      await settings.setEnabledFor(ReflectionPeriod.daily, true);
      await settings.setFloorFor(ReflectionPeriod.daily, DateTime(2026, 6, 8));
      entries = [withText('a', DateTime(2026, 7, 29, 9), text: 'today')];

      await service.catchUp();

      expect(engine.reflectCalls, 0);
      expect(store.read(DateTime(2026, 7, 29), period: ReflectionPeriod.daily), isNull);
    });

    test('reflects a closed month as one read of all its entries', () async {
      await settings.setEnabledFor(ReflectionPeriod.weekly, false);
      await settings.setEnabledFor(ReflectionPeriod.monthly, true);
      await settings.setFloorFor(ReflectionPeriod.monthly, DateTime(2026));
      entries = [
        withText('a', DateTime(2026, 6, 10, 9), text: 'june'),
        withText('b', DateTime(2026, 6, 20, 9), text: 'june again'),
      ];

      await service.catchUp();

      expect(engine.reflectCalls, 1);
      expect(engine.lastPeriod, ReflectionPeriod.monthly);
      expect(engine.lastEntries!.length, 2);
      expect(store.read(DateTime(2026, 6), period: ReflectionPeriod.monthly), isNotNull);
    });

    test('a daily reflection inside a week does not mark that week covered', () async {
      await store.save(
        Reflection(
          period: ReflectionPeriod.daily,
          periodStart: DateTime(2026, 7, 22),
          generatedAt: now,
          text: 'a single day',
        ),
      );
      entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];

      await service.catchUp();

      expect(store.read(lastWeek), isNotNull);
    });

    test('history stays weekly even when other periods have rows', () async {
      await store.save(
        Reflection(
          period: ReflectionPeriod.daily,
          periodStart: lastWeek,
          generatedAt: now,
          text: 'day',
        ),
      );
      await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'week'));

      expect(service.historyFor(ReflectionPeriod.weekly).map((r) => r.text), ['week']);
    });
  });

  group('surface pass-throughs', () {
    test('journaledStartsFor buckets by the injected week boundary', () {
      entries = [
        withText('a', DateTime(2026, 7, 22, 9), text: 'x'),
        withText('b', DateTime(2026, 7, 15, 9), text: 'y'),
      ];
      expect(service.journaledStartsFor(ReflectionPeriod.weekly), {lastWeek, twoWeeksAgo});
    });

    test('journaledStartsFor ignores weeks holding only untranscribed entries, '
        'so no waiting page promises a fill that never comes', () {
      entries = [
        withText('a', DateTime(2026, 7, 22, 9), text: 'x'),
        withText('b', DateTime(2026, 7, 15, 9)),
      ];
      expect(service.journaledStartsFor(ReflectionPeriod.weekly), {lastWeek});
    });

    test('currentStartFor is the open week under the same boundary', () {
      expect(service.currentStartFor(ReflectionPeriod.weekly), DateTime(2026, 7, 27));
    });

    test('deletedStartsFor mirrors the store tombstones', () async {
      await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'x'));
      await service.deleteReflection(lastWeek);
      expect(service.deletedStartsFor(ReflectionPeriod.weekly), [lastWeek]);
    });
  });

  test('deleteReflection removes a week and emits', () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'x'));
    final events = <void>[];
    final sub = service.reflectionsChanged.listen(events.add);

    await service.deleteReflection(lastWeek);
    await Future<void>.delayed(Duration.zero);

    expect(store.read(lastWeek), isNull);
    expect(events, isNotEmpty);
    await sub.cancel();
  });

  test('deleteReflection keys off the stored week, not the current locale boundary, '
      'so no row is left undeletable', () async {
    final sundayWeek = DateTime(2026, 7, 19);
    await store.save(Reflection(periodStart: sundayWeek, generatedAt: now, text: 'x'));
    final deService = build(language: 'de', weekOf: null);

    await deService.deleteReflection(sundayWeek);

    expect(store.read(sundayWeek), isNull);
    expect(store.all(), isEmpty);
  });

  group('reflectBacklog', () {
    final mayWeek = DateTime(2026, 5, 25);

    setUp(() async {
      await settings.setEnabledFor(ReflectionPeriod.monthly, false);
    });

    test('catch-up leaves a pre-floor week, and reflectBacklog reflects it', () async {
      entries = [withText('old', DateTime(2026, 5, 27, 12), text: 'a may week')];
      engine.output = 'the may week reflected';

      await service.catchUp();
      expect(store.read(mayWeek), isNull);

      await service.reflectBacklog();
      expect(store.read(mayWeek)!.text, 'the may week reflected');
    });

    test('hasBacklog is true for a journaled pre-floor period and false once drained', () async {
      entries = [withText('old', DateTime(2026, 5, 27, 12), text: 'a may week')];

      expect(service.hasBacklog(), isTrue);
      await service.reflectBacklog();
      expect(service.hasBacklog(), isFalse);
    });

    test('a stored reflection below the floor is left as it is', () async {
      await store.save(Reflection(periodStart: mayWeek, generatedAt: now, text: 'kept by hand'));
      entries = [withText('old', DateTime(2026, 5, 27, 12), text: 'a may week')];
      engine.output = 'regenerated text';

      await service.reflectBacklog();

      expect(store.read(mayWeek)!.text, 'kept by hand');
    });

    test('an erased pre-floor period stays erased', () async {
      entries = [withText('old', DateTime(2026, 5, 27, 12), text: 'a may week')];
      await store.delete(mayWeek);

      await service.reflectBacklog();

      expect(store.read(mayWeek), isNull);
    });

    test(
      'a backlog request landing during a running catch-up is drained by a trailing pass',
      () async {
        await settings.setEnabledFor(ReflectionPeriod.daily, false);
        entries = [
          withText('a', DateTime(2026, 7, 22, 12), text: 'last week'),
          withText('old', DateTime(2026, 5, 27, 12), text: 'a may week'),
        ];
        final gate = Completer<void>();
        engine.gate = gate.future;

        final running = service.catchUp();
        await untilParkedInReflect();
        expect(store.read(mayWeek), isNull);

        await service.reflectBacklog();
        expect(store.read(mayWeek), isNull, reason: 'the trailing pass has not run yet');

        gate.complete();
        await running;

        expect(store.read(lastWeek), isNotNull);
        expect(store.read(mayWeek), isNotNull, reason: 'the coalesced trailing pass drained it');
        expect(engine.reflectCalls, 2);
      },
    );
  });
}
