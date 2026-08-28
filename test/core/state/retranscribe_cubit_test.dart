import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/retranscribe_runner.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/retranscribe_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  final fixedClock = DateTime.utc(2026, 3, 4, 12);

  late LocalService storage;
  late EntryStore store;
  late TranscriptionService service;

  TranscriptionService build(TranscriptionEngine engine) => TranscriptionService(
    recorder: FakeAudioRecorder(),
    engine: engine,
    store: store,
    clock: () => fixedClock,
    idGenerator: () => 'new-id',
    fileDeleter: (f) async {},
  );

  RetranscribeCubit cubit() => RetranscribeCubit(service: service);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    store = EntryStore(storage);
  });

  Transcript transcriptBy(String engineId) => Transcript(
    fullText: 'old words',
    segments: const [],
    localeId: 'en-US',
    engineId: engineId,
    createdAt: fixedClock,
  );

  Entry entry(String id, {bool audio = true, Transcript? transcript}) => Entry(
    id: id,
    createdAt: fixedClock,
    audioPath: audio ? '/audio/$id.m4a' : null,
    duration: const Duration(seconds: 3),
    transcript: transcript,
  );

  test('the preview splits runnable from current and ignores transcript-only entries', () async {
    service = build(FakeBatchEngine());
    await store.save(entry('untranscribed'));
    await store.save(entry('other-engine', transcript: transcriptBy('old.engine')));
    await store.save(entry('current', transcript: transcriptBy('fake.batch')));
    await store.save(
      entry('transcript-only', audio: false, transcript: transcriptBy('old.engine')),
    );
    final c = cubit();

    expect(c.state.runnable, 2);
    expect(c.state.current, 1);
    expect(c.state.progress.phase, RetranscribePhase.idle);

    await c.close();
    await service.dispose();
  });

  test('a start drives the state through running to done and refreshes the preview', () async {
    service = build(FakeBatchEngine());
    await store.save(entry('untranscribed'));
    final c = cubit();
    final phases = <RetranscribePhase>[];
    final sub = c.stream.listen((s) => phases.add(s.progress.phase));
    final done = c.stream.firstWhere((s) => s.progress.phase == RetranscribePhase.done);

    c.start();
    final landed = await done;
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(phases, contains(RetranscribePhase.running));
    expect(landed.progress.landed, 1);
    expect(c.state.runnable, 0);
    expect(c.state.current, 1);

    await c.close();
    await service.dispose();
  });

  test('cancel lands the run as cancelled', () async {
    final gate = Completer<void>();
    service = build(FakeBatchEngine(gate: gate.future));
    await store.save(entry('a'));
    await store.save(entry('b'));
    final c = cubit();
    final ended = c.stream.firstWhere((s) => s.progress.phase == RetranscribePhase.cancelled);

    c.start();
    await Future<void>.delayed(Duration.zero);
    c.cancel();
    gate.complete();
    final state = await ended;

    expect(state.progress.phase, RetranscribePhase.cancelled);
    expect(state.progress.done, lessThan(2));

    await c.close();
    await service.dispose();
  });

  test('an entriesChanged while idle refreshes the preview counts', () async {
    service = build(FakeBatchEngine());
    await store.save(entry('current', transcript: transcriptBy('fake.batch')));
    final c = cubit();
    expect(c.state.runnable, 0);

    await service.adoptImportedEntries([StagedImportEntry(entry: entry('restored'))]);
    await Future<void>.delayed(Duration.zero);

    expect(c.state.runnable, 1);
    expect(c.state.current, 1);

    await c.close();
    await service.dispose();
  });

  test('an engine switch while idle refreshes the preview against the new engine', () async {
    service = build(FakeBatchEngine());
    await store.save(entry('heard', transcript: transcriptBy('fake.batch')));
    final c = cubit();
    expect(c.state.runnable, 0);
    expect(c.state.current, 1);

    expect(service.useEngine(FakeDictationEngine()), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(c.state.runnable, 1);
    expect(c.state.current, 0);

    await c.close();
    await service.dispose();
  });

  test('a closed cubit ignores later runner emissions', () async {
    service = build(FakeBatchEngine());
    await store.save(entry('a'));
    final c = cubit();
    await c.close();

    final result = await service.retranscribeAll.start();

    expect(result.phase, RetranscribePhase.done);
    expect(c.state.progress.phase, RetranscribePhase.idle);

    await service.dispose();
  });
}
