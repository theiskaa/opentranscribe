import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
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

    // The batch pass runs long; the user deletes the entry mid-flight.
    final retranscribing = svc.retranscribe(
      entry,
      using: FakeBatchEngine(delay: const Duration(milliseconds: 30)),
    );
    await svc.deleteEntry(entry);

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
  Future<Transcript> transcribeFile(File audio, {required String localeId}) async =>
      throw UnimplementedError();
}
