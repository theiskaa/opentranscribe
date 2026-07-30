import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/fake_reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime mondayStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

void main() {
  const key = 'test-encryption-key-0123456789ab';
  final now = DateTime(2026, 7, 29, 12);
  final lastWeek = DateTime(2026, 7, 20);

  late LocalService storage;
  late ReflectionStore store;
  late ReflectionSettings settings;
  late FakeReflectionEngine engine;
  late List<Entry> entries;
  late ReflectionService service;

  Entry withText(String id, DateTime createdAt, {String? text}) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: null,
    duration: const Duration(seconds: 1),
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

  ReflectionsCubit build() => ReflectionsCubit(service: service, settings: settings);

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
    store = ReflectionStore(storage);
    settings = ReflectionSettings(storage: storage);
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
    await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'kept'));
    final cubit = build();
    await cubit.load();

    expect(cubit.state.available, isTrue);
    expect(cubit.state.enabled, isTrue);
    expect(cubit.state.style, ReflectionStyle.defaults);
    expect(cubit.state.history.map((r) => r.text), ['kept']);
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

  test('setEnabled persists, reflects in state, and enabling kicks a catch-up', () async {
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    final cubit = build();
    await cubit.load();

    await cubit.setEnabled(false);
    expect(cubit.state.enabled, isFalse);
    expect(settings.enabled, isFalse);

    await cubit.setEnabled(true);
    await settle();
    expect(cubit.state.enabled, isTrue);
    // Enabling caught up the due week without waiting for a relaunch.
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

    expect(settings.style, cubit.state.style);
    expect(cubit.state.style.voice, ReflectionVoice.sparse);
    expect(cubit.state.style.length, ReflectionLength.oneLine);
    expect(cubit.state.style.specificity, ReflectionSpecificity.abstractThemes);
    await cubit.close();
  });

  test('regenerate replaces the week and clears the in-flight marker', () async {
    await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'old'));
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
    // Not a ReflectionUnavailable: a storage-write StateError must not leave
    // the row spinning forever, which only a catch-all/finally guarantees.
    entries = [withText('a', DateTime(2026, 7, 22, 12), text: 'work')];
    engine.error = StateError('persist failed');
    final cubit = build();
    await cubit.load();

    await cubit.regenerate(lastWeek);

    expect(cubit.state.regenerateFailed, isTrue);
    expect(cubit.state.regenerating, isNull);
    await cubit.close();
  });

  test('a second regenerate while one is in flight is ignored', () async {
    // A shared in-flight marker: letting week B start mid-A would steal A's
    // spinner and then have A's completion clear B's.
    final weekBefore = DateTime(2026, 7, 13);
    await store.save(Reflection(weekStart: lastWeek, generatedAt: now, text: 'a'));
    await store.save(Reflection(weekStart: weekBefore, generatedAt: now, text: 'b'));
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

  test('load re-probes availability, so a resume picks up a mid-life enable', () async {
    engine.availabilityResult = const ReflectionAvailability(
      ReflectionAvailabilityStatus.notEnabled,
    );
    final cubit = build();
    await cubit.load();
    expect(cubit.state.available, isFalse);

    // Apple Intelligence enabled while backgrounded; the app's lifecycle
    // observer calls load() on resume.
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

    // The foreground catch-up path writes a reflection and notifies.
    await service.catchUp();
    await settle();

    expect(cubit.state.history, isNotEmpty);
    await cubit.close();
  });
}
