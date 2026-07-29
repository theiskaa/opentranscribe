import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  late TranscriptionService service;
  late FakeBatchEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    engine = FakeBatchEngine();
    service = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: engine,
      store: EntryStore(storage),
    );
  });

  tearDown(() => service.dispose());

  Future<EntriesCubit> seeded() async {
    await service.startRecording();
    await service.stopRecording();
    return EntriesCubit(service: service);
  }

  test('seeds from the service so a fresh cubit is never empty', () async {
    final cubit = await seeded();
    expect(cubit.state.entries, hasLength(1));
    await cubit.close();
  });

  test('rename updates the list and clears busy', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;

    await cubit.rename(entry, 'Morning pages');

    expect(cubit.state.entries.single.title, 'Morning pages');
    expect(cubit.state.busyId, isNull);
    expect(cubit.state.error, isNull);

    await cubit.close();
  });

  test('a rename failure surfaces on error and still refreshes', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    await service.deleteEntry(entry);

    await cubit.rename(entry, 'ghost');

    expect(cubit.state.error, isNotNull);
    expect(cubit.state.entries, isEmpty);
    expect(cubit.state.busyId, isNull);

    await cubit.close();
  });

  test('delete removes the entry from the list', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;

    await cubit.delete(entry);

    expect(cubit.state.entries, isEmpty);
    await cubit.close();
  });

  test('a delete is busy as a delete, never as a transcribe', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    final seen = <EntriesAction?>[];
    final sub = cubit.stream.listen((s) => seen.add(s.busyAction));

    await cubit.delete(entry);

    // The transcript view dissolves on a transcribe-busy entry; a delete
    // wearing the wrong kind would run the shimmer on its way out.
    expect(seen, contains(EntriesAction.delete));
    expect(seen, isNot(contains(EntriesAction.transcribe)));
    expect(cubit.state.busyAction, isNull);

    await sub.cancel();
    await cubit.close();
  });

  test('a retranscribe is busy as a transcribe, and clears when it lands', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    final seen = <EntriesAction?>[];
    final sub = cubit.stream.listen((s) => seen.add(s.busyAction));

    await cubit.retranscribe(entry);

    expect(seen, contains(EntriesAction.transcribe));
    expect(cubit.state.busyAction, isNull);
    expect(cubit.state.busyId, isNull);

    await sub.cancel();
    await cubit.close();
  });

  test('retranscribe swaps in the fresh transcript', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;

    await cubit.retranscribe(entry);

    expect(cubit.state.entries.single.isTranscribed, isTrue);
    await cubit.close();
  });

  test('every failure bumps the tick, so a repeat can re-announce itself', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    await service.deleteEntry(entry);

    await cubit.rename(entry, 'ghost');
    final first = cubit.state.errorTick;
    await cubit.rename(entry, 'ghost again');

    expect(first, greaterThan(0));
    expect(cubit.state.errorTick, greaterThan(first));

    await cubit.close();
  });

  test('a failure is pinned to its entry, invisible on any other', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    await service.deleteEntry(entry);

    await cubit.rename(entry, 'ghost');

    expect(cubit.state.error?.entryId, entry.id);
    expect(cubit.state.errorFor(entry.id), EntriesError.generic);
    expect(cubit.state.errorFor('someone-else'), isNull);

    await cubit.close();
  });

  test('a retry in flight keeps the standing error, so the pill never blinks', () async {
    engine.failBatch = true;
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    await cubit.retranscribe(entry);
    expect(cubit.state.errorFor(entry.id), isNotNull);

    final seen = <bool>[];
    final sub = cubit.stream.listen((s) => seen.add(s.error != null));
    await cubit.retranscribe(entry);
    await sub.cancel();

    expect(seen, isNotEmpty);
    expect(seen, everyElement(isTrue));
    await cubit.close();
  });

  test('a retry that succeeds clears the standing error', () async {
    engine.failBatch = true;
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    await cubit.retranscribe(entry);
    expect(cubit.state.errorFor(entry.id), isNotNull);

    engine.failBatch = false;
    await cubit.retranscribe(entry);

    expect(cubit.state.errorFor(entry.id), isNull);
    expect(cubit.state.entries.single.isTranscribed, isTrue);
    await cubit.close();
  });

  test('keep-off: a first-success retranscribe lands transcript-only in the list', () async {
    // The branch's headline behavior at the state layer: after the deferred
    // discard completes, the list must reflect the transcript-only entry.
    final dir = await Directory.systemTemp.createTemp('otr-cubitkeep');
    final file = File('${dir.path}/clip.m4a')..writeAsStringSync('audio');
    final storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    final store = EntryStore(storage);
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      engine: FakeBatchEngine(cannedText: 'finally'),
      store: store,
      keepAudio: () => false,
    );
    await store.save(
      Entry(
        id: 'k1',
        createdAt: DateTime.utc(2026, 3, 4),
        audioPath: 'clip.m4a',
        duration: const Duration(seconds: 1),
      ),
    );
    final cubit = EntriesCubit(service: svc);

    await cubit.retranscribe(cubit.state.entries.single);
    await pumpEventQueue();

    final listed = cubit.state.entries.single;
    expect(listed.transcript?.fullText, 'finally');
    expect(listed.hasAudio, isFalse);
    expect(cubit.state.error, isNull);
    expect(file.existsSync(), isFalse);

    await cubit.close();
    await svc.dispose();
    await dir.delete(recursive: true);
  });

  test('retranscribe of a transcript-only entry pins a failure, never the zone', () async {
    final storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    final store = EntryStore(storage);
    final localEngine = FakeBatchEngine();
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: localEngine,
      store: store,
    );
    await store.save(
      Entry(
        id: 'b1',
        createdAt: DateTime.utc(2026, 3, 4),
        audioPath: null,
        duration: Duration.zero,
      ),
    );
    final cubit = EntriesCubit(service: svc);

    // A stale open menu can still fire this; the StateError must be caught,
    // pinned to the entry, and the list left consistent.
    await cubit.retranscribe(cubit.state.entries.single);

    expect(cubit.state.errorFor('b1'), EntriesError.generic);
    expect(cubit.state.entries.single.hasAudio, isFalse);
    expect(localEngine.batchCalls, isEmpty);

    await cubit.close();
    await svc.dispose();
  });

  test('a detached discard refreshes the list without a manual load', () async {
    final dir = await Directory.systemTemp.createTemp('otr-cubitdisc');
    File('${dir.path}/take.m4a').writeAsStringSync('audio');
    final storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
      engine: FakeBatchEngine(),
      store: EntryStore(storage),
      keepAudio: () => false,
    );
    final cubit = EntriesCubit(service: svc);

    await svc.startRecording();
    await svc.stopRecording();
    cubit.load();
    // The discard lands detached and announces itself; wait on that emit.
    await cubit.stream
        .firstWhere((s) => s.entries.isNotEmpty && !s.entries.single.hasAudio)
        .timeout(const Duration(seconds: 5));

    expect(cubit.state.entries.single.hasAudio, isFalse);

    await cubit.close();
    await svc.dispose();
    await dir.delete(recursive: true);
  });
}
