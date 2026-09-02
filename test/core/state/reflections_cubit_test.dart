import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:reflections/reflections.dart';
import 'package:reflections/testing.dart';

import '../../support/reflection_fixtures.dart';

void main() {
  final now = DateTime(2026, 7, 29, 12);
  final lastWeek = DateTime(2026, 7, 20);

  late ReflectionStore store;
  late ReflectionSettings settings;
  late FakeReflectionEngine engine;
  late List<Entry> entries;
  late ReflectionService service;

  ReflectionsCubit build() => ReflectionsCubit(service: service, settings: settings);

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  setUp(() async {
    final fresh = await reflectionStorage();
    store = fresh.store;
    settings = fresh.settings;
    await settings.setFloorFor(ReflectionPeriod.weekly, DateTime(2026, 6, 8));
    engine = FakeReflectionEngine();
    entries = [];
    service = ReflectionService(
      engine: engine,
      store: store,
      settings: settings,
      entries: () => entries,
      language: () => 'en',
      clock: () => now,
      weekOf: mondayStart,
    );
  });

  test('loads availability, settings, and history on build', () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'kept'));
    final cubit = build();
    await cubit.load();

    expect(cubit.state.available, isTrue);
    expect(cubit.state.enabledByPeriod[ReflectionPeriod.weekly], isTrue);
    expect(cubit.state.style, ReflectionStyle.defaults);
    expect(cubit.state.history.map((r) => r.text), ['kept']);
    await cubit.close();
  });

  test('loaded is true synchronously off construction, before the probe answers', () async {
    engine.availabilityGate = Completer<void>().future;
    final cubit = build();

    expect(cubit.state.loaded, isTrue);
    await cubit.close();
  });

  test('autoLoad false defers every derive until load is called', () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'kept'));
    final cubit = ReflectionsCubit(service: service, settings: settings, autoLoad: false);

    await pumpEventQueue();
    expect(cubit.state, const ReflectionsState());
    expect(cubit.state.loaded, isFalse);

    await cubit.load();

    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.history.map((r) => r.text), ['kept']);
    await cubit.close();
  });

  test('the stored view lands before the availability probe answers', () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'a week'));
    await store.save(
      Reflection(
        period: ReflectionPeriod.monthly,
        periodStart: DateTime(2026, 6),
        generatedAt: now,
        text: 'a month',
      ),
    );
    engine.availabilityGate = Completer<void>().future;
    final cubit = build();

    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.timeline, isNotEmpty);
    await cubit.close();
  });

  test("a drill's period choice made before the first probe answers is honored", () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'a week'));
    await store.save(
      Reflection(
        period: ReflectionPeriod.daily,
        periodStart: DateTime(2026, 7, 28),
        generatedAt: now,
        text: 'a day',
      ),
    );
    final gate = Completer<void>();
    engine.availabilityGate = gate.future;
    final cubit = build();

    cubit.setViewedPeriod(ReflectionPeriod.daily);
    expect(cubit.state.viewedPeriod, ReflectionPeriod.daily);
    expect(cubit.state.history.map((r) => r.text), ['a day']);

    gate.complete();
    await settle();

    expect(cubit.state.viewedPeriod, ReflectionPeriod.daily);
    await cubit.close();
  });

  test('available means the model can actually run, nothing else', () async {
    Future<void> check(ReflectionAvailabilityStatus status, {required bool available}) async {
      engine.availabilityResult = ReflectionAvailability(status);
      final cubit = build();
      await cubit.load();
      expect(cubit.state.available, available, reason: '$status');
      await cubit.close();
    }

    await check(ReflectionAvailabilityStatus.available, available: true);
    await check(ReflectionAvailabilityStatus.notEnabled, available: false);
    await check(ReflectionAvailabilityStatus.modelNotReady, available: false);
    await check(ReflectionAvailabilityStatus.deviceNotEligible, available: false);
    await check(ReflectionAvailabilityStatus.unsupported, available: false);
  });

  test('allDisabled only once every period is off', () async {
    final cubit = build();
    await cubit.load();
    await cubit.setPeriodEnabled(ReflectionPeriod.daily, true);
    await settle();
    expect(cubit.state.allDisabled, isFalse);

    await cubit.setPeriodEnabled(ReflectionPeriod.weekly, false);
    expect(cubit.state.allDisabled, isFalse);
    await cubit.setPeriodEnabled(ReflectionPeriod.monthly, false);
    expect(cubit.state.allDisabled, isFalse);
    await cubit.setPeriodEnabled(ReflectionPeriod.daily, false);
    expect(cubit.state.allDisabled, isTrue);

    await cubit.setPeriodEnabled(ReflectionPeriod.daily, true);
    await settle();
    expect(cubit.state.allDisabled, isFalse);
    await cubit.close();
  });

  test('hasBacklog flags a pre-floor journaled period and generateBacklog drains it', () async {
    await settings.setEnabledFor(ReflectionPeriod.monthly, false);
    entries = [withText('old', DateTime(2026, 5, 27, 12), text: 'a may week')];
    engine.output = 'the may week reflected';
    final cubit = build();
    await cubit.load();
    await settle();

    expect(cubit.state.hasBacklog, isTrue);
    expect(cubit.state.timeline, isEmpty);

    await cubit.generateBacklog();
    await settle();

    expect(cubit.state.generatingAll, isFalse);
    expect(cubit.state.hasBacklog, isFalse);
    expect(store.read(DateTime(2026, 5, 25))!.text, 'the may week reflected');
    await cubit.close();
  });

  test('enableDefaults restores the periods that write out of the box', () async {
    final cubit = build();
    await cubit.load();
    await cubit.setPeriodEnabled(ReflectionPeriod.weekly, false);
    await cubit.setPeriodEnabled(ReflectionPeriod.monthly, false);
    await cubit.setPeriodEnabled(ReflectionPeriod.daily, false);
    expect(cubit.state.allDisabled, isTrue);

    await cubit.enableDefaults();
    await settle();
    expect(cubit.state.enabledByPeriod[ReflectionPeriod.daily], isFalse);
    expect(cubit.state.enabledByPeriod[ReflectionPeriod.weekly], isTrue);
    expect(cubit.state.enabledByPeriod[ReflectionPeriod.monthly], isTrue);
    await cubit.close();
  });

  test('setEnabled persists, reflects in state, and enabling kicks a catch-up', () async {
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    final cubit = build();
    await cubit.load();

    await cubit.setPeriodEnabled(ReflectionPeriod.weekly, false);
    expect(cubit.state.enabledByPeriod[ReflectionPeriod.weekly], isFalse);
    expect(settings.enabledFor(ReflectionPeriod.weekly), isFalse);

    await cubit.setPeriodEnabled(ReflectionPeriod.weekly, true);
    await settle();
    expect(cubit.state.enabledByPeriod[ReflectionPeriod.weekly], isTrue);
    expect(engine.reflectCalls, 1);
    expect(store.read(lastWeek), isNotNull);
    await cubit.close();
  });

  test('each style setter persists and updates the state', () async {
    final cubit = build();
    await cubit.load();

    await cubit.setVoice(ReflectionVoice.sparse);
    await cubit.setLength(ReflectionLength.oneLine);
    await cubit.setSpecificity(ReflectionSpecificity.abstractThemes);

    expect(settings.styleFor(cubit.state.viewedPeriod), cubit.state.style);
    expect(cubit.state.style.voice, ReflectionVoice.sparse);
    expect(cubit.state.style.length, ReflectionLength.oneLine);
    expect(cubit.state.style.specificity, ReflectionSpecificity.abstractThemes);
    await cubit.close();
  });

  test('regenerate replaces the week and clears the in-flight marker', () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'old'));
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    engine.output = 'new';
    final cubit = build();
    await cubit.load();

    await cubit.regenerate(lastWeek);

    expect(cubit.state.history.single.text, 'new');
    expect(cubit.state.regenerating, isNull);
    expect(cubit.state.regenerateFailed, isFalse);
    await cubit.close();
  });

  test('a failed regenerate flags regenerateFailed instead of throwing', () async {
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    engine.failReflect = true;
    final cubit = build();
    await cubit.load();

    await cubit.regenerate(lastWeek);

    expect(cubit.state.regenerateFailed, isTrue);
    expect(cubit.state.regenerating, isNull);
    await cubit.close();
  });

  test('an unexpected regenerate failure still clears the spinner', () async {
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    engine.error = StateError('persist failed');
    final cubit = build();
    await cubit.load();

    await cubit.regenerate(lastWeek);

    expect(cubit.state.regenerateFailed, isTrue);
    expect(cubit.state.regenerating, isNull);
    await cubit.close();
  });

  test('a second regenerate, even for another week, is ignored while one is in flight', () async {
    final weekBefore = DateTime(2026, 7, 13);
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'a'));
    await store.save(Reflection(periodStart: weekBefore, generatedAt: now, text: 'b'));
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    final gate = Completer<void>();
    engine.gate = gate.future;
    final cubit = build();
    await cubit.load();

    final first = cubit.regenerate(lastWeek);
    final second = cubit.regenerate(weekBefore);
    expect(cubit.state.regenerating, lastWeek);
    gate.complete();
    await Future.wait([first, second]);

    expect(engine.reflectCalls, 1);
    expect(cubit.state.regenerating, isNull);
    await cubit.close();
  });

  test('a period switch does not lift the regenerate guard', () async {
    await settings.setEnabledFor(ReflectionPeriod.daily, true);
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'x'));
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    final gate = Completer<void>();
    engine.gate = gate.future;
    final cubit = build();
    await cubit.load();

    final run = cubit.regenerate(lastWeek);
    expect(cubit.state.regenerating, lastWeek);

    cubit.setViewedPeriod(ReflectionPeriod.daily);
    expect(cubit.state.regenerating, isNull);

    final otherStart = DateTime(2026, 7, 28);
    await cubit.regenerate(otherStart);
    expect(engine.reflectCalls, 1);

    gate.complete();
    await run;

    expect(engine.reflectCalls, 1);
    expect(cubit.state.regenerating, isNull);
    await cubit.close();
  });

  test('load re-probes availability, so a resume picks up a mid-life enable', () async {
    engine.availabilityResult = const ReflectionAvailability(
      ReflectionAvailabilityStatus.notEnabled,
    );
    final cubit = build();
    await cubit.load();
    expect(cubit.state.available, isFalse);

    engine.availabilityResult = const ReflectionAvailability.available();
    await cubit.load();

    expect(cubit.state.available, isTrue);
    await cubit.close();
  });

  test('a reflection generated elsewhere refreshes the history', () async {
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    final cubit = build();
    await cubit.load();
    expect(cubit.state.history, isEmpty);

    await service.catchUp();
    await settle();

    expect(cubit.state.history, isNotEmpty);
    await cubit.close();
  });

  test('the timeline pages a journaled but unwritten closed week as waiting, '
      'and refreshes on change', () async {
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    final cubit = build();
    await cubit.load();

    expect(cubit.state.timeline.single.status, ReflectionPageStatus.unreflected);

    await service.catchUp();
    await settle();
    expect(cubit.state.timeline.single.status, ReflectionPageStatus.reflected);
    await cubit.close();
  });

  test('setViewedPeriod switches enabled, style, and history to that period', () async {
    // Weekly off but with stored history keeps it in the switcher alongside
    // daily, so the switch between them is observable.
    await settings.setEnabledFor(ReflectionPeriod.weekly, false);
    await settings.setEnabledFor(ReflectionPeriod.daily, true);
    await settings.setVoiceFor(ReflectionPeriod.daily, ReflectionVoice.sparse);
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'a week'));
    await store.save(
      Reflection(
        period: ReflectionPeriod.daily,
        periodStart: DateTime(2026, 7, 28),
        generatedAt: now,
        text: 'a day',
      ),
    );
    final cubit = build();
    await cubit.load();
    expect(cubit.state.viewedPeriod, ReflectionPeriod.weekly);
    expect(cubit.state.enabledByPeriod[ReflectionPeriod.weekly], isFalse);
    expect(cubit.state.history.map((r) => r.text), ['a week']);

    cubit.setViewedPeriod(ReflectionPeriod.daily);

    expect(cubit.state.viewedPeriod, ReflectionPeriod.daily);
    expect(cubit.state.enabledByPeriod[ReflectionPeriod.daily], isTrue);
    expect(cubit.state.style.voice, ReflectionVoice.sparse);
    expect(cubit.state.history.map((r) => r.text), ['a day']);
    await cubit.close();
  });

  test('the switcher offers a period that is enabled or holds history', () async {
    await settings.setEnabledFor(ReflectionPeriod.daily, false);
    await settings.setEnabledFor(ReflectionPeriod.monthly, true);
    await store.save(
      Reflection(
        period: ReflectionPeriod.daily,
        periodStart: DateTime(2026, 7, 28),
        generatedAt: now,
        text: 'a day',
      ),
    );
    final cubit = build();
    await cubit.load();

    expect(cubit.state.periods, [
      ReflectionPeriod.daily,
      ReflectionPeriod.weekly,
      ReflectionPeriod.monthly,
    ]);
    expect(cubit.state.enabledByPeriod, {
      ReflectionPeriod.daily: false,
      ReflectionPeriod.weekly: true,
      ReflectionPeriod.monthly: true,
    });
    await cubit.close();
  });

  test('setPeriodEnabled turns a period on, adds it to the switcher, and catches up', () async {
    entries = [withText('a', DateTime(2026, 7, 28, 9), text: 'tuesday')];
    await settings.setFloorFor(ReflectionPeriod.daily, DateTime(2026, 6, 8));
    await settings.setEnabledFor(ReflectionPeriod.daily, false);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.periods, [ReflectionPeriod.weekly, ReflectionPeriod.monthly]);

    await cubit.setPeriodEnabled(ReflectionPeriod.daily, true);
    await settle();

    expect(cubit.state.enabledByPeriod[ReflectionPeriod.daily], isTrue);
    expect(cubit.state.periods, contains(ReflectionPeriod.daily));
    expect(store.read(DateTime(2026, 7, 28), period: ReflectionPeriod.daily), isNotNull);
    await cubit.close();
  });

  test('turning off the viewed period with no history snaps the view away', () async {
    await settings.setEnabledFor(ReflectionPeriod.daily, true);
    final cubit = build();
    await cubit.load();
    cubit.setViewedPeriod(ReflectionPeriod.daily);
    expect(cubit.state.viewedPeriod, ReflectionPeriod.daily);

    await cubit.setPeriodEnabled(ReflectionPeriod.daily, false);

    expect(cubit.state.periods, isNot(contains(ReflectionPeriod.daily)));
    expect(cubit.state.viewedPeriod, ReflectionPeriod.weekly);
    await cubit.close();
  });

  test('home reflections span every enabled period and do not follow the viewed one', () async {
    await settings.setEnabledFor(ReflectionPeriod.daily, true);
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'the week'));
    await store.save(
      Reflection(
        period: ReflectionPeriod.daily,
        periodStart: DateTime(2026, 7, 28),
        generatedAt: now,
        text: 'a day',
      ),
    );
    final cubit = build();
    await cubit.load();
    final home = {for (final r in cubit.state.homeReflections) r.text};
    expect(home, {'the week', 'a day'});

    cubit.setViewedPeriod(ReflectionPeriod.daily);

    expect(cubit.state.history.map((r) => r.text), ['a day']);
    expect({for (final r in cubit.state.homeReflections) r.text}, home);
    await cubit.close();
  });

  test('a disabled period keeps its cards off home while staying browsable', () async {
    await settings.setEnabledFor(ReflectionPeriod.weekly, false);
    await settings.setEnabledFor(ReflectionPeriod.daily, true);
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'the week'));
    await store.save(
      Reflection(
        period: ReflectionPeriod.daily,
        periodStart: DateTime(2026, 7, 28),
        generatedAt: now,
        text: 'a day',
      ),
    );
    final cubit = build();
    await cubit.load();

    expect(cubit.state.homeReflections.map((r) => r.text), ['a day']);
    expect(cubit.state.periods, contains(ReflectionPeriod.weekly));
    await cubit.close();
  });

  test('switching period drops an in-flight regenerate marker', () async {
    await settings.setEnabledFor(ReflectionPeriod.daily, true);
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'x'));
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    final gate = Completer<void>();
    engine.gate = gate.future;
    final cubit = build();
    await cubit.load();

    final run = cubit.regenerate(lastWeek);
    expect(cubit.state.regenerating, lastWeek);

    cubit.setViewedPeriod(ReflectionPeriod.daily);
    expect(cubit.state.regenerating, isNull);

    gate.complete();
    await run;
    await cubit.close();
  });

  test('a deleted week stays on the timeline as erased', () async {
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'x'));
    final cubit = build();
    await cubit.load();
    expect(cubit.state.timeline.single.status, ReflectionPageStatus.reflected);

    await cubit.delete(lastWeek);
    await settle();

    expect(cubit.state.timeline.single.status, ReflectionPageStatus.erased);
    await cubit.close();
  });

  test('one load carries every period\'s stored starts, silences included', () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'a week'));
    await store.save(
      Reflection(
        period: ReflectionPeriod.daily,
        periodStart: DateTime(2026, 7, 28),
        generatedAt: now,
      ),
    );
    final cubit = build();
    await cubit.load();

    expect(cubit.state.reflectedStartsByPeriod[ReflectionPeriod.weekly], {lastWeek});
    expect(cubit.state.reflectedStartsByPeriod[ReflectionPeriod.daily], {DateTime(2026, 7, 28)});
    expect(cubit.state.reflectedStartsByPeriod[ReflectionPeriod.monthly], isEmpty);
    await cubit.close();
  });

  test('a deleted reflection leaves the stored starts', () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'x'));
    final cubit = build();
    await cubit.load();
    expect(cubit.state.reflectedStartsByPeriod[ReflectionPeriod.weekly], {lastWeek});

    await cubit.delete(lastWeek);
    await settle();

    expect(cubit.state.reflectedStartsByPeriod[ReflectionPeriod.weekly], isEmpty);
    await cubit.close();
  });

  test('an open period\'s reflection never appears in the stored starts', () async {
    await store.save(Reflection(periodStart: DateTime(2026, 7, 27), generatedAt: now, text: 'x'));
    final cubit = build();
    await cubit.load();

    expect(cubit.state.reflectedStartsByPeriod[ReflectionPeriod.weekly], isEmpty);
    await cubit.close();
  });

  test('journaled days hold only days with transcribed material', () async {
    entries = [
      withText('a', DateTime(2026, 7, 22, 12), text: 'work'),
      withText('b', DateTime(2026, 7, 23, 12)),
    ];
    final cubit = build();
    await cubit.load();

    expect(cubit.state.journaledDays, contains(DateTime(2026, 7, 22)));
    expect(cubit.state.journaledDays, isNot(contains(DateTime(2026, 7, 23))));
    await cubit.close();
  });

  test('a fresh load lands on the broadest period with pages', () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'a week'));
    await store.save(
      Reflection(
        period: ReflectionPeriod.monthly,
        periodStart: DateTime(2026, 6),
        generatedAt: now,
        text: 'a month',
      ),
    );
    final cubit = build();
    await cubit.load();

    expect(cubit.state.viewedPeriod, ReflectionPeriod.monthly);
    expect(cubit.state.timeline.single.periodStart, DateTime(2026, 6));
    await cubit.close();
  });

  test('a fresh load falls past an empty broadest period', () async {
    await settings.setEnabledFor(ReflectionPeriod.monthly, true);
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'a week'));
    final cubit = build();
    await cubit.load();

    expect(cubit.state.viewedPeriod, ReflectionPeriod.weekly);
    await cubit.close();
  });

  test('viewing a period with no pages falls to the broadest one with pages', () async {
    await settings.setEnabledFor(ReflectionPeriod.daily, true);
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'a week'));
    final cubit = build();
    await cubit.load();

    cubit.setViewedPeriod(ReflectionPeriod.daily);

    expect(cubit.state.viewedPeriod, ReflectionPeriod.weekly);
    await cubit.close();
  });

  test('a deep-linked period with pages is kept across a reload', () async {
    await store.save(Reflection(periodStart: lastWeek, generatedAt: now, text: 'a week'));
    await store.save(
      Reflection(
        period: ReflectionPeriod.daily,
        periodStart: DateTime(2026, 7, 28),
        generatedAt: now,
        text: 'a day',
      ),
    );
    final cubit = build();
    await cubit.load();
    expect(cubit.state.viewedPeriod, ReflectionPeriod.weekly);

    cubit.setViewedPeriod(ReflectionPeriod.daily);
    await cubit.load();

    expect(cubit.state.viewedPeriod, ReflectionPeriod.daily);
    await cubit.close();
  });

  test('every period empty lands the broadest enabled period with an empty timeline', () async {
    final cubit = build();
    await cubit.load();

    expect(cubit.state.viewedPeriod, ReflectionPeriod.monthly);
    expect(cubit.state.timeline, isEmpty);
    await cubit.close();
  });
}
