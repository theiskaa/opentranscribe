import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/retranscribe_runner.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  final fixedClock = DateTime.utc(2026, 3, 4, 12);

  late LocalService storage;
  late EntryStore store;
  var idCounter = 0;

  TranscriptionService build(
    TranscriptionEngine engine, {
    FakeAudioRecorder? recorder,
    bool Function()? thermalPressure,
  }) {
    idCounter = 0;
    return TranscriptionService(
      recorder: recorder ?? FakeAudioRecorder(),
      engine: engine,
      store: store,
      clock: () => fixedClock,
      idGenerator: () => 'id-${idCounter++}',
      fileDeleter: (f) async {},
      thermalPressure: thermalPressure,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    store = EntryStore(storage);
  });

  Transcript transcriptBy(String engineId, {String text = 'old words'}) => Transcript(
    fullText: text,
    segments: [
      TranscriptSegment(text: text, start: Duration.zero, end: const Duration(seconds: 1)),
    ],
    localeId: 'en-US',
    engineId: engineId,
    createdAt: fixedClock,
  );

  Entry entry(
    String id, {
    int minute = 0,
    bool audio = true,
    Transcript? transcript,
    String? localeId,
  }) => Entry(
    id: id,
    createdAt: DateTime.utc(2026, 3, 1, 10, minute),
    audioPath: audio ? '/audio/$id.m4a' : null,
    duration: const Duration(seconds: 3),
    transcript: transcript,
    recordedLocaleId: localeId,
  );

  test(
    'the queue runs untranscribed and other-engine entries, oldest first, and skips the rest',
    () async {
      final engine = FakeBatchEngine();
      final svc = build(engine);
      await store.save(entry('untranscribed', minute: 2, localeId: 'de-DE'));
      await store.save(entry('other-engine', minute: 1, transcript: transcriptBy('old.engine')));
      await store.save(entry('current', transcript: transcriptBy('fake.batch')));
      await store.save(entry('no-audio', minute: 3, audio: false));

      final result = await svc.retranscribeAll.start();

      expect(result.phase, RetranscribePhase.done);
      expect(result.total, 2);
      expect(result.landed, 2);
      expect(result.failed, 0);
      expect(engine.batchCalls.map((c) => c.localeId), ['en-US', 'de-DE']);
      expect(store.read('untranscribed')!.transcript?.engineId, 'fake.batch');
      expect(store.read('other-engine')!.transcript?.engineId, 'fake.batch');
      expect(store.read('current')!.transcript, transcriptBy('fake.batch'));
      expect(store.read('no-audio')!.transcript, isNull);

      await svc.dispose();
    },
  );

  test('progress streams the run in order, one settle per entry', () async {
    final svc = build(FakeBatchEngine());
    await store.save(entry('a'));
    await store.save(entry('b', minute: 1));
    final seen = <RetranscribeProgress>[];
    final sub = svc.retranscribeAll.stream.listen(seen.add);

    await svc.retranscribeAll.start();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen.map((p) => p.phase).toSet(), {RetranscribePhase.running, RetranscribePhase.done});
    expect(seen.first, const RetranscribeProgress(phase: RetranscribePhase.running, total: 2));
    expect(seen.map((p) => p.currentEntryId).where((id) => id != null), ['a', 'b']);
    expect(seen.map((p) => p.done).toList(), [0, 0, 1, 1, 2, 2]);
    expect(seen.last.phase, RetranscribePhase.done);
    expect(svc.retranscribeAll.state, seen.last);

    await svc.dispose();
  });

  test('a failing entry counts as failed, keeps its state, and the queue moves on', () async {
    final engine = FakeBatchEngine()
      ..transcriptBuilder = (localeId, start, end) {
        if (localeId == 'xx-XX') throw const TranscriptionFailed('fake');
        return 'new words';
      };
    final svc = build(engine);
    await store.save(entry('bad', localeId: 'xx-XX'));
    await store.save(entry('good', minute: 1));

    final result = await svc.retranscribeAll.start();

    expect(result.phase, RetranscribePhase.done);
    expect(result.landed, 1);
    expect(result.failed, 1);
    expect(store.read('bad')!.transcript, isNull);
    expect(store.read('good')!.transcript?.fullText, 'new words');
    expect(svc.retranscribeAll.runnable(store.read('bad')!), isTrue);

    await svc.dispose();
  });

  test('every landing announces entriesChanged so list surfaces refresh', () async {
    final svc = build(FakeBatchEngine());
    await store.save(entry('a'));
    await store.save(entry('b', minute: 1));
    var announced = 0;
    final sub = svc.entriesChanged.listen((_) => announced++);

    await svc.retranscribeAll.start();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(announced, 2);

    await svc.dispose();
  });

  test(
    'cancel mid-entry hard-cancels the batch, keeps the count honest, and stops the queue',
    () async {
      late final TranscriptionService svc;
      final engine = FakeBatchEngine()
        ..transcriptBuilder = (localeId, start, end) {
          svc.retranscribeAll.cancel();
          throw const TranscriptionFailed('cancelled under the runner');
        };
      svc = build(engine);
      await store.save(entry('a'));
      await store.save(entry('b', minute: 1));

      final result = await svc.retranscribeAll.start();

      expect(result.phase, RetranscribePhase.cancelled);
      expect(result.landed, 0);
      expect(result.failed, 0);
      expect(engine.batchCalls, hasLength(1));
      expect(engine.cancelBatchesCalls, 1);

      await svc.dispose();
    },
  );

  test('a queued entry deleted mid-run shrinks the total instead of failing', () async {
    late final TranscriptionService svc;
    final engine = FakeBatchEngine()
      ..transcriptBuilder = (localeId, start, end) {
        unawaited(store.delete('b'));
        return 'new words';
      };
    svc = build(engine);
    await store.save(entry('a'));
    await store.save(entry('b', minute: 1));

    final result = await svc.retranscribeAll.start();

    expect(result.phase, RetranscribePhase.done);
    expect(result.total, 1);
    expect(result.landed, 1);
    expect(result.failed, 0);
    expect(engine.batchCalls, hasLength(1));

    await svc.dispose();
  });

  test('the queue holds while a take is live and resumes after the stop', () async {
    final recorder = FakeAudioRecorder();
    final svc = build(FakeBatchEngine(), recorder: recorder);
    await store.save(entry('a'));
    await svc.startRecording();
    var stopped = false;
    svc.retranscribeAll.wait = () async {
      if (!stopped) {
        stopped = true;
        await svc.stopRecording();
      }
    };
    final seen = <RetranscribeProgress>[];
    final sub = svc.retranscribeAll.stream.listen(seen.add);

    final result = await svc.retranscribeAll.start();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen.any((p) => p.waiting), isTrue);
    expect(result.phase, RetranscribePhase.done);
    expect(result.landed, 1);
    expect(store.read('a')!.transcript, isNotNull);

    await svc.dispose();
  });

  test('the queue holds under thermal pressure and resumes when it lifts', () async {
    var hot = true;
    final engine = FakeBatchEngine();
    final svc = build(engine, thermalPressure: () => hot);
    await store.save(entry('a'));
    svc.retranscribeAll.wait = () async => hot = false;
    final seen = <RetranscribeProgress>[];
    final sub = svc.retranscribeAll.stream.listen(seen.add);

    final result = await svc.retranscribeAll.start();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen.any((p) => p.hold == RetranscribeHold.thermal), isTrue);
    expect(result.phase, RetranscribePhase.done);
    expect(result.landed, 1);

    await svc.dispose();
  });

  test('a live take outranks thermal pressure in the hold it reports', () async {
    final svc = build(FakeBatchEngine(), thermalPressure: () => true);
    await store.save(entry('a'));
    await svc.startRecording();
    var released = false;
    svc.retranscribeAll.wait = () async {
      if (!released) {
        released = true;
        await svc.stopRecording();
        svc.retranscribeAll.cancel();
      }
    };
    final seen = <RetranscribeProgress>[];
    final sub = svc.retranscribeAll.stream.listen(seen.add);

    final result = await svc.retranscribeAll.start();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen.first.hold, RetranscribeHold.none);
    expect(seen.any((p) => p.hold == RetranscribeHold.capture), isTrue);
    expect(seen.any((p) => p.hold == RetranscribeHold.thermal), isFalse);
    expect(result.phase, RetranscribePhase.cancelled);

    await svc.dispose();
  });

  test('cancel while deferred stops the queue without touching the engine', () async {
    final engine = FakeBatchEngine();
    final svc = build(engine);
    await store.save(entry('a'));
    await svc.startRecording();
    svc.retranscribeAll.wait = () async => svc.retranscribeAll.cancel();

    final result = await svc.retranscribeAll.start();

    expect(result.phase, RetranscribePhase.cancelled);
    expect(engine.batchCalls, isEmpty);
    expect(engine.cancelBatchesCalls, 0);

    await svc.stopRecording();
    await svc.dispose();
  });

  test('start is single-flight: a second call rides the run already in flight', () async {
    final gate = Completer<void>();
    final engine = FakeBatchEngine(gate: gate.future);
    final svc = build(engine);
    await store.save(entry('a'));

    final first = svc.retranscribeAll.start();
    expect(svc.retranscribeAll.isRunning, isTrue);
    final second = svc.retranscribeAll.start();
    gate.complete();
    final results = await Future.wait([first, second]);

    expect(identical(results[0], results[1]), isTrue);
    expect(engine.batchCalls, hasLength(1));
    expect(svc.retranscribeAll.isRunning, isFalse);

    await svc.dispose();
  });

  test('a run after a terminal state starts fresh with reset counts', () async {
    final engine = FakeBatchEngine()
      ..transcriptBuilder = (localeId, start, end) => throw const TranscriptionFailed('fake');
    final svc = build(engine);
    await store.save(entry('a'));

    final first = await svc.retranscribeAll.start();
    expect(first.failed, 1);
    final second = await svc.retranscribeAll.start();

    expect(second.phase, RetranscribePhase.done);
    expect(second.total, 1);
    expect(second.failed, 1);
    expect(second.landed, 0);

    await svc.dispose();
  });

  test(
    'a concurrent re-transcribe of the same entry refuses instead of running the file twice',
    () async {
      final gate = Completer<void>();
      final engine = FakeBatchEngine(gate: gate.future);
      final svc = build(engine);
      await store.save(entry('a'));

      final first = svc.retranscribe(store.read('a')!);
      await expectLater(svc.retranscribe(store.read('a')!), throwsStateError);
      gate.complete();
      await first;

      expect(engine.batchCalls, hasLength(1));

      await svc.dispose();
    },
  );

  test('bulk cancel never hard-cancels while a user re-transcribe is in flight', () async {
    final gate = Completer<void>();
    final engine = FakeBatchEngine(gate: gate.future);
    final svc = build(engine);
    await store.save(entry('bulk'));
    await store.save(entry('user', minute: 1, transcript: transcriptBy('fake.batch')));

    final run = svc.retranscribeAll.start();
    await Future<void>.delayed(Duration.zero);
    final user = svc.retranscribe(store.read('user')!);
    await Future<void>.delayed(Duration.zero);
    svc.retranscribeAll.cancel();

    expect(engine.cancelBatchesCalls, 0);

    gate.complete();
    await user;
    final result = await run;
    expect(result.phase, RetranscribePhase.cancelled);

    await svc.dispose();
  });

  test('an entry deleted during its own batch shrinks the total instead of failing', () async {
    late final TranscriptionService svc;
    final engine = FakeBatchEngine()
      ..transcriptBuilder = (localeId, start, end) {
        unawaited(store.delete('a'));
        return 'new words';
      };
    svc = build(engine);
    await store.save(entry('a'));

    final result = await svc.retranscribeAll.start();

    expect(result.phase, RetranscribePhase.done);
    expect(result.total, 0);
    expect(result.landed, 0);
    expect(result.failed, 0);

    await svc.dispose();
  });

  test('dispose mid-run ends the queue as a cancel without throwing', () async {
    final gate = Completer<void>();
    final engine = FakeBatchEngine(gate: gate.future);
    final svc = build(engine);
    await store.save(entry('a'));
    await store.save(entry('b', minute: 1));

    final run = svc.retranscribeAll.start();
    await svc.dispose();
    gate.complete();
    final result = await run;

    expect(result.phase, RetranscribePhase.cancelled);
    expect(engine.batchCalls, hasLength(1));
  });
}
