import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) {
    final rec = recorder ?? FakeAudioRecorder();
    idCounter = 0;
    return TranscriptionService(
      recorder: rec,
      engine: engine(rec),
      store: store,
      clock: () => fixedClock,
      idGenerator: () => 'id-${idCounter++}',
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
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
