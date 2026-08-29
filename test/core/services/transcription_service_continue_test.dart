import 'dart:async';
import 'dart:io';

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
  final fixedClock = DateTime.utc(2026, 3, 4, 12);
  const baseDuration = Duration(seconds: 10);
  const tailDuration = Duration(seconds: 2);

  late LocalService storage;
  late EntryStore store;
  late Directory dir;
  late File baseFile;
  late File tailFile;
  late FakeAudioRecorder recorder;
  late FakeAudioComposer composer;
  var idCounter = 0;

  Transcript heard(
    String text, {
    String localeId = 'en-US',
    String engineId = 'fake',
  }) => Transcript(
    fullText: text,
    segments: text.isEmpty
        ? const []
        : [TranscriptSegment(text: text, start: Duration.zero, end: const Duration(seconds: 1))],
    localeId: localeId,
    engineId: engineId,
    createdAt: fixedClock,
  );

  Future<Entry> seedBase({
    Transcript? transcript,
    List<Revision>? revisions,
    List<LanguageSpan>? spans,
    String? recordedLocaleId = 'en-US',
    List<int>? peaks = const [7],
  }) async {
    final entry = Entry(
      id: 'base',
      createdAt: fixedClock,
      audioPath: 'base.m4a',
      duration: baseDuration,
      transcript: transcript,
      recordedLocaleId: recordedLocaleId,
      peaks: peaks,
      languageSpans: spans,
      revisions: revisions,
    );
    await store.save(entry);
    return entry;
  }

  TranscriptionService build(
    TranscriptionEngine engine, {
    EntryStore? using,
    bool Function()? keepAudio,
    Future<List<double>> Function(String path)? peaksReader,
  }) {
    idCounter = 0;
    return TranscriptionService(
      recorder: recorder,
      engine: engine,
      store: using ?? store,
      composer: composer,
      clock: () => fixedClock,
      idGenerator: () => 'id-${idCounter++}',
      keepAudio: keepAudio,
      fileDeleter: (f) async => f.deleteSync(),
      peaksReader: peaksReader,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    store = EntryStore(storage);
    dir = await Directory.systemTemp.createTemp('otr-continue');
    baseFile = File('${dir.path}/base.m4a')..writeAsStringSync('base');
    tailFile = File('${dir.path}/tail.m4a')..writeAsStringSync('tail');
    recorder = FakeAudioRecorder(recordingsDir: dir.path, path: 'tail.m4a');
    composer = FakeAudioComposer(
      name: 'merged.m4a',
      durations: const {'base.m4a': baseDuration, 'tail.m4a': tailDuration},
    );
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('a continuation lands on the base with the merged file and a grown transcript', () async {
    await seedBase(transcript: heard('first thoughts'));
    final engine = FakeBatchEngine(cannedText: 'and then more');
    final svc = build(engine, peaksReader: (_) async => [0.5]);
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await svc.startRecording(continuing: store.read('base'));
    final landed = await svc.stopRecording();
    await pumpEventQueue();

    expect(landed.id, 'base');
    expect(landed.audioPath, 'merged.m4a');
    expect(landed.duration, baseDuration + tailDuration);
    expect(landed.transcript?.fullText, 'first thoughts and then more');
    expect(landed.transcript?.segments.last.start, baseDuration);
    expect(landed.transcript?.localeId, 'en-US');
    expect(landed.languageSpans, isNull);
    expect(landed.revisions, isNull);
    expect(composer.calls, [
      ['base.m4a', 'tail.m4a'],
    ]);
    expect(engine.batchCalls, hasLength(1));
    final stored = store.read('base')!;
    expect(stored.peaks, [128]);
    expect(outcomes.single, ContinuationLanded(entry: landed));
    expect(svc.entries().map((e) => e.id), ['base']);

    await svc.dispose();
  });

  test('the old base file and the tail are removed once the record points at the merge', () async {
    await seedBase(transcript: heard('a'));
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    await svc.stopRecording();

    expect(baseFile.existsSync(), isFalse);
    expect(tailFile.existsSync(), isFalse);

    await svc.dispose();
  });

  test('a hand-edited base keeps its edit and grows a hand head', () async {
    final base = heard('heard words');
    await seedBase(
      transcript: base,
      revisions: [
        Revision.ofTranscript(base),
        Revision(text: 'typed words', at: fixedClock),
      ],
    );
    final svc = build(FakeBatchEngine(cannedText: 'more'));

    await svc.startRecording(continuing: store.read('base'));
    final landed = await svc.stopRecording();

    expect(landed.readableText, 'typed words more');
    expect(landed.head?.isHand, isTrue);
    expect(landed.revisions, hasLength(3));
    expect(landed.transcript?.fullText, 'heard words more');
    expect(landed.readsAsTranscript, isFalse);

    await svc.dispose();
  });

  test('a take in another language earns the marker in text, segment and spans', () async {
    await seedBase(transcript: heard('hello'));
    final engine = FakeBatchEngine(cannedText: 'bonjour', supportedLocaleTags: ['en-US', 'fr-FR']);
    final svc = build(engine);

    await svc.startRecording(continuing: store.read('base'), localeId: 'fr-FR');
    final landed = await svc.stopRecording();

    expect(engine.batchCalls.single.localeId, 'fr-FR');
    expect(landed.transcript?.fullText, 'hello [fr] bonjour');
    expect(landed.transcript?.segments[1].text, '[fr]');
    expect(landed.transcript?.segments[1].start, baseDuration);
    expect(landed.languageSpans, const [
      LanguageSpan(startMs: 0, localeId: 'en-US'),
      LanguageSpan(startMs: 10000, localeId: 'fr-FR'),
    ]);

    await svc.dispose();
  });

  test('a base deleted mid-take files the tail as its own entry', () async {
    await seedBase(transcript: heard('a'));
    final svc = build(FakeBatchEngine(cannedText: 'b'));
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await svc.startRecording(continuing: store.read('base'));
    await svc.deleteEntry(store.read('base')!);
    final saved = await svc.stopRecording();
    await pumpEventQueue();

    expect(saved.id, 'id-0');
    expect(saved.audioPath, 'tail.m4a');
    expect(saved.transcript?.fullText, 'b');
    expect(composer.calls, isEmpty);
    expect(
      outcomes.single,
      ContinuationFellBack(baseId: 'base', reason: ContinuationFallback.deleted, entry: saved),
    );

    await svc.dispose();
  });

  test('a failed merge files the tail as its own entry and leaves the base untouched', () async {
    final base = await seedBase(transcript: heard('a'));
    composer = FakeAudioComposer(throwOnConcatenate: true);
    final svc = build(FakeBatchEngine(cannedText: 'b'));
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await svc.startRecording(continuing: base);
    final saved = await svc.stopRecording();
    await pumpEventQueue();

    expect(saved.id, 'id-0');
    expect(saved.audioPath, 'tail.m4a');
    expect(store.read('base'), base);
    expect(baseFile.existsSync(), isTrue);
    expect(tailFile.existsSync(), isTrue);
    expect(
      outcomes.single,
      ContinuationFellBack(baseId: 'base', reason: ContinuationFallback.mergeFailed, entry: saved),
    );

    await svc.dispose();
  });

  test('a failed save of the grown record drops the merge and files the tail', () async {
    final base = await seedBase(transcript: heard('a'));
    final merged = File('${dir.path}/merged.m4a')..writeAsStringSync('merged');
    final svc = build(FakeBatchEngine(cannedText: 'b'), using: _RefusingIdStore(storage, 'base'));
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await svc.startRecording(continuing: base);
    final saved = await svc.stopRecording();
    await pumpEventQueue();

    expect(merged.existsSync(), isFalse);
    expect(saved.id, 'id-0');
    expect(saved.audioPath, 'tail.m4a');
    expect(store.read('base'), base);
    expect(baseFile.existsSync(), isTrue);
    expect(tailFile.existsSync(), isTrue);
    expect(
      outcomes.single,
      ContinuationFellBack(baseId: 'base', reason: ContinuationFallback.saveFailed, entry: saved),
    );

    await svc.dispose();
  });

  test('a fallback whose own save fails surfaces EntrySaveFailed and reports no entry', () async {
    final base = await seedBase(transcript: heard('a'));
    composer = FakeAudioComposer(throwOnConcatenate: true);
    final svc = build(FakeBatchEngine(cannedText: 'b'), using: _RefusingIdStore(storage, 'id-0'));
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await svc.startRecording(continuing: base);
    await expectLater(svc.stopRecording(), throwsA(isA<EntrySaveFailed>()));
    await pumpEventQueue();

    expect(
      outcomes.single,
      const ContinuationFellBack(baseId: 'base', reason: ContinuationFallback.mergeFailed),
    );

    await svc.dispose();
  });

  test('a failed tail batch merges the audio and keeps the base words', () async {
    await seedBase(transcript: heard('kept'));
    final svc = build(FakeBatchEngine(failBatch: true));
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await svc.startRecording(continuing: store.read('base'));
    final landed = await svc.stopRecording();
    await pumpEventQueue();

    expect(landed.audioPath, 'merged.m4a');
    expect(landed.duration, baseDuration + tailDuration);
    expect(landed.transcript?.fullText, 'kept');
    expect(landed.revisions, isNull);
    expect(outcomes.single, ContinuationLanded(entry: landed, additionUntranscribed: true));

    await svc.dispose();
  });

  test('a silent take merges the audio and pushes nothing', () async {
    final base = heard('kept');
    await seedBase(transcript: base, revisions: [Revision.ofTranscript(base)]);
    final svc = build(FakeBatchEngine(cannedText: ''));

    await svc.startRecording(continuing: store.read('base'));
    final landed = await svc.stopRecording();

    expect(landed.audioPath, 'merged.m4a');
    expect(landed.transcript?.fullText, 'kept');
    expect(landed.revisions, hasLength(1));

    await svc.dispose();
  });

  test('a never-transcribed base gets one pass over the whole merged file', () async {
    await seedBase(recordedLocaleId: 'de-DE');
    final engine = FakeBatchEngine(cannedText: 'alles', supportedLocaleTags: ['en-US', 'de-DE']);
    final svc = build(engine);

    await svc.startRecording(continuing: store.read('base'), localeId: 'de-DE');
    final landed = await svc.stopRecording();

    expect(engine.batchCalls.single.localeId, 'de-DE');
    expect(engine.batchCalls.single.start, isNull);
    expect(landed.transcript?.fullText, 'alles');
    expect(landed.transcript?.localeId, 'de-DE');
    expect(landed.languageSpans, isNull);
    expect(landed.duration, baseDuration + tailDuration);

    await svc.dispose();
  });

  test('keep-audio off never discards a merged file', () async {
    await seedBase(transcript: heard('a'));
    final svc = build(FakeBatchEngine(cannedText: 'b'), keepAudio: () => false);

    await svc.startRecording(continuing: store.read('base'));
    await svc.stopRecording();
    await pumpEventQueue();

    expect(store.read('base')?.audioPath, 'merged.m4a');

    await svc.dispose();
  });

  test('the base is claimed against re-transcription for the life of the take', () async {
    await seedBase(transcript: heard('a'));
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    await expectLater(svc.retranscribe(store.read('base')!), throwsStateError);
    await svc.stopRecording();

    final again = await svc.retranscribe(store.read('base')!);
    expect(again.transcript?.fullText, 'b');

    await svc.dispose();
  });

  test('a base mid-batch cannot be continued', () async {
    await seedBase(transcript: heard('a'));
    final gate = Completer<void>();
    final svc = build(FakeBatchEngine(cannedText: 'b', gate: gate.future));

    final pending = svc.retranscribe(store.read('base')!);
    await expectLater(
      () => svc.startRecording(continuing: store.read('base')),
      throwsA(isA<ContinuationRefused>()),
    );
    expect(svc.isRecording, isFalse);
    gate.complete();
    await pending;

    await svc.dispose();
  });

  test('a transcript-only base cannot be continued', () async {
    await seedBase(transcript: heard('a'));
    await store.save(store.read('base')!.withoutAudio());
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await expectLater(
      () => svc.startRecording(continuing: store.read('base')),
      throwsA(isA<ContinuationRefused>()),
    );
    expect(svc.isRecording, isFalse);

    await svc.dispose();
  });

  test('a second continuation while one take is live is refused as already recording', () async {
    await seedBase(transcript: heard('a'));
    final other = Entry(
      id: 'other',
      createdAt: fixedClock,
      audioPath: 'other.m4a',
      duration: baseDuration,
    );
    await store.save(other);
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    await expectLater(
      () => svc.startRecording(continuing: other),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'already recording')),
    );
    await svc.stopRecording();

    final again = await svc.retranscribe(other);
    expect(again.id, 'other');

    await svc.dispose();
  });

  test('a cancelled continuation discards the tail and releases the base', () async {
    final base = await seedBase(transcript: heard('a'));
    final svc = build(FakeBatchEngine(cannedText: 'b'));
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await svc.startRecording(continuing: base);
    await svc.cancelRecording();
    await pumpEventQueue();

    expect(outcomes.single, const ContinuationDiscarded(baseId: 'base'));
    expect(recorder.cancelled, isTrue);
    expect(store.read('base'), base);
    expect(composer.calls, isEmpty);
    final again = await svc.retranscribe(base);
    expect(again.transcript?.fullText, 'b');

    await svc.dispose();
  });

  test(
    'an interruption lands the continuation without words and a later cancel spares it',
    () async {
      await seedBase(transcript: heard('a'));
      final svc = build(FakeBatchEngine(cannedText: 'b'));
      final auto = <Entry>[];
      svc.autoFinalized.listen(auto.add);
      final outcomes = <ContinuationOutcome>[];
      svc.continuations.listen(outcomes.add);

      await svc.startRecording(continuing: store.read('base'));
      recorder.interrupt();
      await pumpEventQueue();

      expect(auto.single.id, 'base');
      expect(auto.single.audioPath, 'merged.m4a');
      expect(auto.single.transcript?.fullText, 'a');
      expect(outcomes.single, ContinuationLanded(entry: auto.single, additionUntranscribed: true));

      await svc.cancelRecording();
      expect(store.read('base')?.audioPath, 'merged.m4a');

      await svc.dispose();
    },
  );

  test('a termination mid-continuation merges the audio untranscribed', () async {
    await seedBase(transcript: heard('a'));
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    await svc.finalizeActiveCapture();

    final stored = store.read('base')!;
    expect(stored.audioPath, 'merged.m4a');
    expect(stored.duration, baseDuration + tailDuration);
    expect(stored.transcript?.fullText, 'a');

    await svc.dispose();
  });

  test('the orphan sweep stands aside during a landing and adopts nothing after', () async {
    await seedBase(transcript: heard('a'));
    final gate = Completer<void>();
    composer.gate = gate.future;
    recorder = FakeAudioRecorder(
      recordingsDir: dir.path,
      path: 'tail.m4a',
      probe: (_) => const Duration(seconds: 1),
    );
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    final stopping = svc.stopRecording();
    await pumpEventQueue();
    expect(await svc.reconcileOrphans(), isNull);
    gate.complete();
    await stopping;
    File('${dir.path}/merged.m4a').writeAsStringSync('merged');

    expect(await svc.reconcileOrphans(), 0);
    expect(svc.entries().map((e) => e.id), ['base']);

    await svc.dispose();
  });

  test('a purge mid-continuation leaves the base alone', () async {
    await seedBase(transcript: heard('a'));
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    expect(await svc.purgeTranscribedAudio(), 0);
    expect(store.read('base')?.audioPath, 'base.m4a');
    await svc.stopRecording();

    expect(store.read('base')?.audioPath, 'merged.m4a');

    await svc.dispose();
  });

  test('startRecording opens a fresh take in the language it was asked for', () async {
    final engine = FakeBatchEngine(cannedText: 'hola', supportedLocaleTags: ['en-US', 'es-ES']);
    final svc = build(engine);

    await svc.startRecording(localeId: 'es-ES');
    final entry = await svc.stopRecording();

    expect(engine.batchCalls.single.localeId, 'es-ES');
    expect(entry.recordedLocaleId, 'es-ES');
    expect(entry.transcript?.localeId, 'es-ES');

    await svc.dispose();
  });

  test('continuingEntryId names the base only while the take is live', () async {
    await seedBase(transcript: heard('a'));
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    expect(svc.continuingEntryId, isNull);
    await svc.startRecording(continuing: store.read('base'));
    expect(svc.continuingEntryId, 'base');
    await svc.stopRecording();
    expect(svc.continuingEntryId, isNull);

    await svc.dispose();
  });

  test('a delete during the merge files the tail alone and never resurrects the base', () async {
    await seedBase(transcript: heard('a'));
    final gate = Completer<void>();
    composer.gate = gate.future;
    final merged = File('${dir.path}/merged.m4a')..writeAsStringSync('merged');
    final svc = build(FakeBatchEngine(cannedText: 'b'));
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await svc.startRecording(continuing: store.read('base'));
    final stopping = svc.stopRecording();
    await pumpEventQueue();
    await svc.deleteEntry(store.read('base')!);
    gate.complete();
    final saved = await stopping;
    await pumpEventQueue();

    expect(store.read('base'), isNull);
    expect(saved.id, 'id-0');
    expect(merged.existsSync(), isFalse);
    expect(
      outcomes.single,
      ContinuationFellBack(baseId: 'base', reason: ContinuationFallback.deleted, entry: saved),
    );

    await svc.dispose();
  });

  test('a rename during the merge survives the landing', () async {
    await seedBase(transcript: heard('a'));
    final gate = Completer<void>();
    composer.gate = gate.future;
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    final stopping = svc.stopRecording();
    await pumpEventQueue();
    await svc.renameEntry(store.read('base')!, 'renamed');
    gate.complete();
    final landed = await stopping;

    expect(landed.title, 'renamed');
    expect(landed.transcript?.fullText, 'a b');

    await svc.dispose();
  });

  test('a base another entry shares its file with keeps that file on landing', () async {
    await seedBase(transcript: heard('a'));
    await store.save(
      Entry(id: 'twin', createdAt: fixedClock, audioPath: 'base.m4a', duration: baseDuration),
    );
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    await svc.stopRecording();

    expect(baseFile.existsSync(), isTrue);
    expect(tailFile.existsSync(), isFalse);
    expect(store.read('twin')?.audioPath, 'base.m4a');

    await svc.dispose();
  });

  test('a salvaged tail stitches untimed onto its base', () async {
    await seedBase(transcript: heard('heard'));
    final svc = build(
      FakeStreamingEngine(cannedText: 'live words', batchText: '', stopSignal: recorder.stopped),
    );

    await svc.startRecording(continuing: store.read('base'));
    await pumpEventQueue();
    final landed = await svc.stopRecording();

    expect(landed.transcript?.fullText, 'heard live words');
    expect(landed.transcript?.segments, isEmpty);

    await svc.dispose();
  });

  test(
    'a never-transcribed base with a hand edit records the whole-file pass in history',
    () async {
      await seedBase(
        revisions: [Revision(text: 'typed', at: fixedClock)],
      );
      final svc = build(FakeBatchEngine(cannedText: 'heard'));

      await svc.startRecording(continuing: store.read('base'));
      final landed = await svc.stopRecording();

      expect(landed.transcript?.fullText, 'heard');
      expect(landed.revisions?.map((r) => r.text), ['typed', 'heard']);
      expect(landed.readsAsTranscript, isTrue);

      await svc.dispose();
    },
  );

  test('the bulk runner still sees a base whose continuation was cancelled', () async {
    await seedBase(transcript: heard('a', engineId: 'other'));
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    await svc.cancelRecording();
    expect(svc.retranscribeAll.runnable(store.read('base')!), isTrue);

    await svc.dispose();
  });

  test('a cancel racing an in-flight interruption landing spares the base', () async {
    await seedBase(transcript: heard('a'));
    final gate = Completer<void>();
    composer.gate = gate.future;
    final svc = build(FakeBatchEngine(cannedText: 'b'));

    await svc.startRecording(continuing: store.read('base'));
    recorder.interrupt();
    await pumpEventQueue();
    final cancelling = svc.cancelRecording();
    gate.complete();
    await cancelling;
    await pumpEventQueue();

    expect(store.read('base')?.audioPath, 'merged.m4a');

    await svc.dispose();
  });

  test('a refused or failed start ends the continuation with a discard', () async {
    await seedBase(transcript: heard('a'));
    await store.save(store.read('base')!.withoutAudio());
    final svc = build(FakeBatchEngine(cannedText: 'b'));
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await expectLater(
      () => svc.startRecording(continuing: store.read('base')),
      throwsA(isA<ContinuationRefused>()),
    );
    await store.save(store.read('base')!.withAudioPath('base.m4a'));
    recorder.throwOnStart = true;
    await expectLater(
      () => svc.startRecording(continuing: store.read('base')),
      throwsA(isA<CaptureFailed>()),
    );
    await pumpEventQueue();

    expect(outcomes, hasLength(2));
    expect(outcomes, everyElement(const ContinuationDiscarded(baseId: 'base')));
    final again = await svc.retranscribe(store.read('base')!);
    expect(again.transcript?.fullText, 'b');

    await svc.dispose();
  });

  test('a capture that produced nothing ends the continuation with a discard', () async {
    await seedBase(transcript: heard('a'));
    recorder = FakeAudioRecorder(recordingsDir: dir.path, path: 'tail.m4a', throwOnStop: true);
    final svc = build(FakeBatchEngine(cannedText: 'b'));
    final outcomes = <ContinuationOutcome>[];
    svc.continuations.listen(outcomes.add);

    await svc.startRecording(continuing: store.read('base'));
    await expectLater(svc.stopRecording(), throwsA(isA<CaptureFailed>()));
    await pumpEventQueue();

    expect(outcomes.single, const ContinuationDiscarded(baseId: 'base'));
    expect(store.read('base')?.audioPath, 'base.m4a');
    final again = await svc.retranscribe(store.read('base')!);
    expect(again.transcript?.fullText, 'b');

    await svc.dispose();
  });
}

/// A store that refuses to save one id, so a landing's update (or a fallback's
/// own save) fails while everything else persists.
class _RefusingIdStore extends EntryStore {
  _RefusingIdStore(super.storage, this.refusedId);

  final String refusedId;

  @override
  Future<void> save(Entry entry) async {
    if (entry.id == refusedId) throw Exception('save refused');
    return super.save(entry);
  }
}
