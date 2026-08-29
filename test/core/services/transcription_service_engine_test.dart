import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  late LocalService storage;
  late FakeAudioRecorder recorder;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    recorder = FakeAudioRecorder();
  });

  TranscriptionService build(TranscriptionEngine engine) => TranscriptionService(
    composer: FakeAudioComposer(),
    recorder: recorder,
    engine: engine,
    store: EntryStore(storage),
    fileDeleter: (file) async {},
  );

  test('useEngine swaps the engine, reports the id, and pings model surfaces', () async {
    final svc = build(FakeStreamingEngine());
    final pings = <void>[];
    final sub = svc.modelStateChanged.listen(pings.add);

    expect(svc.engineId, 'fake.streaming');
    expect(svc.useEngine(FakeDictationEngine()), isTrue);
    expect(svc.engineId, 'fake.dictation');
    await pumpEventQueue();
    expect(pings, hasLength(1));

    await sub.cancel();
    await svc.dispose();
  });

  test('useEngine refuses mid-take and allows again after the stop settles', () async {
    final svc = build(FakeStreamingEngine(stopSignal: recorder.stopped));
    await svc.startRecording();

    expect(svc.useEngine(FakeDictationEngine()), isFalse);
    expect(svc.engineId, 'fake.streaming');

    await svc.stopRecording();
    await pumpEventQueue();
    expect(svc.useEngine(FakeDictationEngine()), isTrue);

    await svc.dispose();
  });

  test(
    'useEngine refuses while a bulk re-transcribe runs and allows again after it lands',
    () async {
      final gate = Completer<void>();
      final store = EntryStore(storage);
      await store.save(
        Entry(
          id: 'kept',
          createdAt: DateTime.utc(2026, 3, 4),
          audioPath: '/audio/kept.m4a',
          duration: const Duration(seconds: 3),
        ),
      );
      final svc = TranscriptionService(
        composer: FakeAudioComposer(),
        recorder: recorder,
        engine: FakeBatchEngine(gate: gate.future),
        store: store,
        fileDeleter: (file) async {},
      );
      final run = svc.retranscribeAll.start();
      await Future<void>.delayed(Duration.zero);

      expect(svc.useEngine(FakeDictationEngine()), isFalse);
      expect(svc.engineId, 'fake.batch');

      gate.complete();
      await run;
      expect(svc.useEngine(FakeDictationEngine()), isTrue);

      await svc.dispose();
    },
  );

  test('useEngine refuses while a stop is still finalizing', () async {
    final svc = build(
      FakeStreamingEngine(
        stopSignal: recorder.stopped,
        batchDelay: const Duration(milliseconds: 20),
      ),
    );
    await svc.startRecording();
    final stopping = svc.stopRecording();

    expect(svc.useEngine(FakeDictationEngine()), isFalse);
    expect(svc.engineId, 'fake.streaming');

    await stopping;
    await pumpEventQueue();
    expect(svc.useEngine(FakeDictationEngine()), isTrue);

    await svc.dispose();
  });

  test('swapping to the active engine is a no-op that still answers true', () async {
    final engine = FakeStreamingEngine();
    final svc = build(engine);
    final pings = <void>[];
    final sub = svc.modelStateChanged.listen(pings.add);

    expect(svc.useEngine(engine), isTrue);
    await pumpEventQueue();
    expect(pings, isEmpty);

    await sub.cancel();
    await svc.dispose();
  });

  test('an engine that would leave the device is refused loudly', () async {
    final svc = build(FakeStreamingEngine());

    expect(() => svc.useEngine(FakeOffDeviceEngine()), throwsArgumentError);
    expect(svc.engineId, 'fake.streaming');

    await svc.dispose();
  });

  test('locale status under a non-managed engine follows availability', () async {
    final svc = build(
      FakeDictationEngine(availability: const Availability(AvailabilityStatus.onDeviceUnavailable)),
    );

    expect((await svc.localeStatus('en-US')).status, ModelAssetStatus.unsupported);

    await svc.dispose();
  });

  test('a denied permission never marks a dictation language missing', () async {
    final svc = build(
      FakeDictationEngine(availability: const Availability(AvailabilityStatus.permissionDenied)),
    );

    expect((await svc.localeStatus('en-US')).status, ModelAssetStatus.installed);

    await svc.dispose();
  });

  test('a transcript after the swap carries the new engine id', () async {
    final svc = build(FakeStreamingEngine(stopSignal: recorder.stopped));
    svc.useEngine(FakeDictationEngine(stopSignal: recorder.stopped));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript?.engineId, 'fake.dictation');

    await svc.dispose();
  });
}
