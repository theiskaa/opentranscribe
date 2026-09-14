import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/engine_registry.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/engine_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_recorder.dart';

import '../../support/engine_fixtures.dart';

class _FailingWrites extends LocalService {
  @override
  Future<void> write<T>(String key, T value) async => throw StateError('no disk');
}

class _GatedWrites extends LocalService {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> write<T>(String key, T value) => gate.future;
}

class _HookedWrites extends LocalService {
  _HookedWrites(this._beforeThrow);

  final Future<void> Function() _beforeThrow;

  @override
  Future<void> write<T>(String key, T value) async {
    await _beforeThrow();
    throw StateError('no disk');
  }
}

void main() {
  const key = 'test-encryption-key-0123456789ab';
  late LocalService storage;
  late FakeAudioRecorder recorder;
  late FakeStreamingEngine speech;
  late FakeDictationEngine dictation;
  late TranscriptionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    recorder = FakeAudioRecorder();
    speech = FakeStreamingEngine(stopSignal: recorder.stopped);
    dictation = FakeDictationEngine();
    service = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: recorder,
      engine: speech,
      store: EntryStore(storage),
      fileDeleter: (file) async {},
    );
  });

  tearDown(() => service.dispose());

  EngineEntry entry(TranscriptionEngine engine, {required bool available, int order = 0}) =>
      EngineEntry(
        descriptor: engineDescriptor(engine.id, displayOrder: order),
        engine: engine,
        available: available,
        unavailability: available ? null : EngineUnavailability.needsNewerDevice,
      );

  EnginesCubit build({
    bool speechAvailable = true,
    EngineSettings? engineSettings,
    int speechOrder = 0,
    int dictationOrder = 1,
  }) {
    final cubit = EnginesCubit(
      registry: [
        entry(speech, available: speechAvailable, order: speechOrder),
        entry(dictation, available: true, order: dictationOrder),
      ],
      service: service,
      engineSettings: engineSettings ?? EngineSettings(storage: storage),
      transcriptionSettings: TranscriptionSettings(
        storage: storage,
        service: service,
        deviceTag: () => 'en-US',
      ),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('a pick racing an in-flight pick is dropped as unchanged', () async {
    final gated = _GatedWrites();
    await gated.init(legacyKey: key);
    final cubit = build(engineSettings: EngineSettings(storage: gated));

    final first = cubit.pick('fake.dictation');
    final second = await cubit.pick('fake.streaming');

    expect(second, EnginePickOutcome.unchanged);
    expect(service.engineId, 'fake.dictation');

    gated.gate.complete();
    expect(await first, EnginePickOutcome.switched);
    expect(service.engineId, 'fake.dictation');

    await cubit.close();
  });

  test("rows carry each entry's descriptor and availability, the active one marked", () {
    final cubit = build(speechAvailable: false);

    expect(cubit.state.rows.map((r) => r.descriptor.engineId), [
      'fake.streaming',
      'fake.dictation',
    ]);
    expect(cubit.state.rows.first.available, isFalse);
    expect(cubit.state.rows.first.unavailability, EngineUnavailability.needsNewerDevice);
    expect(cubit.state.rows.first.isActive, isTrue);
    expect(cubit.state.rows.last.isActive, isFalse);
  });

  test('rows follow the display order, not the preference order auto resolves', () {
    final cubit = build(speechOrder: 1, dictationOrder: 0);

    expect(cubit.state.rows.map((r) => r.descriptor.engineId), [
      'fake.dictation',
      'fake.streaming',
    ]);
  });

  test("engines sharing a display order keep the registry's order between them", () {
    final cubit = build(speechOrder: 3, dictationOrder: 3);

    expect(cubit.state.rows.map((r) => r.descriptor.engineId), [
      'fake.streaming',
      'fake.dictation',
    ]);
  });

  test('pick switches, persists, re-resolves the language, and re-marks rows', () async {
    final engineSettings = EngineSettings(storage: storage);
    final cubit = build(engineSettings: engineSettings);
    final pings = <void>[];
    final sub = service.modelStateChanged.listen(pings.add);

    final outcome = await cubit.pick('fake.dictation');
    await pumpEventQueue();

    expect(outcome, EnginePickOutcome.switched);
    expect(service.engineId, 'fake.dictation');
    expect(engineSettings.engineId, 'fake.dictation');
    expect(service.localeId, 'en-US');
    expect(cubit.state.rows.last.isActive, isTrue);
    expect(cubit.state.rows.first.isActive, isFalse);
    expect(pings, hasLength(2));

    await sub.cancel();
  });

  test('picking the active engine pins the auto-resolved choice', () async {
    final engineSettings = EngineSettings(storage: storage);
    final cubit = build(engineSettings: engineSettings);

    expect(await cubit.pick('fake.streaming'), EnginePickOutcome.unchanged);
    expect(engineSettings.engineId, 'fake.streaming');
  });

  test('an engine this device cannot run is never switched to', () async {
    service.useEngine(dictation);
    final cubit = build(speechAvailable: false);

    expect(await cubit.pick('fake.streaming'), EnginePickOutcome.unavailable);
    expect(service.engineId, 'fake.dictation');
  });

  test('an id nothing ships is refused', () async {
    final cubit = build();

    expect(await cubit.pick('gone'), EnginePickOutcome.unavailable);
  });

  test('a pick during a take answers busy and stores nothing', () async {
    final engineSettings = EngineSettings(storage: storage);
    final cubit = build(engineSettings: engineSettings);
    await service.startRecording();

    expect(await cubit.pick('fake.dictation'), EnginePickOutcome.busy);
    expect(service.engineId, 'fake.streaming');
    expect(engineSettings.engineId, isNull);

    await service.stopRecording();
  });

  test('a pick during a bulk re-transcribe answers retranscribing and stores nothing', () async {
    final engineSettings = EngineSettings(storage: storage);
    final cubit = build(engineSettings: engineSettings);
    final gate = Completer<void>();
    expect(service.useEngine(FakeBatchEngine(gate: gate.future)), isTrue);
    await service.adoptImportedEntries([
      StagedImportEntry(
        entry: Entry(
          id: 'kept',
          createdAt: DateTime.utc(2026, 3, 4),
          audioPath: '/audio/kept.m4a',
          duration: const Duration(seconds: 3),
        ),
      ),
    ]);
    final run = service.retranscribeAll.start();
    await Future<void>.delayed(Duration.zero);

    expect(await cubit.pick('fake.dictation'), EnginePickOutcome.retranscribing);
    expect(service.engineId, 'fake.batch');
    expect(engineSettings.engineId, isNull);

    gate.complete();
    await run;
  });

  test('nothing refuses a switch while nothing holds the engine', () {
    expect(build().refusal, isNull);
  });

  test('a take in flight refuses a switch before any pick is tried', () async {
    final cubit = build();
    await service.startRecording();

    expect(cubit.refusal, EnginePickOutcome.busy);

    await service.stopRecording();
    await pumpEventQueue();
    expect(cubit.refusal, isNull);
  });

  test('a bulk re-transcribe refuses a switch before any pick is tried', () async {
    final cubit = build();
    final gate = Completer<void>();
    expect(service.useEngine(FakeBatchEngine(gate: gate.future)), isTrue);
    await service.adoptImportedEntries([
      StagedImportEntry(
        entry: Entry(
          id: 'kept',
          createdAt: DateTime.utc(2026, 3, 4),
          audioPath: '/audio/kept.m4a',
          duration: const Duration(seconds: 3),
        ),
      ),
    ]);
    final run = service.retranscribeAll.start();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.refusal, EnginePickOutcome.retranscribing);

    gate.complete();
    await run;
  });

  test('a failed persist reverts the switch and rethrows', () async {
    final cubit = build(engineSettings: EngineSettings(storage: _FailingWrites()));

    await expectLater(cubit.pick('fake.dictation'), throwsStateError);
    expect(service.engineId, 'fake.streaming');
    expect(cubit.state.rows.first.isActive, isTrue);
  });

  test('a refused revert leaves the swap for the session and the rows honest', () async {
    dictation = FakeDictationEngine(supportedLocaleTags: ['de-DE']);
    final cubit = build(
      engineSettings: EngineSettings(storage: _HookedWrites(() => service.startRecording())),
    );

    await expectLater(cubit.pick('fake.dictation'), throwsStateError);
    expect(service.engineId, 'fake.dictation');
    expect(cubit.state.rows.last.isActive, isTrue);

    await service.stopRecording();
    await pumpEventQueue();
    expect(service.localeId, 'de-DE');
  });
}
