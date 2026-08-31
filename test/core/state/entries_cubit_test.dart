import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  late TranscriptionService service;
  late FakeBatchEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    engine = FakeBatchEngine();
    service = TranscriptionService(
      composer: FakeAudioComposer(),
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

  test('edit updates the list and never touches busy', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    final busyIds = <String?>[];
    final sub = cubit.stream.listen((s) => busyIds.add(s.busyId));

    await cubit.edit(entry, 'fixed words');
    await sub.cancel();

    expect(cubit.state.entries.single.head?.text, 'fixed words');
    expect(cubit.state.entries.single.readableText, 'fixed words');
    expect(busyIds, everyElement(isNull));
    expect(cubit.state.error, isNull);

    await cubit.close();
  });

  test('an edit failure surfaces on its own entry and still refreshes', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    await service.deleteEntry(entry);

    await cubit.edit(entry, 'ghost');

    expect(cubit.state.errorFor(entry.id), isNotNull);
    expect(cubit.state.entries, isEmpty);
    expect(cubit.state.busyId, isNull);

    await cubit.close();
  });

  test('retranscribe replaces the head and keeps the edit in history', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    await cubit.edit(entry, 'fixed words');

    await cubit.retranscribe(entry);
    final landed = cubit.state.entries.single;
    expect(landed.readableText, isNot('fixed words'));
    expect(landed.revisions!.map((r) => r.text), contains('fixed words'));

    await cubit.close();
  });

  test('restore pushes an old revision back as the head', () async {
    final cubit = await seeded();
    await cubit.edit(cubit.state.entries.single, 'fixed words');
    final edited = cubit.state.entries.single;

    await cubit.restore(edited, edited.revisions!.first);

    final restored = cubit.state.entries.single;
    expect(restored.readableText, edited.revisions!.first.text);
    expect(restored.revisions, hasLength(3));
    expect(cubit.state.busyId, isNull);
    expect(cubit.state.error, isNull);

    await cubit.close();
  });

  test('deleteRevision trims the history in the list', () async {
    final cubit = await seeded();
    await cubit.edit(cubit.state.entries.single, 'fixed words');
    final edited = cubit.state.entries.single;

    await cubit.deleteRevision(edited, edited.revisions!.last);

    final trimmed = cubit.state.entries.single;
    expect(trimmed.revisions!.map((r) => r.text), isNot(contains('fixed words')));
    expect(cubit.state.error, isNull);

    await cubit.close();
  });

  test('a restore failure surfaces on its own entry and still refreshes', () async {
    final cubit = await seeded();
    await cubit.edit(cubit.state.entries.single, 'fixed words');
    final edited = cubit.state.entries.single;
    await service.deleteEntry(edited);

    await cubit.restore(edited, edited.revisions!.first);

    expect(cubit.state.errorFor(edited.id), isNotNull);
    expect(cubit.state.entries, isEmpty);

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
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final store = EntryStore(storage);
    final svc = TranscriptionService(
      composer: FakeAudioComposer(),
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
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final store = EntryStore(storage);
    final localEngine = FakeBatchEngine();
    final svc = TranscriptionService(
      composer: FakeAudioComposer(),
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
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final svc = TranscriptionService(
      composer: FakeAudioComposer(),
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

  test('re-transcribe quietly yields to a bulk run already on that entry', () async {
    final gate = Completer<void>();
    final gatedEngine = FakeBatchEngine(gate: gate.future);
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final store = EntryStore(storage);
    final svc = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(),
      engine: gatedEngine,
      store: store,
    );
    await store.save(
      Entry(
        id: 'queued',
        createdAt: DateTime.utc(2026, 3),
        audioPath: '/audio/queued.m4a',
        duration: const Duration(seconds: 3),
      ),
    );
    final cubit = EntriesCubit(service: svc);
    final run = svc.retranscribeAll.start();
    await Future<void>.delayed(Duration.zero);

    await cubit.retranscribe(store.read('queued')!);

    expect(cubit.state.error, isNull);
    expect(cubit.state.busyId, isNull);
    gate.complete();
    await run;
    expect(gatedEngine.batchCalls, hasLength(1));

    await cubit.close();
    await svc.dispose();
  });

  group('continuation', () {
    test('markContinuing sets busy and the outcome of a landing clears it', () async {
      final cubit = await seeded();
      final base = cubit.state.entries.single;

      expect(cubit.markContinuing(base), isTrue);
      expect(cubit.state.busyId, base.id);
      expect(cubit.state.busyAction, EntriesAction.continueRecording);

      await service.startRecording(continuing: base);
      await service.stopRecording();
      await pumpEventQueue();

      expect(cubit.state.busyId, isNull);
      expect(cubit.state.error, isNull);
      expect(cubit.state.entries.single.duration, const Duration(seconds: 4));

      await cubit.close();
    });

    test('an untranscribed addition pins its error to the base', () async {
      final cubit = await seeded();
      final base = cubit.state.entries.single;
      engine.failBatch = true;

      cubit.markContinuing(base);
      await service.startRecording(continuing: base);
      await service.stopRecording();
      await pumpEventQueue();

      expect(cubit.state.busyId, isNull);
      expect(cubit.state.errorFor(base.id), EntriesError.additionUntranscribed);

      await cubit.close();
    });

    test('a take saved separately pins the new entry to the base', () async {
      final storage = LocalService();
      await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
      final failing = TranscriptionService(
        composer: FakeAudioComposer(throwOnConcatenate: true),
        recorder: FakeAudioRecorder(),
        engine: FakeBatchEngine(),
        store: EntryStore(storage),
      );
      await failing.startRecording();
      final base = await failing.stopRecording();
      final cubit = EntriesCubit(service: failing);

      cubit.markContinuing(base);
      await failing.startRecording(continuing: base);
      final saved = await failing.stopRecording();
      await pumpEventQueue();

      expect(cubit.state.busyId, isNull);
      expect(
        cubit.state.error,
        EntriesFailure(entryId: base.id, kind: EntriesError.savedSeparately, relatedId: saved.id),
      );
      expect(cubit.state.entries, hasLength(2));

      await cubit.close();
      await failing.dispose();
    });

    test('a take whose own save failed clears the mark and pins nothing', () async {
      final storage = LocalService();
      await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
      final refusing = _TogglingRefuseStore(storage);
      final failing = TranscriptionService(
        composer: FakeAudioComposer(throwOnConcatenate: true),
        recorder: FakeAudioRecorder(),
        engine: FakeBatchEngine(),
        store: refusing,
      );
      await failing.startRecording();
      final base = await failing.stopRecording();
      final cubit = EntriesCubit(service: failing);
      refusing.refuse = true;

      cubit.markContinuing(base);
      await failing.startRecording(continuing: base);
      await expectLater(failing.stopRecording(), throwsA(isA<EntrySaveFailed>()));
      await pumpEventQueue();

      expect(cubit.state.busyId, isNull);
      expect(cubit.state.error, isNull);

      await cubit.close();
      await failing.dispose();
    });

    test('dismissFailure drops only the named entry\'s failure', () async {
      final cubit = await seeded();
      final base = cubit.state.entries.single;
      await service.deleteEntry(base);
      await cubit.rename(base, 'ghost');
      expect(cubit.state.error, isNotNull);

      cubit.dismissFailure('other');
      expect(cubit.state.error, isNotNull);
      cubit.dismissFailure(base.id);
      expect(cubit.state.error, isNull);

      await cubit.close();
    });

    test('clearContinuing clears only its own continuation', () async {
      final cubit = await seeded();
      final base = cubit.state.entries.single;

      cubit.clearContinuing(base.id);
      expect(cubit.state.busyId, isNull);
      cubit.markContinuing(base);
      cubit.clearContinuing('other');
      expect(cubit.state.busyId, base.id);
      cubit.clearContinuing(base.id);
      expect(cubit.state.busyId, isNull);

      await cubit.close();
    });

    test('an entry with an action in flight cannot be continued', () async {
      final cubit = await seeded();
      final base = cubit.state.entries.single;

      cubit.markContinuing(base);
      expect(cubit.canContinue(base), isFalse);
      expect(cubit.markContinuing(base), isFalse);
      cubit.clearContinuing(base.id);
      expect(cubit.canContinue(base), isTrue);

      await cubit.close();
    });

    test('delete is refused while the entry is being continued', () async {
      final cubit = await seeded();
      final base = cubit.state.entries.single;

      cubit.markContinuing(base);
      await cubit.delete(base);

      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.busyAction, EntriesAction.continueRecording);

      await cubit.close();
    });

    test('a refused start clears the mark and leaves no error', () async {
      final cubit = await seeded();
      final base = cubit.state.entries.single;
      final gate = Completer<void>();
      final held = FakeBatchEngine(gate: gate.future);
      service.useEngine(held);
      final batching = service.retranscribe(base);

      cubit.markContinuing(base);
      await expectLater(
        () => service.startRecording(continuing: base),
        throwsA(isA<ContinuationRefused>()),
      );
      await pumpEventQueue();
      gate.complete();
      await batching;

      expect(cubit.state.busyId, isNull);
      expect(cubit.state.error, isNull);

      await cubit.close();
    });

    test('a cancelled take clears the mark', () async {
      final cubit = await seeded();
      final base = cubit.state.entries.single;

      cubit.markContinuing(base);
      await service.startRecording(continuing: base);
      await service.cancelRecording();
      await pumpEventQueue();

      expect(cubit.state.busyId, isNull);

      await cubit.close();
    });

    test('retranscribe is refused while the entry is being continued', () async {
      final cubit = await seeded();
      final base = cubit.state.entries.single;

      cubit.markContinuing(base);
      await cubit.retranscribe(base);

      expect(engine.batchCalls, hasLength(1));
      expect(cubit.state.busyAction, EntriesAction.continueRecording);

      await cubit.close();
    });
  });
}

class _TogglingRefuseStore extends EntryStore {
  _TogglingRefuseStore(super.storage);

  bool refuse = false;

  @override
  Future<void> save(Entry entry) async {
    if (refuse) throw Exception('save refused');
    return super.save(entry);
  }
}
