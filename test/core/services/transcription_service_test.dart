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

  late LocalService storage;
  late EntryStore store;
  var idCounter = 0;

  /// Builds a service, letting each test provide the engine as a function of the
  /// recorder so a streaming engine can be wired to the recorder's stop signal.
  TranscriptionService build(
    TranscriptionEngine Function(FakeAudioRecorder) engine, {
    FakeAudioRecorder? recorder,
    bool Function()? keepAudio,
    Future<void> Function(File file)? fileDeleter,
    Future<List<double>> Function(String path)? peaksReader,
  }) {
    final rec = recorder ?? FakeAudioRecorder();
    idCounter = 0;
    return TranscriptionService(
      recorder: rec,
      engine: engine(rec),
      store: store,
      clock: () => fixedClock,
      idGenerator: () => 'id-${idCounter++}',
      keepAudio: keepAudio,
      // Synchronous so a discard's only real I/O never outruns pumpEventQueue.
      fileDeleter: fileDeleter ?? (f) async => f.deleteSync(),
      peaksReader: peaksReader,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    store = EntryStore(storage);
  });

  test('streaming engine: live streams for UI, batch is the persisted transcript', () async {
    // Live text and batch text differ so the persisted transcript proves it is the
    // batch result, while the live events prove real-time streaming.
    final svc = build(
      (rec) => FakeStreamingEngine(
        cannedText: 'live partial words',
        batchText: 'settled batch transcript',
        stopSignal: rec.stopped,
      ),
    );
    final events = <String>[];
    final sub = svc.liveEvents.listen((e) => events.add(e.text));

    await svc.startRecording();
    expect(svc.isRecording, isTrue);
    await svc.liveEvents.first; // deterministic: a partial has flowed
    final entry = await svc.stopRecording();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(entry.transcript?.fullText, 'settled batch transcript');
    expect(entry.transcript?.engineId, 'fake.streaming');
    expect(svc.isRecording, isFalse);
    expect(events, isNotEmpty);
    expect(store.read('id-0'), entry);

    await svc.dispose();
  });

  test('a live session that ends without a final still persists the batch transcript', () async {
    // A real analyzer session can end on partials only, never emitting a final
    // event. The service must not wait for one: it always runs the batch pass on
    // stop, so the saved transcript is the batch text regardless.
    final svc = build(
      (rec) => FakeStreamingEngine(
        cannedText: 'live partial words',
        batchText: 'settled batch transcript',
        liveNoFinal: true,
        stopSignal: rec.stopped,
      ),
    );

    await svc.startRecording();
    await svc.liveEvents.first; // deterministic: a partial has flowed
    final entry = await svc.stopRecording();

    expect(entry.transcript?.fullText, 'settled batch transcript');

    await svc.dispose();
  });

  test('a live isFinal event is dropped from liveEvents (batch is the truth)', () async {
    // The isFinal event only duplicates the last partial, and it is the one a
    // stopped session flushes late into the next take. The service must drop it
    // from the live stream. Deleting the guard would let 'FINAL TEXT' through.
    final engine = _ManualLiveEngine();
    final svc = build((_) => engine);
    final events = <String>[];
    final sub = svc.liveEvents.listen((e) => events.add(e.text));

    await svc.startRecording();
    engine.controllers[0].add(const TranscriptEvent(text: 'partial one', isFinal: false));
    engine.controllers[0].add(const TranscriptEvent(text: 'partial two', isFinal: false));
    engine.controllers[0].add(const TranscriptEvent(text: 'FINAL TEXT', isFinal: true));
    await Future<void>.delayed(Duration.zero);

    expect(events, ['partial one', 'partial two']);

    await svc.stopRecording();
    await sub.cancel();
    await svc.dispose();
  });

  test('a superseded take\'s late live event never paints the new take', () async {
    // The stop's live-sub cancel is unawaited and the recorder's stopDelay holds
    // the finalize open, so the old (generation-1) subscription is still alive
    // when the next startRecording bumps the generation. The generation gate must
    // keep the old take's late flush off the new take.
    final engine = _ManualLiveEngine();
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 30));
    final svc = build((_) => engine, recorder: rec);
    final events = <String>[];
    final sub = svc.liveEvents.listen((e) => events.add(e.text));

    await svc.startRecording(); // generation 1, subscribes controllers[0]
    engine.controllers[0].add(const TranscriptEvent(text: 'take one', isFinal: false));
    await Future<void>.delayed(Duration.zero);

    final stopping = svc.stopRecording(); // flips _recording false, holds on stopDelay
    await Future<void>.delayed(Duration.zero);
    await svc.startRecording(); // generation 2, subscribes controllers[1]

    // The superseded take flushes late while its sub is still detaching.
    engine.controllers[0].add(const TranscriptEvent(text: 'STALE from take one', isFinal: false));
    engine.controllers[0].add(const TranscriptEvent(text: 'FINAL from take one', isFinal: true));
    engine.controllers[1].add(const TranscriptEvent(text: 'take two', isFinal: false));
    await Future<void>.delayed(Duration.zero);
    await stopping;

    expect(events, contains('take one'));
    expect(events, contains('take two'));
    expect(events, isNot(contains('STALE from take one')));
    expect(events, isNot(contains('FINAL from take one')));

    await sub.cancel();
    await svc.dispose();
  });

  test('batch-only engine: kept file is transcribed on stop', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'batch result'));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript?.fullText, 'batch result');
    expect(entry.transcript?.engineId, 'fake.batch');
    expect(entry.transcript?.segments, isNotEmpty);
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('live-stream error is surfaced but the batch transcript still persists', () async {
    final svc = build(
      (rec) => FakeStreamingEngine(
        cannedText: 'live words',
        batchText: 'safe transcript',
        stopSignal: rec.stopped,
        failLive: true,
      ),
    );
    Object? forwardedError;
    final sub = svc.liveEvents.listen((_) {}, onError: (Object e) => forwardedError = e);

    await svc.startRecording();
    await svc.liveEvents.first; // deterministic: a partial has flowed
    final entry = await svc.stopRecording();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(entry.transcript?.fullText, 'safe transcript');
    expect(forwardedError, isNotNull);
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('transcription failure keeps the recording untranscribed, not lost', () async {
    final svc = build((_) => FakeBatchEngine(failBatch: true));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    // The recording is saved with its audio; the transcript is null and can be
    // produced later by re-transcription.
    expect(entry.transcript, isNull);
    expect(entry.isTranscribed, isFalse);
    expect(entry.audioPath, 'fake-recording.m4a');
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('retranscribe replaces the transcript with another engine', () async {
    final svc = build(
      (rec) => FakeStreamingEngine(
        cannedText: 'first',
        batchText: 'first pass',
        stopSignal: rec.stopped,
      ),
    );

    await svc.startRecording();
    final original = await svc.stopRecording();
    expect(original.transcript?.fullText, 'first pass');

    final updated = await svc.retranscribe(
      original,
      using: FakeBatchEngine(cannedText: 'sharper pass'),
    );

    expect(updated.id, original.id);
    expect(updated.audioPath, original.audioPath);
    expect(updated.transcript?.fullText, 'sharper pass');
    expect(store.read(original.id)?.transcript?.fullText, 'sharper pass');

    await svc.dispose();
  });

  test('an interruption auto-finalizes and saves the entry untranscribed', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(cannedText: 'ignored'), recorder: rec);
    final saved = <Entry>[];
    final sub = svc.autoFinalized.listen(saved.add);

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(saved, hasLength(1));
    expect(saved.first.transcript, isNull); // saved untranscribed on interruption
    // Stamped even here, so transcribing later uses the language it was spoken in.
    expect(saved.first.recordedLocaleId, 'en-US');
    expect(saved.first.audioPath, 'fake-recording.m4a');
    expect(store.read(saved.first.id), saved.first);
    expect(svc.isRecording, isFalse);

    await svc.dispose();
  });

  test('stopRecording after an interruption returns the same auto-finalized entry', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    Entry? emitted;
    final sub = svc.autoFinalized.listen((e) => emitted = e);

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero);

    final entry = await svc.stopRecording(); // must not throw
    await sub.cancel();

    expect(emitted, isNotNull);
    expect(entry.id, emitted!.id); // the very entry the interruption saved
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('a normal stopRecording emits nothing on autoFinalized', () async {
    final svc = build((_) => FakeBatchEngine());
    final saved = <Entry>[];
    final sub = svc.autoFinalized.listen(saved.add);

    await svc.startRecording();
    await svc.stopRecording();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(saved, isEmpty);

    await svc.dispose();
  });

  test('a second stopRecording after a normal stop throws', () async {
    final svc = build((_) => FakeBatchEngine());

    await svc.startRecording();
    await svc.stopRecording();
    await expectLater(svc.stopRecording, throwsStateError);

    await svc.dispose();
  });

  test('an interruption surfaces a save failure instead of orphaning the audio', () async {
    final rec = FakeAudioRecorder();
    final svc = TranscriptionService(
      recorder: rec,
      engine: FakeBatchEngine(),
      store: _ThrowingStore(storage),
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );
    Object? error;
    final sub = svc.autoFinalized.listen((_) {}, onError: (Object e) => error = e);

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    // Typed and carrying the entry, so a listener can retrySave it.
    expect(error, isA<EntrySaveFailed>());
    expect((error as EntrySaveFailed).entry.audioPath, 'fake-recording.m4a');

    await svc.dispose();
  });

  test('stopRecording during an in-flight interruption finalize returns its entry', () async {
    // The interruption claims the stop but is still mid-save when the user taps
    // stop; the stop must await that finalize, not throw StateError.
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 30));
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final saved = <Entry>[];
    final sub = svc.autoFinalized.listen(saved.add);

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero); // the handler claims the stop
    final entry = await svc.stopRecording();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(saved.map((e) => e.id), [entry.id]); // one save, one emit, same entry
    expect(svc.entries(), hasLength(1));

    await svc.dispose();
  });

  test('a second interruption while finalizing does not double-save', () async {
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 20));
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final saved = <Entry>[];
    final sub = svc.autoFinalized.listen(saved.add);

    await svc.startRecording();
    rec.interrupt();
    rec.interrupt();
    // Await the real signal, then settle, rather than sleeping a wall-clock guess.
    await svc.autoFinalized.first;
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(saved, hasLength(1));
    expect(svc.entries(), hasLength(1));

    await svc.dispose();
  });

  test('two concurrent stops resolve to the same entry', () async {
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 20));
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    await svc.startRecording();
    final first = svc.stopRecording();
    final second = svc.stopRecording(); // lands while the first is finalizing
    final entries = await Future.wait([first, second]);

    expect(entries[0].id, entries[1].id);
    expect(svc.entries(), hasLength(1));

    await svc.dispose();
  });

  test('stopRecording surfaces a racing interruption save failure as EntrySaveFailed', () async {
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 20));
    final svc = TranscriptionService(
      recorder: rec,
      engine: FakeBatchEngine(),
      store: _ThrowingStore(storage),
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );
    final sub = svc.autoFinalized.listen((_) {}, onError: (_) {});

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero); // the interruption claims the stop

    // The stop must carry the typed failure (with the entry), never 'not recording'.
    await expectLater(svc.stopRecording(), throwsA(isA<EntrySaveFailed>()));

    await sub.cancel();
    await svc.dispose();
  });

  test('a new recording during an in-flight finalize is unaffected by it', () async {
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 20));
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero); // finalize 1 is now in flight
    await svc.startRecording(); // session 2 begins while 1 is still saving
    await svc.autoFinalized.first; // finalize 1 lands
    expect(svc.isRecording, isTrue); // ...without killing session 2

    final entry2 = await svc.stopRecording();
    final ids = svc.entries().map((e) => e.id).toSet();
    expect(ids, hasLength(2)); // both sessions saved, as distinct entries
    expect(ids, contains(entry2.id));

    // Session 1's stale entry must not resurrect the double-stop replay.
    await expectLater(svc.stopRecording, throwsStateError);

    await svc.dispose();
  });

  test('dispose during an in-flight interruption finalize completes cleanly', () async {
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 20));
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero); // finalize in flight
    await svc.dispose(); // must not throw, even with the controller closing

    while (svc.entries().isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 5)); // until it lands
    }
    expect(svc.entries(), hasLength(1));
  });

  test('a failed save on stop throws EntrySaveFailed carrying the entry', () async {
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(),
      store: _ThrowingStore(storage),
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );

    await svc.startRecording();
    await expectLater(
      svc.stopRecording(),
      throwsA(
        isA<EntrySaveFailed>().having(
          (e) => e.entry.audioPath,
          'entry.audioPath',
          'fake-recording.m4a',
        ),
      ),
    );

    await svc.dispose();
  });

  test('dispose during a recording finalizes and saves it', () async {
    final svc = build((_) => FakeBatchEngine());

    await svc.startRecording();
    await svc.dispose();

    expect(svc.entries(), hasLength(1));
    expect(svc.entries().single.transcript, isNull);
  });

  test('a locale change mid-recording lands on the next session, not this one', () async {
    late FakeStreamingEngine engine;
    final svc = build((rec) {
      return engine = FakeStreamingEngine(batchText: 'x', stopSignal: rec.stopped);
    });

    await svc.startRecording();
    await Future<void>.delayed(Duration.zero); // let the lazy live generator start
    expect(engine.lastLiveLocaleId, 'en-US'); // live got the session snapshot
    svc.localeId = 'de-DE'; // the setting changes while a session is live
    final first = await svc.stopRecording();
    expect(first.transcript?.localeId, 'en-US'); // batch agrees with live

    await svc.startRecording();
    await Future<void>.delayed(Duration.zero);
    expect(engine.lastLiveLocaleId, 'de-DE');
    final second = await svc.stopRecording();
    expect(second.transcript?.localeId, 'de-DE'); // next session uses the change

    await svc.dispose();
  });

  test('a new session starting mid-finalize cannot re-language the old batch', () async {
    // Session N stops (finalize parked on the slow recorder stop); the locale
    // changes and session N+1 starts before N's batch runs. N's transcript must
    // still carry N's locale.
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 20));
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    await svc.startRecording();
    final stopping = svc.stopRecording(); // finalize in flight
    svc.localeId = 'de-DE';
    await svc.startRecording(); // session N+1 overwrites the snapshot field
    final first = await stopping;

    expect(first.transcript?.localeId, 'en-US'); // N kept its own locale

    final second = await svc.stopRecording();
    expect(second.transcript?.localeId, 'de-DE');

    await svc.dispose();
  });

  test('supportedLocales delegates to the engine', () async {
    final svc = build(
      (_) => FakeBatchEngine(supportedLocaleTags: const ['en-US', 'de-DE', 'az-AZ']),
    );

    expect(await svc.supportedLocales(), ['en-US', 'de-DE', 'az-AZ']);

    await svc.dispose();
  });

  test('retranscribe defaults to the transcript original locale', () async {
    final svc = build((_) => FakeBatchEngine());
    final entry = Entry(
      id: 'l1',
      createdAt: fixedClock,
      audioPath: '/tmp/x.m4a',
      duration: Duration.zero,
      transcript: Transcript(
        fullText: 'alt',
        segments: const [],
        localeId: 'de-DE',
        engineId: 'x',
        createdAt: fixedClock,
      ),
    );
    await store.save(entry);

    final updated = await svc.retranscribe(entry, using: FakeBatchEngine(cannedText: 'neu'));

    // The app-level locale is en-US; the entry keeps its original language.
    expect(updated.transcript?.localeId, 'de-DE');

    await svc.dispose();
  });

  test('a new recording gets its wave shape persisted off the critical path', () async {
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(),
      store: store,
      peaksReader: (_) async => [0.0, 0.5, 1.0, 2.0], // >1 clamps, not wraps
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );

    await svc.startRecording();
    final entry = await svc.stopRecording();
    // The save itself does not wait for the shape.
    expect(entry.peaks, isNull);
    await Future<void>.delayed(Duration.zero);

    expect(store.read('id-0')?.peaks, [0, 128, 255, 255]);

    await svc.dispose();
  });

  test('saveEntryPeaks quantizes once and never clobbers or resurrects', () async {
    final svc = build((_) => FakeBatchEngine());
    final entry = Entry(
      id: 'p1',
      createdAt: fixedClock,
      audioPath: '/tmp/p.m4a',
      duration: Duration.zero,
    );
    await store.save(entry);

    await svc.saveEntryPeaks(entry, [0.5]);
    expect(store.read('p1')?.peaks, [128]);

    // Already shaped: a second write is a no-op, not a clobber.
    await svc.saveEntryPeaks(entry, [1.0]);
    expect(store.read('p1')?.peaks, [128]);

    // Deleted meanwhile: never resurrected. Empty input: never stored.
    await store.delete('p1');
    await svc.saveEntryPeaks(entry, [0.5]);
    expect(store.read('p1'), isNull);
    await svc.saveEntryPeaks(entry.withTitle('x'), const []);
    expect(store.read('p1'), isNull);

    await svc.dispose();
  });

  test('a mid-take language switch batches each span in its own language', () async {
    var now = DateTime.utc(2026, 3, 4, 12);
    final engine = FakeStreamingEngine(supportedLocaleTags: ['en-US', 'fr-FR'])
      ..transcriptBuilder = (locale, start, end) => locale.split('-').first;
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: engine,
      store: store,
      clock: () => now,
      idGenerator: () => 'id-0',
    );
    svc.localeId = 'en-US';

    await svc.startRecording();
    now = now.add(const Duration(seconds: 5));
    await svc.setSessionLocale('fr-FR');
    now = now.add(const Duration(seconds: 5));
    final entry = await svc.stopRecording();

    expect(entry.transcript?.fullText, 'en [fr] fr');
    expect(entry.transcript?.localeId, 'en-US');
    expect(entry.recordedLocaleId, 'en-US');
    expect(entry.languageSpans, const [
      LanguageSpan(startMs: 0, localeId: 'en-US'),
      LanguageSpan(startMs: 5000, localeId: 'fr-FR'),
    ]);
    // Each span batched with its own language over its own slice.
    expect(engine.batchCalls, [
      (localeId: 'en-US', start: Duration.zero, end: const Duration(seconds: 5)),
      (localeId: 'fr-FR', start: const Duration(seconds: 5), end: null),
    ]);
    // The switch marker rides as its own zero-length segment (the transcript
    // view renders segments, not fullText), and the later span's segments
    // offset from slice time to file time (the fake's canned segment spans
    // 0..1s of its slice).
    expect(entry.transcript?.segments[1].text, '[fr]');
    expect(entry.transcript?.segments[1].start, const Duration(seconds: 5));
    expect(entry.transcript?.segments[1].end, const Duration(seconds: 5));
    expect(entry.transcript?.segments[2].start, const Duration(seconds: 5));
    // Spans survive the storage round-trip.
    expect(store.read('id-0'), entry);

    await svc.dispose();
  });

  test('a switch within the start grace window yields a single-language take', () async {
    var now = DateTime.utc(2026, 3, 4, 12);
    final engine = FakeStreamingEngine(supportedLocaleTags: ['en-US', 'fr-FR'])
      ..transcriptBuilder = (locale, start, end) => locale.split('-').first;
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: engine,
      store: store,
      clock: () => now,
      idGenerator: () => 'id-0',
    );
    svc.localeId = 'en-US';

    await svc.startRecording();
    // The switch lands a hair after start (scheduling latency, nothing spoken):
    // it replaces the opening span rather than leaving a throwaway en-US sliver
    // that would mis-stamp the take and plant a spurious marker.
    now = now.add(const Duration(milliseconds: 50));
    await svc.setSessionLocale('fr-FR');
    now = now.add(const Duration(seconds: 5));
    final entry = await svc.stopRecording();

    expect(entry.languageSpans, isNull, reason: 'coalesced to one span, not a mix');
    expect(entry.recordedLocaleId, 'fr-FR');
    expect(entry.transcript?.localeId, 'fr-FR');
    expect(entry.transcript?.fullText, 'fr', reason: 'no [en] marker, no leading en slice');

    await svc.dispose();
  });

  test('the grace window is scoped to the opening span, not mid-take', () async {
    // Two switches close together deep in a take must NOT collapse: the grace
    // window only forgives the start round-trip, so a genuine short span (a word
    // said in a third language) survives rather than being swallowed.
    var now = DateTime.utc(2026, 3, 4, 12);
    final engine = FakeStreamingEngine(supportedLocaleTags: ['en-US', 'fr-FR', 'de-DE'])
      ..transcriptBuilder = (locale, start, end) => locale.split('-').first;
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: engine,
      store: store,
      clock: () => now,
      idGenerator: () => 'id-0',
    );
    svc.localeId = 'en-US';

    await svc.startRecording();
    now = now.add(const Duration(seconds: 5));
    await svc.setSessionLocale('fr-FR');
    now = now.add(const Duration(milliseconds: 180)); // within the grace window
    await svc.setSessionLocale('de-DE');
    final entry = await svc.stopRecording();

    expect(entry.languageSpans, const [
      LanguageSpan(startMs: 0, localeId: 'en-US'),
      LanguageSpan(startMs: 5000, localeId: 'fr-FR'),
      LanguageSpan(startMs: 5180, localeId: 'de-DE'),
    ], reason: 'the 180ms French span is kept, not eaten by the grace window');

    await svc.dispose();
  });

  test('an engine that cannot slice flattens the take to the first language', () async {
    var now = DateTime.utc(2026, 3, 4, 12);
    final engine = FakeBatchEngine()
      ..failRanged = true
      ..transcriptBuilder = (locale, start, end) => 'whole-$locale';
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: engine,
      store: store,
      clock: () => now,
      idGenerator: () => 'id-0',
    );
    svc.localeId = 'en-US';

    await svc.startRecording();
    now = now.add(const Duration(seconds: 3));
    await svc.setSessionLocale('fr-FR');
    final entry = await svc.stopRecording();

    expect(entry.transcript?.fullText, 'whole-en-US');
    expect(entry.transcript?.localeId, 'en-US', reason: 'flattened to the FIRST language');
    expect(entry.languageSpans, hasLength(2), reason: 'the mix is kept for a capable engine');

    await svc.dispose();
  });

  test('retranscribe rebuilds the mix from spans; an explicit override flattens', () async {
    final engine = FakeBatchEngine()
      ..transcriptBuilder = (locale, start, end) => locale.split('-').first;
    final svc = build((_) => engine);
    final entry = Entry(
      id: 'mix',
      createdAt: fixedClock,
      audioPath: '/tmp/x.m4a',
      duration: const Duration(seconds: 10),
      recordedLocaleId: 'en-US',
      languageSpans: const [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 4000, localeId: 'fr-FR'),
      ],
    );
    await store.save(entry);

    final rebuilt = await svc.retranscribe(entry);
    expect(rebuilt.transcript?.fullText, 'en [fr] fr');
    expect(rebuilt.languageSpans, entry.languageSpans);

    final flattened = await svc.retranscribe(rebuilt, localeId: 'ru-RU');
    expect(flattened.transcript?.fullText, 'ru');
    expect(engine.batchCalls.last.start, isNull, reason: 'override runs the whole file');

    await svc.dispose();
  });

  test('pauses do not inflate span starts: audio time, not wall time', () async {
    var now = DateTime.utc(2026, 3, 4, 12);
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeStreamingEngine(supportedLocaleTags: ['en-US', 'fr-FR']),
      store: store,
      clock: () => now,
      idGenerator: () => 'id-0',
    );
    svc.localeId = 'en-US';

    await svc.startRecording();
    now = now.add(const Duration(seconds: 2));
    await svc.pauseRecording();
    now = now.add(const Duration(minutes: 5)); // a long pause holds NO audio
    await svc.resumeRecording();
    now = now.add(const Duration(seconds: 1));
    await svc.setSessionLocale('fr-FR');
    final entry = await svc.stopRecording();

    expect(entry.languageSpans?.last.startMs, 3000);

    await svc.dispose();
  });

  test('a same-instant toggle collapses; a single-span take stays plain', () async {
    final svc = build((_) => FakeStreamingEngine(supportedLocaleTags: ['en-US', 'fr-FR']));
    svc.localeId = 'en-US';

    await svc.startRecording();
    // Both switches land on the same audio instant (the fixed clock): the
    // French span never held audio and the take collapses back to English.
    await svc.setSessionLocale('fr-FR');
    await svc.setSessionLocale('en-US');
    final entry = await svc.stopRecording();

    expect(entry.languageSpans, isNull);
    expect(entry.transcript?.localeId, 'en-US');

    await svc.dispose();
  });

  test('setSessionLocale re-languages the take: batch AND restarted live', () async {
    final engine = FakeStreamingEngine(supportedLocaleTags: ['en-US', 'ru-RU']);
    final svc = build((_) => engine);
    svc.localeId = 'en-US';

    await svc.startRecording();
    // The live generator body runs on its first microtask, not at listen.
    await Future<void>.delayed(Duration.zero);
    expect(engine.lastLiveLocaleId, 'en-US');

    await svc.setSessionLocale('ru-RU');
    await Future<void>.delayed(Duration.zero);
    expect(engine.lastLiveLocaleId, 'ru-RU', reason: 'live restarted in the new language');

    final entry = await svc.stopRecording();
    expect(entry.transcript?.localeId, 'ru-RU');
    expect(entry.recordedLocaleId, 'ru-RU');
    // Session-only: the app default was never touched.
    expect(svc.localeId, 'en-US');

    // Idle: a no-op, not a default change.
    await svc.setSessionLocale('de-DE');
    expect(svc.localeId, 'en-US');

    await svc.dispose();
  });

  test('every save path stamps the recording-time locale', () async {
    final svc = build((_) => FakeBatchEngine());
    svc.localeId = 'fr-FR';

    // A normal stop.
    await svc.startRecording();
    final stopped = await svc.stopRecording();
    expect(stopped.recordedLocaleId, 'fr-FR');
    expect(stopped.transcript?.localeId, 'fr-FR');

    // A dispose mid-capture saves untranscribed, still stamped.
    final rec2 = FakeAudioRecorder();
    final svc2 = build((_) => FakeBatchEngine(), recorder: rec2);
    svc2.localeId = 'fr-FR';
    await svc2.startRecording();
    await svc2.dispose();
    final abandoned = store.all().firstWhere((e) => e.transcript == null);
    expect(abandoned.recordedLocaleId, 'fr-FR');

    await svc.dispose();
  });

  test('retranscribe of an untranscribed entry uses its recording-time locale', () async {
    // Fail the first batch so the entry lands untranscribed (but stamped).
    final failing = build((_) => FakeBatchEngine(failBatch: true));
    failing.localeId = 'fr-FR';
    await failing.startRecording();
    final entry = await failing.stopRecording();
    expect(entry.transcript, isNull);
    expect(entry.recordedLocaleId, 'fr-FR');

    // The default changed since; the take keeps the language it was spoken in.
    failing.localeId = 'en-US';
    final updated = await failing.retranscribe(entry, using: FakeBatchEngine());
    expect(updated.transcript?.localeId, 'fr-FR');

    // An explicit choice still wins over everything.
    final corrected = await failing.retranscribe(
      entry,
      using: FakeBatchEngine(),
      localeId: 'de-DE',
    );
    expect(corrected.transcript?.localeId, 'de-DE');

    await failing.dispose();
  });

  test('retrySave recovers an entry whose first save failed', () async {
    final failOnce = _ThrowingStore(storage, failures: 1);
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(),
      store: failOnce,
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );

    await svc.startRecording();
    EntrySaveFailed? failure;
    try {
      await svc.stopRecording();
    } on EntrySaveFailed catch (e) {
      failure = e;
    }
    expect(failure, isNotNull);

    // The whole point of the typed error: the carried entry makes recovery possible.
    await svc.retrySave(failure!.entry);
    expect(svc.entries().single.id, failure.entry.id);

    await svc.dispose();
  });

  test('two concurrent starts: the second throws, nothing leaks', () async {
    final svc = build((_) => FakeBatchEngine());

    final first = svc.startRecording();
    await expectLater(svc.startRecording(), throwsStateError);
    await first;
    expect(svc.isRecording, isTrue);

    await svc.stopRecording();
    await svc.dispose();
  });

  test('a failed start preserves the interruption-saved entry for a later stop', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    // An interruption saves E1; the user re-taps record while the mic is still
    // held by the interrupting call, and that start fails.
    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero);
    rec.throwOnStart = true;
    await expectLater(svc.startRecording(), throwsA(isA<CaptureFailed>()));

    // The stop after the failed start must still return E1, not throw.
    final entry = await svc.stopRecording();
    expect(svc.entries().single.id, entry.id);

    await svc.dispose();
  });

  test('an interruption during an in-flight start is latched, not dropped', () async {
    final rec = FakeAudioRecorder(startDelay: const Duration(milliseconds: 20));
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final saved = <Entry>[];
    final sub = svc.autoFinalized.listen(saved.add);

    final starting = svc.startRecording();
    await Future<void>.delayed(Duration.zero); // listener attached, start in flight
    rec.interrupt(); // native killed the capture before start() even resolved
    await starting;
    await svc.autoFinalized.first.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(saved, hasLength(1)); // the latched interruption still auto-finalized
    expect(svc.isRecording, isFalse);

    await svc.dispose();
  });

  test('retranscribe of a deleted entry throws instead of resurrecting it', () async {
    final svc = build((_) => FakeBatchEngine());
    final dir = await Directory.systemTemp.createTemp('otr-ghost');
    final file = File('${dir.path}/ghost.m4a');
    await file.writeAsString('audio');
    final entry = Entry(
      id: 'g1',
      createdAt: fixedClock,
      audioPath: file.path,
      duration: const Duration(seconds: 1),
    );
    await store.save(entry);

    // The batch pass is held open while the user deletes the entry mid-flight.
    // A gate (not a wall-clock delay) keeps the ordering deterministic: the
    // delete fully lands before the engine is released and retranscribe reads
    // the store back.
    final gate = Completer<void>();
    final retranscribing = svc.retranscribe(entry, using: FakeBatchEngine(gate: gate.future));
    await svc.deleteEntry(entry);
    gate.complete();

    await expectLater(retranscribing, throwsStateError);
    expect(store.read('g1'), isNull); // stayed deleted, no ghost

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('reconcileOrphans recovers readable orphans and deletes unreadable ones', () async {
    final dir = await Directory.systemTemp.createTemp('otr-reconcile');
    final good = File('${dir.path}/orphan-good.m4a')..writeAsStringSync('audio');
    final bad = File('${dir.path}/orphan-bad.m4a')..writeAsStringSync('junk');
    final referenced = File('${dir.path}/referenced.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(
        recordingsDir: dir.path,
        probe: (name) => name == 'orphan-good.m4a' ? const Duration(seconds: 3) : null,
      ),
    );
    await store.save(
      Entry(
        id: 'kept',
        createdAt: fixedClock,
        audioPath: 'referenced.m4a',
        duration: const Duration(seconds: 1),
      ),
    );

    final recovered = await svc.reconcileOrphans();

    expect(recovered, 1);
    expect(good.existsSync(), isTrue); // recovered as an entry, file kept
    expect(bad.existsSync(), isFalse); // unreadable: deleted
    expect(referenced.existsSync(), isTrue); // referenced: untouched
    final paths = svc.entries().map((e) => e.audioPath).toSet();
    expect(paths, {'referenced.m4a', 'orphan-good.m4a'});
    expect(
      svc.entries().firstWhere((e) => e.audioPath == 'orphan-good.m4a').duration,
      const Duration(seconds: 3),
    );

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('captureStatus forwards the recorder lifecycle', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final statuses = <CaptureStatus>[];
    final sub = svc.captureStatus.listen(statuses.add);

    await svc.startRecording();
    await svc.stopRecording();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(statuses, [CaptureStatus.recording, CaptureStatus.stopped]);

    await svc.dispose();
  });

  test('rejects an engine that is not on-device only', () {
    expect(
      () =>
          TranscriptionService(recorder: FakeAudioRecorder(), engine: _CloudEngine(), store: store),
      throwsArgumentError,
    );
  });

  test('startRecording twice throws', () async {
    final svc = build((rec) => FakeStreamingEngine(stopSignal: rec.stopped));

    await svc.startRecording();
    await expectLater(svc.startRecording, throwsStateError);

    await svc.stopRecording();
    await svc.dispose();
  });

  test('stopRecording without starting throws', () async {
    final svc = build((_) => FakeBatchEngine());

    await expectLater(svc.stopRecording, throwsStateError);

    await svc.dispose();
  });

  test('a non-taxonomy engine error still saves the recording untranscribed', () async {
    // A generic throw (not a TranscriptionException) must never orphan the audio.
    final svc = build((_) => FakeBatchEngine(throwGeneric: true));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript, isNull);
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('batch timeout keeps the recording untranscribed', () async {
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(duration: Duration.zero),
      engine: FakeBatchEngine(delay: const Duration(milliseconds: 200)),
      store: store,
      batchTimeout: const Duration(milliseconds: 10),
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript, isNull);

    await svc.dispose();
  });

  test('a batch that outlives its timeout is cancelled on the engine', () async {
    // The Dart future giving up must not leave the native task running: the
    // service tells a CancellableBatchEngine to abandon it too.
    final engine = FakeBatchEngine(delay: const Duration(milliseconds: 200));
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(duration: Duration.zero),
      engine: engine,
      store: store,
      batchTimeout: const Duration(milliseconds: 10),
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript, isNull);
    expect(engine.cancelBatchesCalls, 1);

    await svc.dispose();
  });

  test('startRecording throws PermissionDenied when the mic is denied', () async {
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(permission: PermissionStatus.denied),
    );

    await expectLater(svc.startRecording, throwsA(isA<PermissionDenied>()));
    expect(svc.isRecording, isFalse);

    await svc.dispose();
  });

  test('deleteEntry removes the audio file and the record', () async {
    final svc = build((_) => FakeBatchEngine());
    final dir = await Directory.systemTemp.createTemp('otr-test');
    final file = File('${dir.path}/audio.m4a');
    await file.writeAsString('audio');
    final entry = Entry(
      id: 'e1',
      createdAt: fixedClock,
      audioPath: file.path,
      duration: const Duration(seconds: 3),
    );
    await store.save(entry);

    await svc.deleteEntry(entry);

    expect(file.existsSync(), isFalse);
    expect(store.read('e1'), isNull);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('model lifecycle delegates to a managed engine', () async {
    final svc = build((_) => FakeManagedEngine(installSteps: const [0.3, 0.7]));

    expect(await svc.isModelInstalled(), isFalse);
    expect((await svc.checkAvailability()).isAvailable, isTrue);

    final progress = await svc.installModel().toList();
    expect(progress.map((p) => p.fraction), [0.3, 0.7, 1.0]);
    expect(progress.last.done, isTrue);

    await svc.dispose();
  });

  test('isModelInstalled reflects a managed engine reporting installed', () async {
    final svc = build((_) => FakeManagedEngine(installed: true));

    expect(await svc.isModelInstalled(), isTrue);

    await svc.dispose();
  });

  test('model lifecycle is a no-op for an engine with no downloadable model', () async {
    final svc = build((_) => FakeBatchEngine());

    // A non-managed engine is always ready and installs instantly.
    expect(await svc.isModelInstalled(), isTrue);
    final progress = await svc.installModel().toList();
    expect(progress.single.done, isTrue);

    await svc.dispose();
  });

  test('resolveAudioPath resolves a bare filename, passes an absolute path through', () async {
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: '/recordings'),
    );

    final relative = Entry(
      id: 'a1',
      createdAt: fixedClock,
      audioPath: 'clip.m4a',
      duration: Duration.zero,
    );
    final absolute = Entry(
      id: 'a2',
      createdAt: fixedClock,
      audioPath: '/tmp/other.m4a',
      duration: Duration.zero,
    );

    expect(await svc.resolveAudioPath(relative), '/recordings/clip.m4a');
    expect(await svc.resolveAudioPath(absolute), '/tmp/other.m4a');

    await svc.dispose();

    // A trailing slash from the native side must not produce a double separator.
    final slashed = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: '/recordings/'),
    );
    expect(await slashed.resolveAudioPath(relative), '/recordings/clip.m4a');
    await slashed.dispose();
  });

  test('deleteEntry resolves a bare filename against the recordings directory', () async {
    // Real entries store a filename, not an absolute path, so it survives a
    // backup/restore that moves the app container. Deletion must resolve it.
    final dir = await Directory.systemTemp.createTemp('otr-resolve');
    final file = File('${dir.path}/clip.m4a');
    await file.writeAsString('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
    );
    final entry = Entry(
      id: 'r1',
      createdAt: fixedClock,
      audioPath: 'clip.m4a',
      duration: const Duration(seconds: 1),
    );
    await store.save(entry);

    await svc.deleteEntry(entry);

    expect(file.existsSync(), isFalse);
    expect(store.read('r1'), isNull);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('deleteEntry removes the record even when the audio file is missing', () async {
    final svc = build((_) => FakeBatchEngine());
    final entry = Entry(
      id: 'e2',
      createdAt: fixedClock,
      audioPath: '/no/such/file.m4a',
      duration: Duration.zero,
    );
    await store.save(entry);

    await svc.deleteEntry(entry);

    expect(store.read('e2'), isNull);

    await svc.dispose();
  });

  test('deleteEntry keeps the record when the delete fails and the file remains', () async {
    // An iOS data-protection lock can make the delete throw with the file still
    // on disk. Dropping the record then would orphan the file and
    // reconcileOrphans would resurrect the "deleted" recording next launch, so
    // the record must survive for a retry to remove both.
    final dir = await Directory.systemTemp.createTemp('otr-delfail');
    final file = File('${dir.path}/clip.m4a');
    await file.writeAsString('audio');
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      engine: FakeBatchEngine(),
      store: store,
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
      fileDeleter: (_) async => throw const FileSystemException('locked'),
    );
    final entry = Entry(
      id: 'd1',
      createdAt: fixedClock,
      audioPath: 'clip.m4a',
      duration: const Duration(seconds: 1),
    );
    await store.save(entry);

    await expectLater(svc.deleteEntry(entry), throwsA(isA<EntryDeleteFailed>()));

    // Record kept and the file still referenced, so the sweep sees it as a live
    // entry, not an orphan to resurrect.
    expect(store.read('d1'), isNotNull);
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('deleteEntry removes the record when the delete throws but the file is gone', () async {
    // The delete seam threw, but the file is actually gone (a delete that failed
    // only on its result, not its effect): there is nothing left to orphan, so
    // the record is still removed.
    final dir = await Directory.systemTemp.createTemp('otr-delgone');
    final file = File('${dir.path}/clip.m4a');
    await file.writeAsString('audio');
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      engine: FakeBatchEngine(),
      store: store,
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
      fileDeleter: (f) async {
        await f.delete();
        throw const FileSystemException('reported failure after delete');
      },
    );
    final entry = Entry(
      id: 'd2',
      createdAt: fixedClock,
      audioPath: 'clip.m4a',
      duration: const Duration(seconds: 1),
    );
    await store.save(entry);

    await svc.deleteEntry(entry);

    expect(store.read('d2'), isNull);
    expect(file.existsSync(), isFalse);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('retranscribe failure throws and leaves the old transcript intact', () async {
    final svc = build((rec) => FakeStreamingEngine(batchText: 'original', stopSignal: rec.stopped));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    expect(entry.transcript?.fullText, 'original');

    await expectLater(
      svc.retranscribe(entry, using: FakeBatchEngine(failBatch: true)),
      throwsA(isA<TranscriptionFailed>()),
    );
    expect(store.read(entry.id)?.transcript?.fullText, 'original');

    await svc.dispose();
  });

  test('retranscribe rejects a non-on-device engine', () async {
    final svc = build((rec) => FakeStreamingEngine(stopSignal: rec.stopped));
    await svc.startRecording();
    final entry = await svc.stopRecording();

    await expectLater(svc.retranscribe(entry, using: _CloudEngine()), throwsArgumentError);

    await svc.dispose();
  });

  test('persists createdAt as UTC even from a local clock', () async {
    final localClock = DateTime(2026, 3, 4, 12);
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(clock: () => localClock),
      store: store,
      clock: () => localClock,
      idGenerator: () => 'id-0',
    );

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.createdAt.isUtc, isTrue);
    expect(entry.createdAt, localClock.toUtc());
    expect(entry.transcript?.createdAt.isUtc, isTrue);

    await svc.dispose();
  });

  test('pause and resume flip isPaused and only in legal states', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    expect(() => svc.pauseRecording(), throwsStateError);
    expect(() => svc.resumeRecording(), throwsStateError);

    await svc.startRecording();
    expect(svc.isPaused, isFalse);
    expect(() => svc.resumeRecording(), throwsStateError);

    await svc.pauseRecording();
    expect(svc.isPaused, isTrue);
    expect(rec.paused, isTrue);
    expect(() => svc.pauseRecording(), throwsStateError);

    await svc.resumeRecording();
    expect(svc.isPaused, isFalse);
    expect(rec.paused, isFalse);

    await svc.stopRecording();
    await svc.dispose();
  });

  test('a recorder pause failure leaves the session running and unpaused', () async {
    final rec = FakeAudioRecorder(throwOnPause: true);
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    await svc.startRecording();
    await expectLater(svc.pauseRecording(), throwsA(isA<CaptureFailed>()));
    expect(svc.isPaused, isFalse);
    expect(svc.isRecording, isTrue);

    await svc.stopRecording();
    await svc.dispose();
  });

  test('stop while paused persists a normal entry and clears the pause', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'paused then stopped'));

    await svc.startRecording();
    await svc.pauseRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript?.fullText, 'paused then stopped');
    expect(svc.isPaused, isFalse);
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('an interruption while paused auto-finalizes and clears the pause', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final saved = <Entry>[];
    final sub = svc.autoFinalized.listen(saved.add);

    await svc.startRecording();
    await svc.pauseRecording();
    rec.interrupt();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(saved, hasLength(1));
    expect(svc.isPaused, isFalse);
    expect(svc.isRecording, isFalse);

    await sub.cancel();
    await svc.dispose();
  });

  test('cancel persists nothing and a later stop throws', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    await svc.startRecording();
    await svc.cancelRecording();

    expect(rec.cancelled, isTrue);
    expect(svc.isRecording, isFalse);
    expect(svc.entries(), isEmpty);
    await expectLater(svc.stopRecording(), throwsStateError);

    await svc.dispose();
  });

  test('cancel while idle is quiet; cancel during a start throws', () async {
    final rec = FakeAudioRecorder(startDelay: const Duration(milliseconds: 20));
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    await svc.cancelRecording(); // idle: no-op

    final starting = svc.startRecording();
    await expectLater(svc.cancelRecording(), throwsStateError);
    await starting;

    await svc.stopRecording();
    await svc.dispose();
  });

  test('cancel while paused discards without saving', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);

    await svc.startRecording();
    await svc.pauseRecording();
    await svc.cancelRecording();

    expect(svc.isPaused, isFalse);
    expect(svc.entries(), isEmpty);

    await svc.dispose();
  });

  test('inputLevel passes the recorder levels through', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final levels = <double>[];
    final sub = svc.inputLevel.listen(levels.add);

    rec.levelController.add(0.2);
    rec.levelController.add(0.8);
    await Future<void>.delayed(Duration.zero);

    expect(levels, [0.2, 0.8]);
    await sub.cancel();
    await svc.dispose();
  });

  test('renameEntry sets, trims, and clears the title on the stored entry', () async {
    final svc = build((_) => FakeBatchEngine());
    await svc.startRecording();
    final entry = await svc.stopRecording();

    final renamed = await svc.renameEntry(entry, '  Morning pages  ');
    expect(renamed.title, 'Morning pages');
    expect(store.read(entry.id)?.title, 'Morning pages');

    final cleared = await svc.renameEntry(renamed, '   ');
    expect(cleared.title, isNull);
    expect(store.read(entry.id)?.title, isNull);

    await svc.dispose();
  });

  test('renameEntry applies to the stored entry, not a stale caller copy', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final stale = await svc.stopRecording();

    // The stored entry moves on (a re-transcription) after the caller's copy.
    final fresher = await svc.retranscribe(stale, using: FakeBatchEngine(cannedText: 'second'));
    final renamed = await svc.renameEntry(stale, 'kept');

    expect(renamed.title, 'kept');
    expect(renamed.transcript?.fullText, fresher.transcript?.fullText);

    await svc.dispose();
  });

  test('renameEntry throws for a deleted entry', () async {
    final svc = build((_) => FakeBatchEngine());
    await svc.startRecording();
    final entry = await svc.stopRecording();

    await svc.deleteEntry(entry);

    await expectLater(svc.renameEntry(entry, 'ghost'), throwsStateError);
    await svc.dispose();
  });

  test('a rename landing mid-retranscribe survives the retranscribe save', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final entry = await svc.stopRecording();

    // The slow batch opens the window; the rename lands inside it. The
    // retranscribe must save onto the stored (renamed) entry, not its stale
    // untitled argument.
    final slow = svc.retranscribe(
      entry,
      using: FakeBatchEngine(cannedText: 'second', delay: const Duration(milliseconds: 30)),
    );
    await svc.renameEntry(entry, 'kept title');
    final updated = await slow;

    expect(updated.title, 'kept title');
    expect(updated.transcript?.fullText, 'second');
    expect(store.read(entry.id)?.title, 'kept title');

    await svc.dispose();
  });

  test('editTranscript lays the engine base then pushes the trimmed edit', () async {
    final svc = build((_) => FakeBatchEngine());
    await svc.startRecording();
    final entry = await svc.stopRecording();

    final edited = await svc.editTranscript(entry, '  fixed words  ');
    expect(edited.revisions, hasLength(2));
    expect(edited.revisions!.first.text, 'batch transcript');
    expect(edited.revisions!.first.isHand, isFalse);
    expect(edited.head?.text, 'fixed words');
    expect(edited.head?.isHand, isTrue);
    expect(edited.head?.at, fixedClock);
    expect(edited.transcript?.fullText, 'batch transcript');
    expect(store.read(entry.id)?.readableText, 'fixed words');

    await svc.dispose();
  });

  test('a blank commit writes nothing, since revert is its own surface', () async {
    final svc = build((_) => FakeBatchEngine());
    await svc.startRecording();
    final entry = await svc.stopRecording();

    await svc.editTranscript(entry, 'fixed');
    final blanked = await svc.editTranscript(entry, '   ');

    expect(blanked.head?.text, 'fixed');
    expect(blanked.revisions, hasLength(2));

    await svc.dispose();
  });

  test('typing the head words back writes nothing, edge whitespace and all', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: ' batch transcript '));
    await svc.startRecording();
    final entry = await svc.stopRecording();

    final same = await svc.editTranscript(entry, 'batch transcript');
    expect(same.revisions, isNull);

    await svc.editTranscript(entry, 'fixed');
    final repeat = await svc.editTranscript(entry, ' fixed ');
    expect(repeat.revisions, hasLength(2));

    await svc.dispose();
  });

  test('a typed paragraph break is a change and pushes', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first words'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    await svc.editTranscript(entry, 'fixed words');

    final reflowed = await svc.editTranscript(entry, 'fixed\n\nwords');

    expect(reflowed.revisions, hasLength(3));
    expect(reflowed.head?.text, 'fixed\n\nwords');

    await svc.dispose();
  });

  test('an unchanged edit keeps the head stamp', () async {
    var now = DateTime.utc(2026, 3, 4, 12);
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(),
      store: store,
      clock: () => now,
      fileDeleter: (f) async => f.deleteSync(),
    );
    await svc.startRecording();
    final entry = await svc.stopRecording();

    final first = await svc.editTranscript(entry, 'fixed');
    now = now.add(const Duration(hours: 1));
    final repeat = await svc.editTranscript(entry, ' fixed ');

    expect(repeat.head?.at, first.head?.at);
    expect(store.read(entry.id)?.head?.at, first.head?.at);

    await svc.dispose();
  });

  test('editTranscript applies to the stored entry, not a stale caller copy', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final stale = await svc.stopRecording();

    final fresher = await svc.retranscribe(stale, using: FakeBatchEngine(cannedText: 'second'));
    final edited = await svc.editTranscript(stale, 'kept');

    expect(edited.head?.text, 'kept');
    expect(edited.transcript?.fullText, fresher.transcript?.fullText);

    await svc.dispose();
  });

  test('editTranscript throws for a deleted entry', () async {
    final svc = build((_) => FakeBatchEngine());
    await svc.startRecording();
    final entry = await svc.stopRecording();

    await svc.deleteEntry(entry);

    await expectLater(svc.editTranscript(entry, 'ghost'), throwsStateError);
    await svc.dispose();
  });

  test('an edit landing mid-retranscribe stays in the landed history', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final entry = await svc.stopRecording();

    final slow = svc.retranscribe(
      entry,
      using: FakeBatchEngine(cannedText: 'second', delay: const Duration(milliseconds: 30)),
    );
    await svc.editTranscript(entry, 'mid-flight edit');
    final updated = await slow;

    expect(updated.head?.text, 'second');
    expect(updated.head?.isHand, isFalse);
    expect(updated.transcript?.fullText, 'second');
    expect(updated.revisions!.map((r) => r.text), ['first', 'mid-flight edit', 'second']);

    await svc.dispose();
  });

  test('retranscribe pushes the replaced words into history', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    await svc.editTranscript(entry, 'fixed');

    final landed = await svc.retranscribe(entry, using: FakeBatchEngine(cannedText: 'second'));

    expect(landed.head?.text, 'second');
    expect(landed.head?.isHand, isFalse);
    expect(landed.revisions!.map((r) => r.text), ['first', 'fixed', 'second']);
    expect(landed.readsAsTranscript, isTrue);

    await svc.dispose();
  });

  test('a landing that moved only whitespace pushes nothing', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first words'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    await svc.editTranscript(entry, 'fixed');

    final landed = await svc.retranscribe(entry, using: FakeBatchEngine(cannedText: ' fixed '));

    expect(landed.revisions!.map((r) => r.text), ['first words', 'fixed']);
    expect(landed.transcript?.fullText, ' fixed ');

    await svc.dispose();
  });

  test('an empty landing on a pristine entry keeps the old words as the head', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first words'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    expect(entry.revisions, isNull);

    final landed = await svc.retranscribe(entry, using: FakeBatchEngine(cannedText: '   '));

    expect(landed.transcript?.fullText, '   ');
    expect(landed.readableText, 'first words');
    expect(landed.revisions!.map((r) => r.text), ['first words']);

    await svc.dispose();
  });

  test('a first transcription of an untouched entry pushes no history', () async {
    final engine = FakeBatchEngine(failBatch: true);
    final svc = build((_) => engine);
    await svc.startRecording();
    final entry = await svc.stopRecording();
    expect(entry.transcript, isNull);

    engine.failBatch = false;
    final landed = await svc.retranscribe(entry);

    expect(landed.transcript?.fullText, 'batch transcript');
    expect(landed.revisions, isNull);

    await svc.dispose();
  });

  test('restoreRevision pushes a stamped copy, origin kept', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    final edited = await svc.editTranscript(entry, 'fixed');

    final restored = await svc.restoreRevision(edited, edited.revisions!.first);

    expect(restored.revisions!.map((r) => r.text), ['first', 'fixed', 'first']);
    expect(restored.head?.isHand, isFalse);
    expect(restored.head?.at, fixedClock);
    expect(restored.readsAsTranscript, isTrue);
    expect(store.read(entry.id)?.readableText, 'first');

    await svc.dispose();
  });

  test('restoring what the entry already reads as writes nothing', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    final edited = await svc.editTranscript(entry, 'fixed');

    final same = await svc.restoreRevision(edited, edited.revisions!.last);
    expect(same.revisions, hasLength(2));

    await svc.dispose();
  });

  test('restoring the engine base under a hand reflow pushes', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'hello world'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    final reflowed = await svc.editTranscript(entry, 'hello\n\nworld');

    final restored = await svc.restoreRevision(reflowed, reflowed.revisions!.first);

    expect(restored.revisions, hasLength(3));
    expect(restored.readableText, 'hello world');
    expect(restored.readsAsTranscript, isTrue);

    await svc.dispose();
  });

  test('restoring a hand revision that differs only in whitespace pushes', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first words'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    await svc.editTranscript(entry, 'fixed\n\nwords');
    final reflowed = await svc.editTranscript(entry, 'fixed words');

    final restored = await svc.restoreRevision(reflowed, reflowed.revisions![1]);

    expect(restored.revisions, hasLength(4));
    expect(restored.readableText, 'fixed\n\nwords');

    await svc.dispose();
  });

  test('deleteRevision removes one revision; deleting the head changes the reading', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    await svc.editTranscript(entry, 'fixed');
    final edited = await svc.editTranscript(entry, 'fixed again');

    final trimmed = await svc.deleteRevision(edited, edited.revisions!.last);

    expect(trimmed.revisions!.map((r) => r.text), ['first', 'fixed']);
    expect(trimmed.readableText, 'fixed');
    expect(store.read(entry.id)?.readableText, 'fixed');

    await svc.dispose();
  });

  test('the last remaining revision cannot be deleted', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    final edited = await svc.editTranscript(entry, 'fixed');

    final one = await svc.deleteRevision(edited, edited.revisions!.last);
    final still = await svc.deleteRevision(one, one.revisions!.single);

    expect(still.revisions!.map((r) => r.text), ['first']);
    expect(still.readableText, 'first');

    await svc.dispose();
  });

  test('deleting a revision the stack no longer holds writes nothing', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'first'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    final edited = await svc.editTranscript(entry, 'fixed');
    final gone = edited.revisions!.last;
    await svc.deleteRevision(edited, gone);

    final repeat = await svc.deleteRevision(edited, gone);

    expect(repeat.revisions!.map((r) => r.text), ['first']);

    await svc.dispose();
  });

  test('restoreRevision throws for a deleted entry', () async {
    final svc = build((_) => FakeBatchEngine());
    await svc.startRecording();
    final entry = await svc.stopRecording();
    final edited = await svc.editTranscript(entry, 'fixed');

    await svc.deleteEntry(entry);

    await expectLater(svc.restoreRevision(edited, edited.revisions!.first), throwsStateError);
    await svc.dispose();
  });

  test('a stop landing during an in-flight pause leaves no stale pause flag', () async {
    final svc = build((_) => FakeBatchEngine());
    await svc.startRecording();

    // Do not await the pause: the stop claims the session while the pause's
    // continuation is still pending, and that continuation must not stamp
    // paused chrome onto an idle service.
    final pausing = svc.pauseRecording();
    await svc.stopRecording();
    await pausing.catchError((_) {});

    expect(svc.isRecording, isFalse);
    expect(svc.isPaused, isFalse);

    await svc.dispose();
  });

  test('a concurrent second pause loses as CaptureFailed, state stays coherent', () async {
    final svc = build((_) => FakeBatchEngine());
    await svc.startRecording();

    final results = await Future.wait([
      svc.pauseRecording().then((_) => 'ok').catchError((Object e) => e.runtimeType.toString()),
      svc.pauseRecording().then((_) => 'ok').catchError((Object e) => e.runtimeType.toString()),
    ]);

    expect(results.where((r) => r == 'ok'), hasLength(1));
    expect(svc.isPaused, isTrue);

    await svc.stopRecording();
    await svc.dispose();
  });

  test('cancel racing a stop: exactly one wins in either order', () async {
    // Stop first: the entry is saved and the cancel is quiet.
    var svc = build((_) => FakeBatchEngine());
    await svc.startRecording();
    final stopped = svc.stopRecording();
    await svc.cancelRecording();
    final entry = await stopped;
    expect(store.read(entry.id), isNotNull);
    await svc.dispose();

    // Cancel first: nothing is saved and the stop throws.
    svc = build((_) => FakeBatchEngine());
    await svc.startRecording();
    final cancelled = svc.cancelRecording();
    await expectLater(svc.stopRecording(), throwsStateError);
    await cancelled;
    await svc.dispose();
  });

  test('cancel during an in-flight interruption finalize discards the auto-save', () async {
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 20));
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final autoSaved = <Entry>[];
    final sub = svc.autoFinalized.listen(autoSaved.add);

    await svc.startRecording();
    rec.interrupt();
    // Let the interruption claim the session, then discard while it saves.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await svc.cancelRecording();

    // The auto-save happened (the stream is honest about it), but the discard
    // won: no entry remains.
    expect(autoSaved, hasLength(1));
    expect(svc.entries(), isEmpty);

    await sub.cancel();
    await svc.dispose();
  });

  test(
    'cancelRecording after a completed interruption finalize deletes the auto-saved entry',
    () async {
      final rec = FakeAudioRecorder();
      final svc = build((_) => FakeBatchEngine(), recorder: rec);
      final sub = svc.autoFinalized.listen((_) {});

      await svc.startRecording();
      rec.interrupt();
      await Future<void>.delayed(Duration.zero); // the auto-finalize completes

      expect(svc.entries(), hasLength(1)); // the interruption's save landed

      await svc.cancelRecording();

      expect(svc.entries(), isEmpty);

      await sub.cancel();
      await svc.dispose();
    },
  );

  test('stopRecording after a cancel that discarded the interruption save throws', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final sub = svc.autoFinalized.listen((_) {});

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero);
    await svc.cancelRecording();

    // The take was discarded; there is nothing left to promise a stop.
    await expectLater(svc.stopRecording(), throwsStateError);

    await sub.cancel();
    await svc.dispose();
  });

  test('cancelRecording after the interruption entry was delivered by a stop is a no-op', () async {
    final dir = await Directory.systemTemp.createTemp('otr-delivered');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final rec = FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a');
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final sub = svc.autoFinalized.listen((_) {});

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero); // the auto-finalize completes

    final entry = await svc.stopRecording(); // delivered to this caller

    await svc.cancelRecording();

    expect(store.read(entry.id), entry);
    expect(file.existsSync(), isTrue);

    await sub.cancel();
    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('cancelRecording after a failed restart does not delete the delivered entry', () async {
    final dir = await Directory.systemTemp.createTemp('otr-failed-restart');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final rec = FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a');
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final sub = svc.autoFinalized.listen((_) {});

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero); // the auto-finalize completes

    final entry = await svc.stopRecording(); // delivered to this caller

    // The user re-taps record while the phone call still holds the mic.
    rec.throwOnStart = true;
    await expectLater(svc.startRecording(), throwsA(isA<CaptureFailed>()));

    await svc.cancelRecording();

    expect(store.read(entry.id), entry);
    expect(file.existsSync(), isTrue);

    await sub.cancel();
    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('a stop after delivery throws instead of handing the entry out twice', () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final sub = svc.autoFinalized.listen((_) {});

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero); // the auto-finalize completes

    await svc.stopRecording(); // first delivery consumes the handle

    await expectLater(svc.stopRecording(), throwsStateError);

    await sub.cancel();
    await svc.dispose();
  });

  test("cancel around a second take never touches the first take's stalled finalize", () async {
    final rec = FakeAudioRecorder();
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    final saved = <Entry>[];
    final sub = svc.autoFinalized.listen(saved.add);
    final gate = Completer<void>();

    await svc.startRecording(); // take 1
    rec.nextStopGate = gate.future;
    rec.interrupt(); // take 1's finalize claims the stop and stalls on the gate
    await Future<void>.delayed(Duration.zero); // the handler claims the stop

    await svc.startRecording(); // take 2, unaffected by take 1's stalled stop
    final entry2 = await svc.stopRecording(); // take 2's own stop sees no gate

    await svc.cancelRecording(); // an idle cancel issued around take 2

    gate.complete(); // release take 1's stop
    await svc.autoFinalized.first.timeout(const Duration(seconds: 1));
    await pumpEventQueue();
    await sub.cancel();

    expect(saved, hasLength(1)); // only take 1 auto-finalized
    final entry1 = saved.single;
    expect(store.read(entry1.id), entry1);
    expect(store.read(entry2.id), entry2);
    expect(svc.entries(), hasLength(2));

    await svc.dispose();
  });

  test('cancelRecording while idle with no interruption save is a no-op', () async {
    final svc = build((_) => FakeBatchEngine());
    final entry = Entry(
      id: 'e1',
      createdAt: fixedClock,
      audioPath: null,
      duration: const Duration(seconds: 1),
    );
    await store.save(entry);

    await svc.cancelRecording();

    expect(store.read('e1'), isNotNull);

    await svc.dispose();
  });

  Transcript canned(String text) => Transcript(
    fullText: text,
    segments: [
      TranscriptSegment(text: text, start: Duration.zero, end: const Duration(seconds: 1)),
    ],
    localeId: 'en-US',
    engineId: 'fake',
    createdAt: fixedClock,
  );

  test('keep-off: a transcribed stop discards the audio only after the wave lands', () async {
    final dir = await Directory.systemTemp.createTemp('otr-keepoff');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final gate = Completer<List<double>>();
    final svc = build(
      (_) => FakeBatchEngine(cannedText: 'kept words'),
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
      keepAudio: () => false,
      peaksReader: (_) => gate.future,
    );

    await svc.startRecording();
    final entry = await svc.stopRecording();
    // The caller's copy still carries the path; the store is the truth and the
    // discard lands off the critical path.
    expect(entry.audioPath, 'take.m4a');
    await pumpEventQueue();
    // The discard chains BEHIND the backfill: while the shape is still being
    // read, the file must exist (a discard-first order would pass the end
    // state below either way, since _discardAudio backfills peaks itself).
    expect(file.existsSync(), isTrue);

    gate.complete([0.5]);
    await pumpEventQueue();

    final stored = store.read('id-0');
    expect(stored?.audioPath, isNull);
    expect(stored?.transcript?.fullText, 'kept words');
    // The wave outlives the file it was read from.
    expect(stored?.peaks, [128]);
    expect(file.existsSync(), isFalse);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('a keep-on stop stays kept even if the preference flips mid-backfill', () async {
    // The service latches the answer at save time: a flip-to-off while the
    // wave is still being read must not delete a take stopped under keep-on.
    final dir = await Directory.systemTemp.createTemp('otr-latch');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    var keep = true;
    final gate = Completer<List<double>>();
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
      keepAudio: () => keep,
      peaksReader: (_) => gate.future,
    );

    await svc.startRecording();
    await svc.stopRecording();
    keep = false;
    gate.complete([0.5]);
    await pumpEventQueue();

    expect(store.read('id-0')?.audioPath, 'take.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-off: a failing peaks reader never blocks the discard', () async {
    // The wave is cosmetic; a decode failure must not leave the space held.
    final dir = await Directory.systemTemp.createTemp('otr-peaksfail');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(cannedText: 'words'),
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
      keepAudio: () => false,
      peaksReader: (_) async => throw StateError('decode failed'),
    );

    await svc.startRecording();
    await svc.stopRecording();
    await pumpEventQueue();

    final stored = store.read('id-0');
    expect(stored?.audioPath, isNull);
    expect(stored?.transcript?.fullText, 'words');
    expect(stored?.peaks, isNull);
    expect(file.existsSync(), isFalse);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('an overlapping purge is a no-op that returns 0', () async {
    final dir = await Directory.systemTemp.createTemp('otr-purgerace');
    final file = File('${dir.path}/one.m4a')..writeAsStringSync('audio');
    final gate = Completer<void>();
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      fileDeleter: (f) async {
        await gate.future;
        await f.delete();
      },
    );
    await store.save(
      Entry(
        id: 'q1',
        createdAt: fixedClock,
        audioPath: 'one.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('q'),
      ),
    );

    final first = svc.purgeTranscribedAudio();
    await pumpEventQueue();
    // The first purge is parked inside its delete; a second must not race the
    // same snapshot.
    expect(await svc.purgeTranscribedAudio(), 0);
    gate.complete();
    expect(await first, 1);
    expect(file.existsSync(), isFalse);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('healDanglingAudio repairs only transcribed records whose file is gone', () async {
    final dir = await Directory.systemTemp.createTemp('otr-heal');
    final present = File('${dir.path}/present.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
    );
    await store.save(
      Entry(
        id: 'h1',
        createdAt: fixedClock,
        audioPath: 'gone.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('h'),
      ),
    );
    await store.save(
      Entry(
        id: 'h2',
        createdAt: fixedClock,
        audioPath: 'present.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('h'),
      ),
    );
    // Untranscribed with a missing file: its words are gone, left visible.
    await store.save(
      Entry(id: 'h3', createdAt: fixedClock, audioPath: 'alsogone.m4a', duration: Duration.zero),
    );

    expect(await svc.healDanglingAudio(), 1);

    expect(store.read('h1')?.audioPath, isNull);
    // The heal never deletes a file: kept history is untouchable here.
    expect(store.read('h2')?.audioPath, 'present.m4a');
    expect(present.existsSync(), isTrue);
    expect(store.read('h3')?.audioPath, 'alsogone.m4a');

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('the heal is a no-op while a finalize holds the unreferenced guard', () async {
    final dir = await Directory.systemTemp.createTemp('otr-healgate');
    final rec = FakeAudioRecorder(recordingsDir: dir.path);
    final svc = build((_) => FakeBatchEngine(), recorder: rec);
    await store.save(
      Entry(
        id: 'hg1',
        createdAt: fixedClock,
        audioPath: 'gone.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('h'),
      ),
    );
    final sub = svc.autoFinalized.listen((_) {});
    final gate = Completer<void>();

    await svc.startRecording();
    rec.nextStopGate = gate.future;
    rec.interrupt(); // the finalize claims the stop and stalls on the gate
    await Future<void>.delayed(Duration.zero); // the handler claims the stop

    expect(await svc.healDanglingAudio(), 0);
    expect(store.read('hg1')?.audioPath, 'gone.m4a');

    gate.complete();
    await svc.autoFinalized.first.timeout(const Duration(seconds: 1));
    await pumpEventQueue();

    expect(await svc.healDanglingAudio(), 1);
    expect(store.read('hg1')?.audioPath, isNull);

    await sub.cancel();
    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('a heal never deletes a file that is back on disk', () async {
    final dir = await Directory.systemTemp.createTemp('otr-healback');
    final file = File('${dir.path}/back.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
    );
    await store.save(
      Entry(
        id: 'hb1',
        createdAt: fixedClock,
        audioPath: 'back.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('h'),
      ),
    );

    expect(await svc.healDanglingAudio(), 0);

    expect(store.read('hb1')?.audioPath, 'back.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('a discard killed between file delete and save is healed at launch', () async {
    // The kill-window shape: the file went, the record still points at it.
    final dir = await Directory.systemTemp.createTemp('otr-healkill');
    File('${dir.path}/take.m4a').writeAsStringSync('audio');
    final failing = _NullPathSaveFailsOnce(storage);
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
      engine: FakeBatchEngine(),
      store: failing,
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
      keepAudio: () => false,
      fileDeleter: (f) async => f.deleteSync(),
    );

    await svc.startRecording();
    await svc.stopRecording();
    await pumpEventQueue();

    // Dangling: the discard deleted the file but its save was "killed".
    expect(failing.read('id-0')?.audioPath, 'take.m4a');
    expect(File('${dir.path}/take.m4a').existsSync(), isFalse);
    // Usage never counts a dangling record as held bytes.
    final usage = await svc.audioUsage();
    expect(usage.totalCount, 0);

    expect(await svc.healDanglingAudio(), 1);
    expect(failing.read('id-0')?.audioPath, isNull);
    expect(failing.read('id-0')?.transcript, isNotNull);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-off: a failed transcription keeps the audio', () async {
    // The audio is the only copy of the words; the discard defers to a later
    // successful (re-)transcription.
    final dir = await Directory.systemTemp.createTemp('otr-keepfail');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(failBatch: true),
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
      keepAudio: () => false,
    );

    await svc.startRecording();
    await svc.stopRecording();
    await pumpEventQueue();

    final stored = store.read('id-0');
    expect(stored?.transcript, isNull);
    expect(stored?.audioPath, 'take.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-off: an interruption auto-save keeps its audio', () async {
    final dir = await Directory.systemTemp.createTemp('otr-keepint');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final rec = FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a');
    final svc = build((_) => FakeBatchEngine(), recorder: rec, keepAudio: () => false);

    await svc.startRecording();
    final saved = svc.autoFinalized.first;
    rec.interrupt();
    final entry = await saved;
    await pumpEventQueue();

    expect(entry.transcript, isNull);
    expect(store.read(entry.id)?.audioPath, 'take.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-on (the default): a transcribed stop keeps the audio', () async {
    final dir = await Directory.systemTemp.createTemp('otr-keepon');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
    );

    await svc.startRecording();
    await svc.stopRecording();
    await pumpEventQueue();

    expect(store.read('id-0')?.audioPath, 'take.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-off: retranscribe completes the deferred discard on first success', () async {
    final dir = await Directory.systemTemp.createTemp('otr-keepretr');
    final file = File('${dir.path}/clip.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(cannedText: 'finally'),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      keepAudio: () => false,
    );
    await store.save(
      Entry(
        id: 'r1',
        createdAt: fixedClock,
        audioPath: 'clip.m4a',
        duration: const Duration(seconds: 1),
      ),
    );

    final updated = await svc.retranscribe(store.read('r1')!);

    expect(updated.audioPath, isNull);
    expect(store.read('r1')?.audioPath, isNull);
    expect(store.read('r1')?.transcript?.fullText, 'finally');
    expect(file.existsSync(), isFalse);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-off: re-transcribing an already-transcribed entry never deletes', () async {
    // Reclaiming old audio is an explicit cleanup action only; a re-run with a
    // better engine must not silently destroy the source it just read.
    final dir = await Directory.systemTemp.createTemp('otr-keepretr2');
    final file = File('${dir.path}/clip.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(cannedText: 'sharper'),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      keepAudio: () => false,
    );
    await store.save(
      Entry(
        id: 'r2',
        createdAt: fixedClock,
        audioPath: 'clip.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('old'),
      ),
    );

    final updated = await svc.retranscribe(store.read('r2')!);

    expect(updated.transcript?.fullText, 'sharper');
    expect(updated.audioPath, 'clip.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-off: a batch that heard nothing keeps the audio', () async {
    final dir = await Directory.systemTemp.createTemp('otr-emptystop');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine()..transcriptBuilder = (locale, start, end) => '',
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
      keepAudio: () => false,
    );

    await svc.startRecording();
    await svc.stopRecording();
    await pumpEventQueue();

    expect(store.read('id-0')?.transcript?.fullText, '');
    expect(store.read('id-0')?.audioPath, 'take.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-off: an empty retranscribe keeps the audio', () async {
    final dir = await Directory.systemTemp.createTemp('otr-emptyretr');
    final file = File('${dir.path}/clip.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine()..transcriptBuilder = (locale, start, end) => '',
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      keepAudio: () => false,
    );
    await store.save(
      Entry(
        id: 'e1',
        createdAt: fixedClock,
        audioPath: 'clip.m4a',
        duration: const Duration(seconds: 1),
      ),
    );

    final updated = await svc.retranscribe(store.read('e1')!);

    expect(updated.transcript?.fullText, '');
    expect(updated.audioPath, 'clip.m4a');
    expect(store.read('e1')?.audioPath, 'clip.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-off: a material landing after an empty one discards the audio', () async {
    final dir = await Directory.systemTemp.createTemp('otr-emptythenreal');
    final file = File('${dir.path}/clip.m4a')..writeAsStringSync('audio');
    final engine = FakeBatchEngine()..transcriptBuilder = (locale, start, end) => '';
    final svc = build(
      (_) => engine,
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      keepAudio: () => false,
    );
    await store.save(
      Entry(
        id: 'e2',
        createdAt: fixedClock,
        audioPath: 'clip.m4a',
        duration: const Duration(seconds: 1),
      ),
    );
    await svc.retranscribe(store.read('e2')!);
    expect(store.read('e2')?.audioPath, 'clip.m4a');

    engine.transcriptBuilder = (locale, start, end) => 'landed';
    final updated = await svc.retranscribe(store.read('e2')!);

    expect(updated.transcript?.fullText, 'landed');
    expect(updated.audioPath, isNull);
    expect(store.read('e2')?.audioPath, isNull);
    expect(file.existsSync(), isFalse);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-on: an empty landing changes nothing about the audio', () async {
    final dir = await Directory.systemTemp.createTemp('otr-emptykeepon');
    final file = File('${dir.path}/clip.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine()..transcriptBuilder = (locale, start, end) => '',
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
    );
    await store.save(
      Entry(
        id: 'e3',
        createdAt: fixedClock,
        audioPath: 'clip.m4a',
        duration: const Duration(seconds: 1),
      ),
    );

    final updated = await svc.retranscribe(store.read('e3')!);

    expect(updated.transcript?.fullText, '');
    expect(updated.audioPath, 'clip.m4a');
    expect(store.read('e3')?.audioPath, 'clip.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('retranscribe of a transcript-only entry throws before any engine work', () async {
    final engine = FakeBatchEngine();
    final svc = build((_) => engine);
    final entry = Entry(
      id: 'r3',
      createdAt: fixedClock,
      audioPath: null,
      duration: Duration.zero,
      transcript: canned('only text'),
    );
    await store.save(entry);

    await expectLater(svc.retranscribe(entry), throwsStateError);
    expect(engine.batchCalls, isEmpty);

    await svc.dispose();
  });

  test('keep-off: a failed discard keeps the path and a later purge finishes it', () async {
    final dir = await Directory.systemTemp.createTemp('otr-discfail');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
      keepAudio: () => false,
      fileDeleter: (_) async => throw const FileSystemException('locked'),
    );

    await svc.startRecording();
    await svc.stopRecording();
    await pumpEventQueue();

    // While the file survives, the path stays, or the reconcile sweep would
    // resurrect the audio as a new entry.
    expect(store.read('id-0')?.audioPath, 'take.m4a');
    expect(store.read('id-0')?.transcript, isNotNull);
    expect(file.existsSync(), isTrue);

    // The retry story: the Cache screen's explicit purge, with the lock gone,
    // reclaims it (the launch heal never touches a file that still exists).
    final retry = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      keepAudio: () => false,
    );
    expect(await retry.purgeTranscribedAudio(), 1);
    expect(store.read('id-0')?.audioPath, isNull);
    expect(file.existsSync(), isFalse);

    await dir.delete(recursive: true);
    await svc.dispose();
    await retry.dispose();
  });

  test('deleteEntry of a transcript-only entry removes the record with no file work', () async {
    var deletes = 0;
    final svc = build(
      (_) => FakeBatchEngine(),
      fileDeleter: (_) async {
        deletes++;
      },
    );
    final entry = Entry(id: 'd3', createdAt: fixedClock, audioPath: null, duration: Duration.zero);
    await store.save(entry);

    await svc.deleteEntry(entry);

    expect(store.read('d3'), isNull);
    expect(deletes, 0);

    await svc.dispose();
  });

  test('reconcileOrphans ignores transcript-only entries and still recovers orphans', () async {
    final dir = await Directory.systemTemp.createTemp('otr-reconull');
    final orphan = File('${dir.path}/orphan.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(
        recordingsDir: dir.path,
        probe: (_) => const Duration(seconds: 2),
      ),
    );
    await store.save(
      Entry(id: 'b1', createdAt: fixedClock, audioPath: null, duration: Duration.zero),
    );

    expect(await svc.reconcileOrphans(), 1);
    expect(store.read('b1')?.audioPath, isNull);
    expect(orphan.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('reconcileOrphans answers null rather than zero when a capture blocks the sweep', () async {
    final dir = await Directory.systemTemp.createTemp('otr-recoblocked');
    final orphan = File('${dir.path}/orphan.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(
        recordingsDir: dir.path,
        probe: (_) => const Duration(seconds: 2),
      ),
    );
    await svc.startRecording();

    expect(await svc.reconcileOrphans(), isNull);
    expect(orphan.existsSync(), isTrue);
    expect(svc.entries(), isEmpty);

    await svc.stopRecording();
    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('reconcileOrphans keeps sweeping the directory after a probe throws', () async {
    final dir = await Directory.systemTemp.createTemp('otr-recoprobe');
    File('${dir.path}/orphan-a.m4a').writeAsStringSync('audio');
    File('${dir.path}/orphan-b.m4a').writeAsStringSync('audio');
    var probes = 0;
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(
        recordingsDir: dir.path,
        probe: (_) =>
            probes++ == 0 ? throw const CaptureFailed('probe failed') : const Duration(seconds: 3),
      ),
    );

    expect(await svc.reconcileOrphans(), 1);
    expect(probes, 2);
    expect(svc.entries(), hasLength(1));
    expect(File('${dir.path}/orphan-a.m4a').existsSync(), isTrue);
    expect(File('${dir.path}/orphan-b.m4a').existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('reconcileOrphans stops and answers null when a capture starts mid-walk', () async {
    final dir = await Directory.systemTemp.createTemp('otr-recomidwalk');
    File('${dir.path}/orphan-a.m4a').writeAsStringSync('audio');
    File('${dir.path}/orphan-b.m4a').writeAsStringSync('audio');
    late final TranscriptionService svc;
    Future<void>? started;
    svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(
        recordingsDir: dir.path,
        probe: (_) {
          started ??= svc.startRecording();
          return const Duration(seconds: 3);
        },
      ),
    );

    expect(await svc.reconcileOrphans(), isNull);
    await started;
    expect(svc.entries(), hasLength(1));
    expect(File('${dir.path}/orphan-a.m4a').existsSync(), isTrue);
    expect(File('${dir.path}/orphan-b.m4a').existsSync(), isTrue);

    await svc.stopRecording();
    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test(
    'reconcileOrphans answers null while a finalize is in flight, then sweeps once it lands',
    () async {
      final dir = await Directory.systemTemp.createTemp('otr-recofinalize');
      final orphan = File('${dir.path}/orphan.m4a')..writeAsStringSync('audio');
      final svc = build(
        (_) => FakeBatchEngine(),
        recorder: FakeAudioRecorder(
          path: 'take.m4a',
          recordingsDir: dir.path,
          probe: (_) => const Duration(seconds: 3),
          stopDelay: const Duration(milliseconds: 20),
        ),
      );
      await svc.startRecording();
      final finalizing = svc.stopRecording();

      expect(svc.isRecording, isFalse);
      expect(await svc.reconcileOrphans(), isNull);
      expect(svc.entries(), isEmpty);

      await finalizing;
      expect(svc.entries().map((e) => e.audioPath), ['take.m4a']);
      expect(orphan.existsSync(), isTrue);

      expect(await svc.reconcileOrphans(), 1);
      expect(svc.entries().map((e) => e.audioPath), containsAll(['take.m4a', 'orphan.m4a']));

      await dir.delete(recursive: true);
      await svc.dispose();
    },
  );

  test('reconcileOrphans answers null while an import adopts, then sweeps once it lands', () async {
    final dir = await Directory.systemTemp.createTemp('otr-adoptsweep');
    final staging = await Directory.systemTemp.createTemp('otr-adoptstage');
    File('${dir.path}/orphan.m4a').writeAsStringSync('audio');
    final stagedAudio = File('${staging.path}/import.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(
        recordingsDir: dir.path,
        probe: (_) => const Duration(seconds: 3),
      ),
    );

    final adopting = svc.adoptImportedEntries([
      StagedImportEntry(
        entry: Entry(
          id: 'imported',
          createdAt: fixedClock,
          audioPath: 'import.m4a',
          duration: const Duration(seconds: 1),
        ),
        stagedAudio: stagedAudio,
      ),
    ]);
    expect(await svc.reconcileOrphans(), isNull);
    await adopting;

    expect(await svc.reconcileOrphans(), 1);
    expect(svc.entries(), hasLength(2));
    expect(svc.entries().map((e) => e.audioPath), containsAll(['import.m4a', 'orphan.m4a']));

    await dir.delete(recursive: true);
    await staging.delete(recursive: true);
    await svc.dispose();
  });

  test('deleteEntry leaves a recording another entry still references on disk', () async {
    final dir = await Directory.systemTemp.createTemp('otr-shareddelete');
    final file = File('${dir.path}/shared.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
    );
    const duration = Duration(seconds: 1);
    final twin = Entry(
      id: 'twin',
      createdAt: fixedClock,
      audioPath: 'shared.m4a',
      duration: duration,
    );
    final original = Entry(
      id: 'original',
      createdAt: fixedClock,
      audioPath: 'shared.m4a',
      duration: duration,
    );
    await store.save(twin);
    await store.save(original);

    await svc.deleteEntry(original);

    expect(file.existsSync(), isTrue);
    expect(store.read('original'), isNull);
    expect(store.read('twin'), twin);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('purgeTranscribedAudio reclaims a solo recording but never one two entries share', () async {
    final dir = await Directory.systemTemp.createTemp('otr-sharedpurge');
    final shared = File('${dir.path}/shared.m4a')..writeAsStringSync('audio');
    final solo = File('${dir.path}/solo.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
    );
    const duration = Duration(seconds: 1);
    for (final (id, path) in [('a', 'shared.m4a'), ('b', 'shared.m4a'), ('c', 'solo.m4a')]) {
      await store.save(
        Entry(
          id: id,
          createdAt: fixedClock,
          audioPath: path,
          duration: duration,
          transcript: canned(id),
        ),
      );
    }

    expect(await svc.purgeTranscribedAudio(), 1);

    expect(shared.existsSync(), isTrue);
    expect(solo.existsSync(), isFalse);
    expect(store.read('a')?.audioPath, 'shared.m4a');
    expect(store.read('b')?.audioPath, 'shared.m4a');
    expect(store.read('c')?.audioPath, isNull);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('recoverInterruptedSave adds nothing once the sweep adopted the same recording', () async {
    final svc = build((_) => FakeBatchEngine());
    const duration = Duration(seconds: 2);
    final swept = Entry(
      id: 'swept',
      createdAt: fixedClock,
      audioPath: 'take.m4a',
      duration: duration,
    );
    await store.save(swept);

    await svc.recoverInterruptedSave(
      Entry(id: 'lost', createdAt: fixedClock, audioPath: 'take.m4a', duration: duration),
    );

    expect(svc.entries(), [swept]);

    await svc.dispose();
  });

  test('retrySave adds nothing once the sweep adopted the same recording', () async {
    final svc = build((_) => FakeBatchEngine());
    const duration = Duration(seconds: 2);
    final swept = Entry(
      id: 'swept',
      createdAt: fixedClock,
      audioPath: 'take.m4a',
      duration: duration,
    );
    await store.save(swept);

    await svc.retrySave(
      Entry(id: 'lost', createdAt: fixedClock, audioPath: 'take.m4a', duration: duration),
    );

    expect(svc.entries(), [swept]);

    await svc.dispose();
  });

  test('a cancelled take is not resurrected by the save recovery', () async {
    final dir = await Directory.systemTemp.createTemp('otr-cancelled-recovery');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final rec = FakeAudioRecorder(
      recordingsDir: dir.path,
      path: 'take.m4a',
      stopDelay: const Duration(milliseconds: 20),
    );
    final svc = TranscriptionService(
      recorder: rec,
      engine: FakeBatchEngine(),
      store: _ThrowingStore(storage),
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );
    Object? error;
    final sub = svc.autoFinalized.listen((_) {}, onError: (Object e) => error = e);

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero); // the interruption claims the stop

    // cancelRecording awaits the still-failing save itself and discards it.
    await svc.cancelRecording();
    await pumpEventQueue();

    expect(store.read('id-0'), isNull);
    expect(file.existsSync(), isFalse);
    expect(error, isA<EntrySaveFailed>());
    final failed = (error as EntrySaveFailed).entry;

    // The racing cubit's unawaited recovery arrives after the discard.
    await svc.recoverInterruptedSave(failed);

    expect(store.read('id-0'), isNull);
    expect(file.existsSync(), isFalse);

    await sub.cancel();
    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('a stop during the save recovery returns the recovered entry', () async {
    final dir = await Directory.systemTemp.createTemp('otr-stop-during-recovery');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final entry = Entry(
      id: 'id-0',
      createdAt: fixedClock,
      audioPath: 'take.m4a',
      duration: const Duration(seconds: 2),
    );
    final gate = Completer<void>();
    final gatedStore = _GatedSaveStore(storage, gatedId: 'id-0', gate: gate.future);
    final rec = FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a');
    final svc = TranscriptionService(
      recorder: rec,
      engine: FakeBatchEngine(),
      store: gatedStore,
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );

    final recovering = svc.recoverInterruptedSave(entry);
    await pumpEventQueue(); // the recovery's save is now gated, mid-flight

    final stopping = svc.stopRecording();
    await pumpEventQueue();
    gate.complete(); // release the gated save
    await recovering;

    final stopped = await stopping;

    expect(stopped.id, 'id-0');
    expect(store.read('id-0'), stopped);
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('a cancel during the save recovery discards the recovered entry', () async {
    final dir = await Directory.systemTemp.createTemp('otr-cancel-during-recovery');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final entry = Entry(
      id: 'id-0',
      createdAt: fixedClock,
      audioPath: 'take.m4a',
      duration: const Duration(seconds: 2),
    );
    final gate = Completer<void>();
    final gatedStore = _GatedSaveStore(storage, gatedId: 'id-0', gate: gate.future);
    final rec = FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a');
    final svc = TranscriptionService(
      recorder: rec,
      engine: FakeBatchEngine(),
      store: gatedStore,
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );

    final recovering = svc.recoverInterruptedSave(entry);
    await pumpEventQueue(); // the recovery's save is now gated, mid-flight

    final cancelling = svc.cancelRecording();
    await pumpEventQueue();
    gate.complete(); // release the gated save
    await recovering;
    await cancelling;

    expect(store.read('id-0'), isNull);
    expect(file.existsSync(), isFalse);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('retrySave still saves a take the user cancelled', () async {
    final dir = await Directory.systemTemp.createTemp('otr-retry-after-cancel');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final rec = FakeAudioRecorder(
      recordingsDir: dir.path,
      path: 'take.m4a',
      stopDelay: const Duration(milliseconds: 20),
    );
    final svc = TranscriptionService(
      recorder: rec,
      engine: FakeBatchEngine(),
      store: _ThrowingStore(storage, failures: 1),
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );
    Object? error;
    final sub = svc.autoFinalized.listen((_) {}, onError: (Object e) => error = e);

    await svc.startRecording();
    rec.interrupt();
    await Future<void>.delayed(Duration.zero); // the interruption claims the stop

    await svc.cancelRecording(); // discards, marking the id
    await pumpEventQueue();

    expect(store.read('id-0'), isNull);
    expect(file.existsSync(), isFalse); // the discard's deleteEntry already took it
    expect(error, isA<EntrySaveFailed>());
    final failed = (error as EntrySaveFailed).entry;

    // The explicit, user-driven retry is a deliberate resurrection: it must not
    // consult the discard marker.
    await svc.retrySave(failed);

    expect(store.read('id-0'), failed);

    await sub.cancel();
    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('audioUsage counts kept audio and its reclaimable share, skipping gone files', () async {
    final dir = await Directory.systemTemp.createTemp('otr-usage');
    File('${dir.path}/done.m4a').writeAsStringSync('audio'); // 5 bytes
    File('${dir.path}/raw.m4a').writeAsStringSync('raw'); // 3 bytes
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
    );
    await store.save(
      Entry(
        id: 'u1',
        createdAt: fixedClock,
        audioPath: 'done.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('done'),
      ),
    );
    await store.save(
      Entry(
        id: 'u2',
        createdAt: fixedClock,
        audioPath: 'raw.m4a',
        duration: const Duration(seconds: 1),
      ),
    );
    // Transcript-only and dangling-path entries hold no measurable audio.
    await store.save(
      Entry(
        id: 'u3',
        createdAt: fixedClock,
        audioPath: null,
        duration: Duration.zero,
        transcript: canned('bare'),
      ),
    );
    await store.save(
      Entry(
        id: 'u4',
        createdAt: fixedClock,
        audioPath: 'gone.m4a',
        duration: Duration.zero,
        transcript: canned('gone'),
      ),
    );

    final usage = await svc.audioUsage();

    expect(usage.totalBytes, 8);
    expect(usage.totalCount, 2);
    expect(usage.reclaimableBytes, 5);
    expect(usage.reclaimableCount, 1);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('purgeTranscribedAudio reclaims only transcribed audio and is idempotent', () async {
    final dir = await Directory.systemTemp.createTemp('otr-purge');
    final one = File('${dir.path}/one.m4a')..writeAsStringSync('audio');
    final two = File('${dir.path}/two.m4a')..writeAsStringSync('audio');
    final raw = File('${dir.path}/raw.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
    );
    final base = Entry(
      id: 'p1',
      createdAt: fixedClock,
      audioPath: 'one.m4a',
      duration: const Duration(seconds: 1),
      transcript: canned('one'),
    );
    await store.save(base);
    await store.save(
      Entry(
        id: 'p2',
        createdAt: fixedClock,
        audioPath: 'two.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('two'),
      ),
    );
    // Untranscribed audio is the only copy of its words: never purged.
    await store.save(
      Entry(id: 'p3', createdAt: fixedClock, audioPath: 'raw.m4a', duration: Duration.zero),
    );
    // Already transcript-only: nothing to do.
    await store.save(
      Entry(
        id: 'p4',
        createdAt: fixedClock,
        audioPath: null,
        duration: Duration.zero,
        transcript: canned('bare'),
      ),
    );

    expect(await svc.purgeTranscribedAudio(), 2);
    expect(one.existsSync(), isFalse);
    expect(two.existsSync(), isFalse);
    expect(raw.existsSync(), isTrue);
    expect(store.read('p1')?.audioPath, isNull);
    expect(store.read('p2')?.audioPath, isNull);
    expect(store.read('p3')?.audioPath, 'raw.m4a');
    expect(await svc.purgeTranscribedAudio(), 0);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('purge skips a failing delete and still reclaims the rest', () async {
    final dir = await Directory.systemTemp.createTemp('otr-purgefail');
    final locked = File('${dir.path}/locked.m4a')..writeAsStringSync('audio');
    final free = File('${dir.path}/free.m4a')..writeAsStringSync('audio');
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      fileDeleter: (f) async {
        if (f.path.endsWith('locked.m4a')) throw const FileSystemException('locked');
        await f.delete();
      },
    );
    await store.save(
      Entry(
        id: 'l1',
        createdAt: fixedClock,
        audioPath: 'locked.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('locked'),
      ),
    );
    await store.save(
      Entry(
        id: 'l2',
        createdAt: fixedClock,
        audioPath: 'free.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('free'),
      ),
    );

    expect(await svc.purgeTranscribedAudio(), 1);
    expect(locked.existsSync(), isTrue);
    expect(store.read('l1')?.audioPath, 'locked.m4a');
    expect(free.existsSync(), isFalse);
    expect(store.read('l2')?.audioPath, isNull);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('a delete landing mid-discard is not resurrected as a ghost', () async {
    // _discardAudio re-reads the entry right before its final save; a save of
    // its earlier snapshot would bring a deleted entry back transcript-only.
    final dir = await Directory.systemTemp.createTemp('otr-ghostdisc');
    File('${dir.path}/clip.m4a').writeAsStringSync('audio');
    final gate = Completer<List<double>>();
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      keepAudio: () => false,
      peaksReader: (_) => gate.future,
    );
    final entry = Entry(
      id: 'g1',
      createdAt: fixedClock,
      audioPath: 'clip.m4a',
      duration: const Duration(seconds: 1),
    );
    await store.save(entry);

    // First-success discard, held open inside its peaks read.
    final done = svc.retranscribe(entry);
    await pumpEventQueue();
    await svc.deleteEntry(store.read('g1')!);
    gate.complete([0.5]);
    await done;

    expect(store.read('g1'), isNull);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('keep-off: a failed save schedules no discard, and a recovered save keeps audio', () async {
    // The single most safety-critical point of the contract: the discard is
    // chained only behind a SUCCESSFUL save, so a save failure must leave the
    // audio untouched, and the retrySave recovery must not delete it either
    // (reclaiming it later is the Cache screen's explicit clear).
    final dir = await Directory.systemTemp.createTemp('otr-savefail');
    final file = File('${dir.path}/take.m4a')..writeAsStringSync('audio');
    final throwing = _ThrowingStore(storage, failures: 1);
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(recordingsDir: dir.path, path: 'take.m4a'),
      engine: FakeBatchEngine(),
      store: throwing,
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
      keepAudio: () => false,
    );

    await svc.startRecording();
    Entry? failed;
    try {
      await svc.stopRecording();
    } on EntrySaveFailed catch (e) {
      failed = e.entry;
    }
    await pumpEventQueue();
    expect(failed, isNotNull);
    expect(file.existsSync(), isTrue);

    await svc.retrySave(failed!);
    await pumpEventQueue();
    expect(throwing.read('id-0')?.audioPath, 'take.m4a');
    expect(file.existsSync(), isTrue);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('a rename landing mid-discard survives on the transcript-only record', () async {
    final dir = await Directory.systemTemp.createTemp('otr-renamedisc');
    final file = File('${dir.path}/clip.m4a')..writeAsStringSync('audio');
    final gate = Completer<List<double>>();
    final svc = build(
      (_) => FakeBatchEngine(cannedText: 'words'),
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      keepAudio: () => false,
      peaksReader: (_) => gate.future,
    );
    final entry = Entry(
      id: 'g2',
      createdAt: fixedClock,
      audioPath: 'clip.m4a',
      duration: const Duration(seconds: 1),
    );
    await store.save(entry);

    final done = svc.retranscribe(entry);
    await pumpEventQueue();
    await svc.renameEntry(entry, 'named');
    gate.complete([0.5]);
    await done;

    final stored = store.read('g2');
    expect(stored?.title, 'named');
    expect(stored?.audioPath, isNull);
    expect(stored?.transcript?.fullText, 'words');
    expect(stored?.peaks, [128]);
    expect(file.existsSync(), isFalse);

    await dir.delete(recursive: true);
    await svc.dispose();
  });
}

/// A store whose FIRST transcript-only save throws, modeling a kill landing
/// between a discard's file delete and its record update.
class _NullPathSaveFailsOnce extends EntryStore {
  _NullPathSaveFailsOnce(super.storage);

  bool _failed = false;

  @override
  Future<void> save(Entry entry) async {
    if (!_failed && entry.audioPath == null) {
      _failed = true;
      throw Exception('killed');
    }
    return super.save(entry);
  }
}

/// A store whose save fails [failures] times (-1: always), to prove save failures
/// surface as EntrySaveFailed and recover via retrySave.
class _ThrowingStore extends EntryStore {
  _ThrowingStore(super.storage, {this.failures = -1});

  int failures;

  @override
  Future<void> save(Entry entry) async {
    if (failures != 0) {
      if (failures > 0) failures--;
      throw Exception('save failed');
    }
    return super.save(entry);
  }
}

/// A store whose save for one specific entry id awaits [gate] before writing,
/// modeling a save recovery's write held open so a racing stop or cancel can be
/// issued while it is still in flight. Saves for any other id pass straight
/// through.
class _GatedSaveStore extends EntryStore {
  _GatedSaveStore(super.storage, {required this.gatedId, required this.gate});

  final String gatedId;
  final Future<void> gate;

  @override
  Future<void> save(Entry entry) async {
    if (entry.id == gatedId) await gate;
    return super.save(entry);
  }
}

/// A streaming engine whose live events the test drives by hand: each
/// [transcribeLive] call hands back a fresh controller, kept in [controllers] so
/// a test can emit on a superseded take's stream after a newer take started.
/// Unlike [FakeStreamingEngine] it does NOT suppress a late final on cancel, so
/// the service's own guards (isFinal drop, generation gate) are what must hold.
class _ManualLiveEngine implements StreamingTranscriptionEngine {
  final List<StreamController<TranscriptEvent>> controllers = [];

  @override
  String get id => 'manual.live';

  @override
  bool get onDeviceOnly => true;

  @override
  Future<List<String>> supportedLocales() async => const ['en-US'];

  @override
  Future<Availability> checkAvailability({required String localeId}) async =>
      const Availability.available();

  @override
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  }) async => Transcript(
    fullText: 'batch',
    segments: const [],
    localeId: localeId,
    engineId: id,
    createdAt: DateTime.utc(2026),
  );

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) {
    final controller = StreamController<TranscriptEvent>();
    controllers.add(controller);
    return controller.stream;
  }
}

/// An engine that would route off-device. Used only to prove the service rejects it.
class _CloudEngine implements TranscriptionEngine {
  @override
  String get id => 'cloud';

  @override
  Future<List<String>> supportedLocales() async => const [];

  @override
  bool get onDeviceOnly => false;

  @override
  Future<Availability> checkAvailability({required String localeId}) async =>
      const Availability.available();

  @override
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  }) async => throw UnimplementedError();
}
