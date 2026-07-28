import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/recorder_cubit.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

/// A streaming engine whose live streams are hand-fed by the test, so event
/// timing (a finished session flushing late) is scripted, not raced.
class _ScriptedLiveEngine extends FakeStreamingEngine {
  _ScriptedLiveEngine() : super(supportedLocaleTags: const ['en-US']);

  final List<StreamController<TranscriptEvent>> sessions = [];

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) {
    final controller = StreamController<TranscriptEvent>();
    sessions.add(controller);
    return controller.stream;
  }
}

void main() {
  late LocalService storage;
  late EntryStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    store = EntryStore(storage);
  });

  (RecorderCubit, TranscriptionService) build({FakeAudioRecorder? recorder}) {
    final rec = recorder ?? FakeAudioRecorder();
    final service = TranscriptionService(recorder: rec, engine: FakeBatchEngine(), store: store);
    return (RecorderCubit(service: service), service);
  }

  test('a switch during the start round-trip still languages the take', () async {
    // The regression: tapping the globe while the sheet is still rising used
    // to be silently dropped (the service was not recording yet), leaving the
    // whole take in the old language under a chip claiming the new one.
    final rec = FakeAudioRecorder(startDelay: const Duration(milliseconds: 20));
    final service = TranscriptionService(
      recorder: rec,
      engine: FakeStreamingEngine(supportedLocaleTags: const ['en-US', 'fr-FR']),
      store: store,
    );
    service.localeId = 'en-US';
    final cubit = RecorderCubit(service: service);

    final starting = cubit.start();
    await cubit.setLanguage('fr-FR');
    await starting;
    final entry = await cubit.stop();

    expect(entry?.recordedLocaleId, 'fr-FR');
    expect(entry?.transcript?.localeId, 'fr-FR');

    await cubit.close();
    await service.dispose();
  });

  test('the mic hearing sound latches heardSound, below-threshold noise does not', () async {
    // heardSound, not the live transcript, is what an X-to-discard consults: the
    // live stream can be blank over real speech. A room-tone level must not latch;
    // a spoken peak must, and it stays latched for the take.
    final rec = FakeAudioRecorder();
    final (cubit, service) = build(recorder: rec);
    await cubit.start();
    expect(cubit.state.heardSound, isFalse);

    rec.levelController.add(0.1); // quiet room floor
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.heardSound, isFalse);

    rec.levelController.add(0.6); // a spoken word
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.heardSound, isTrue);

    // Latched: a later dip back to silence does not clear it.
    rec.levelController.add(0.0);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.heardSound, isTrue);

    await cubit.close();
    await service.dispose();
  });

  test('a fresh take starts with heardSound reset to false', () async {
    final rec = FakeAudioRecorder();
    final (cubit, service) = build(recorder: rec);
    await cubit.start();
    rec.levelController.add(0.6);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.heardSound, isTrue);

    await cubit.stop();
    await cubit.start();
    expect(cubit.state.heardSound, isFalse);

    await cubit.close();
    await service.dispose();
  });

  test('a language switch keeps the live text and marks the new span', () async {
    final rec = FakeAudioRecorder();
    final service = TranscriptionService(
      recorder: rec,
      engine: FakeStreamingEngine(
        cannedText: 'hello world',
        stopSignal: rec.stopped,
        supportedLocaleTags: const ['en-US', 'fr-FR'],
      ),
      store: store,
    );
    final cubit = RecorderCubit(service: service);

    await cubit.start();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.liveText, 'hello world');

    await cubit.setLanguage('fr-FR');
    // Nothing spoken so far is thrown away: it commits with the new marker
    // (the restarted stream's first partials may already have flowed).
    expect(cubit.state.localeId, 'fr-FR');
    expect(cubit.state.liveText, startsWith('hello world [fr]'));

    // The restarted stream appends AFTER the committed prefix.
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.liveText, 'hello world [fr] hello world');

    // A switch before anything was said adds no marker; a restart clears all.
    await cubit.restart();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.liveText.contains('['), isFalse);

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('pause freezes the timer and status; resume continues', () async {
    final (cubit, service) = build();
    await cubit.start();
    expect(cubit.state.status, RecorderStatus.recording);

    await cubit.pause();
    expect(cubit.state.status, RecorderStatus.paused);
    expect(service.isPaused, isTrue);
    final frozen = cubit.state.elapsed;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.elapsed, frozen);

    await cubit.resume();
    expect(cubit.state.status, RecorderStatus.recording);
    expect(service.isPaused, isFalse);

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('pause when idle and resume when recording are quiet no-ops', () async {
    final (cubit, service) = build();

    await cubit.pause();
    expect(cubit.state.status, RecorderStatus.idle);
    expect(cubit.state.error, isNull);

    await cubit.start();
    await cubit.resume();
    expect(cubit.state.status, RecorderStatus.recording);
    expect(cubit.state.error, isNull);

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('a pause failure surfaces on state and stays recording', () async {
    final (cubit, service) = build(recorder: FakeAudioRecorder(throwOnPause: true));
    await cubit.start();

    await cubit.pause();

    expect(cubit.state.status, RecorderStatus.recording);
    expect(cubit.state.error, isNotNull);

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('restart discards the take and records fresh', () async {
    final (cubit, service) = build();
    await cubit.start();
    cubit.emit(cubit.state.copyWith(liveText: 'old words', elapsed: const Duration(seconds: 9)));

    await cubit.restart();

    expect(cubit.state.status, RecorderStatus.recording);
    expect(cubit.state.liveText, isEmpty);
    expect(cubit.state.elapsed, Duration.zero);
    expect(service.isRecording, isTrue);
    expect(service.entries(), isEmpty);

    await cubit.stop();
    expect(service.entries(), hasLength(1));

    await cubit.close();
    await service.dispose();
  });

  test('live waits for the platform to answer, and a failed start never claims it', () async {
    final recorder = FakeAudioRecorder();
    final (cubit, service) = build(recorder: recorder);

    final starting = cubit.start();
    // The status is the screen asking; live is the microphone answering.
    expect(cubit.state.isRecording, isTrue);
    expect(cubit.state.live, isFalse);
    await starting;
    expect(cubit.state.live, isTrue);

    await cubit.stop();
    expect(cubit.state.live, isFalse);

    recorder.throwOnStart = true;
    await cubit.start();
    expect(cubit.state.live, isFalse);
    expect(cubit.state.error, isNotNull);

    await cubit.close();
    await service.dispose();
  });

  test('an interruption stops the clock but leaves the take claimable', () async {
    final recorder = FakeAudioRecorder();
    final (cubit, service) = build(recorder: recorder);
    await cubit.start();

    // The native session dies and the service saves the entry itself.
    recorder.interrupt();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.live, isFalse, reason: 'the microphone is no longer open');
    expect(service.entries(), hasLength(1));

    // Complete must still hand back what the interruption saved, rather than
    // silently doing nothing.
    final entry = await cubit.stop();
    expect(entry, isNotNull);
    expect(service.entries(), hasLength(1));

    await cubit.close();
    await service.dispose();
  });

  test('an interruption latches the interrupted flag with the settled clock', () async {
    final recorder = FakeAudioRecorder();
    final (cubit, service) = build(recorder: recorder);
    await cubit.start();

    recorder.interrupt();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.interrupted, isTrue);
    expect(cubit.state.live, isFalse);

    await cubit.close();
    await service.dispose();
  });

  test('starting a new take clears the interrupted notice', () async {
    final recorder = FakeAudioRecorder();
    final (cubit, service) = build(recorder: recorder);
    await cubit.start();

    recorder.interrupt();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.interrupted, isTrue);

    await cubit.start();
    expect(cubit.state.interrupted, isFalse);

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('clearInterrupted dismisses without touching the rest of the state', () async {
    final recorder = FakeAudioRecorder();
    final (cubit, service) = build(recorder: recorder);
    await cubit.start();

    recorder.interrupt();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.interrupted, isTrue);
    final beforeClear = cubit.state;

    cubit.clearInterrupted();

    expect(cubit.state.interrupted, isFalse);
    expect(cubit.state.status, beforeClear.status);
    expect(cubit.state.elapsed, beforeClear.elapsed);
    expect(cubit.state.live, beforeClear.live);
    expect(cubit.state.error, beforeClear.error);

    await cubit.close();
    await service.dispose();
  });

  test('a second resume inside the first one is a quiet no-op', () async {
    final (cubit, service) = build();
    await cubit.start();
    await cubit.pause();

    // Both taps see `paused` before either round trip lands.
    await Future.wait([cubit.resume(), cubit.resume()]);
    expect(cubit.state.status, RecorderStatus.recording);
    expect(cubit.state.error, isNull, reason: 'a double tap is not the user erring');

    // One timer, not two. Elapsed reads the wall clock now, so a doubled
    // timer cannot double the value; what it WOULD do is emit twice. Assert
    // the clock advanced like real time, not like two summed tickers.
    final before = cubit.state.elapsed;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final delta = cubit.state.elapsed - before;
    expect(delta.inMilliseconds, greaterThanOrEqualTo(1000));
    expect(delta.inMilliseconds, lessThan(2000));

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('the take id advances on a fresh take but not across a pause', () async {
    final (cubit, service) = build();
    await cubit.start();
    final first = cubit.state.takeId;

    await cubit.pause();
    expect(cubit.state.takeId, first);
    await cubit.resume();
    expect(cubit.state.takeId, first);

    // A restart is a new take, so views holding the old one's buffer drop it.
    await cubit.restart();
    expect(cubit.state.takeId, greaterThan(first));

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('cancel from recording and from paused lands idle with nothing saved', () async {
    final (cubit, service) = build();

    await cubit.start();
    await cubit.cancel();
    expect(cubit.state.status, RecorderStatus.idle);
    expect(service.entries(), isEmpty);

    await cubit.start();
    await cubit.pause();
    await cubit.cancel();
    expect(cubit.state.status, RecorderStatus.idle);
    expect(service.isPaused, isFalse);
    expect(service.entries(), isEmpty);

    expect(await cubit.stop(), isNull);

    await cubit.close();
    await service.dispose();
  });

  test('pause during an in-flight start waits it out quietly', () async {
    final (cubit, service) = build(
      recorder: FakeAudioRecorder(startDelay: const Duration(milliseconds: 20)),
    );

    final starting = cubit.start();
    await cubit.pause();
    await starting;

    // The pause landed after the start settled: a real pause, no bogus error.
    expect(cubit.state.error, isNull);
    expect(cubit.state.status, RecorderStatus.paused);

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('restart while saving is a no-op', () async {
    final (cubit, service) = build(
      recorder: FakeAudioRecorder(stopDelay: const Duration(milliseconds: 20)),
    );
    await cubit.start();

    final stopping = cubit.stop();
    await cubit.restart();
    final entry = await stopping;

    expect(entry, isNotNull);
    expect(cubit.state.status, RecorderStatus.idle);
    expect(service.entries(), hasLength(1));

    await cubit.close();
    await service.dispose();
  });

  test('cancel during an in-flight start awaits it and lands idle', () async {
    final (cubit, service) = build(
      recorder: FakeAudioRecorder(startDelay: const Duration(milliseconds: 20)),
    );

    final starting = cubit.start();
    await cubit.cancel();
    await starting;

    expect(cubit.state.status, RecorderStatus.idle);
    expect(service.isRecording, isFalse);
    expect(service.entries(), isEmpty);

    await cubit.close();
    await service.dispose();
  });

  test('stop while paused saves and walks paused to saving to idle', () async {
    final (cubit, service) = build();
    final statuses = <RecorderStatus>[];
    final sub = cubit.stream.listen((s) => statuses.add(s.status));

    await cubit.start();
    await cubit.pause();
    final entry = await cubit.stop();
    // Stream delivery is a microtask behind the emit.
    await Future<void>.delayed(Duration.zero);

    expect(entry, isNotNull);
    expect(service.entries(), hasLength(1));
    expect(
      statuses,
      containsAllInOrder([
        RecorderStatus.recording,
        RecorderStatus.paused,
        RecorderStatus.saving,
        RecorderStatus.idle,
      ]),
    );

    await sub.cancel();
    await cubit.close();
    await service.dispose();
  });
  test('elapsed reads the wall clock, so throttled ticks cannot lose time', () async {
    // Background throttling starves Timer.periodic; a tick-counted clock lost
    // every missed second. The clock is now derived from now() anchors, which
    // pause/resume/interruption bank exactly.
    var now = DateTime(2026, 1, 1, 12);
    final rec = FakeAudioRecorder();
    final service = TranscriptionService(recorder: rec, engine: FakeBatchEngine(), store: store);
    final cubit = RecorderCubit(service: service, now: () => now);

    await cubit.start();
    // A 90s span with NO timer ticks delivered (as under background throttle).
    now = now.add(const Duration(seconds: 90));
    await cubit.pause();
    expect(cubit.state.elapsed, const Duration(seconds: 90));

    // Paused time never counts, however long it lasts.
    now = now.add(const Duration(seconds: 30));
    await cubit.resume();
    now = now.add(const Duration(seconds: 10));
    await cubit.pause();
    expect(cubit.state.elapsed, const Duration(seconds: 100));

    await cubit.resume();
    now = now.add(const Duration(seconds: 5));
    // An interruption settles the clock at the moment capture died.
    rec.interrupt();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.elapsed, const Duration(seconds: 105));
    expect(cubit.state.live, isFalse);

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('a backward wall-clock adjustment never shrinks elapsed', () async {
    var now = DateTime(2026, 1, 1, 12);
    final rec = FakeAudioRecorder();
    final service = TranscriptionService(recorder: rec, engine: FakeBatchEngine(), store: store);
    final cubit = RecorderCubit(service: service, now: () => now);

    await cubit.start();
    now = now.add(const Duration(seconds: 30));
    await cubit.pause();
    expect(cubit.state.elapsed, const Duration(seconds: 30));

    await cubit.resume();
    // The clock jumps BACKWARD mid-run (an NTP correction): elapsed must hold at
    // the banked base, not go negative or shrink below it.
    now = now.subtract(const Duration(seconds: 20));
    await cubit.pause();
    expect(cubit.state.elapsed, const Duration(seconds: 30));

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('a stop finalizing behind a popped sheet never clobbers the next take', () async {
    // The regression: complete pops the sheet and lets stop() finish behind it
    // (the batch pass takes seconds). A new take started in that window used
    // to be wiped when the old stop landed: its teardown killed the new live
    // subscription and its final emit reset the state under a hot microphone.
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 40));
    final (cubit, service) = build(recorder: rec);
    await cubit.start();

    final stopping = cubit.stop();
    // The service released the session synchronously; the recorder is still
    // finalizing. A new take begins inside that window.
    expect(service.isRecording, isFalse);
    await cubit.start();
    expect(cubit.state.isRecording, isTrue);
    final newTake = cubit.state.takeId;

    final first = await stopping;
    expect(first, isNotNull, reason: 'the finished take still hands its entry back');
    expect(cubit.state.isRecording, isTrue, reason: 'the stale stop must not wipe the new take');
    expect(cubit.state.takeId, newTake);

    final second = await cubit.stop();
    expect(second, isNotNull);
    expect(cubit.state.isBusy, isFalse);

    await cubit.close();
    await service.dispose();
  });

  test('a finished session flushing late never paints the next take', () async {
    // The field bug: complete a take, open a new one fast, and the OLD take's
    // live stream flushes its full transcript late (a native finalize can run
    // seconds behind; the claimed subscription's cancel runs only after the
    // recorder round trip). The service's live gate must drop it.
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 40));
    final engine = _ScriptedLiveEngine();
    final service = TranscriptionService(recorder: rec, engine: engine, store: store);
    final cubit = RecorderCubit(service: service);

    await cubit.start();
    engine.sessions.single.add(const TranscriptEvent(text: 'old take words', isFinal: false));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.liveText, 'old take words');

    // Complete: the sheet pops, the stop finalizes behind it; a fresh take
    // begins inside that window.
    final stopping = cubit.stop();
    cubit.prepareTake();
    await cubit.start();
    expect(cubit.state.liveText, isEmpty);

    // The finished session flushes late, into a broadcast the new take is
    // already listening to. Gate, not luck: the event must simply not land.
    engine.sessions.first.add(const TranscriptEvent(text: 'old take words', isFinal: true));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.liveText, isEmpty, reason: 'a stale flush must never cross takes');

    engine.sessions.last.add(const TranscriptEvent(text: 'new words', isFinal: false));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.liveText, 'new words');

    await stopping;
    expect(cubit.state.liveText, 'new words', reason: 'the stale stop left the new take alone');

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('a cancel finishing behind a popped sheet never clobbers the next take', () async {
    // cancel()'s final reset carries the same ownership rule as stop()'s.
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 40));
    final (cubit, service) = build(recorder: rec);
    await cubit.start();

    final cancelling = cubit.cancel();
    // start() waits out the discard, then records fresh.
    await cubit.start();
    expect(cubit.state.isRecording, isTrue);

    await cancelling;
    expect(cubit.state.isRecording, isTrue, reason: 'the stale cancel must not wipe the new take');

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('prepareTake clears a finishing take, and is quiet mid-take', () async {
    final rec = FakeAudioRecorder(stopDelay: const Duration(milliseconds: 40));
    final service = TranscriptionService(
      recorder: rec,
      engine: FakeStreamingEngine(cannedText: 'hello world', stopSignal: rec.stopped),
      store: store,
    );
    final cubit = RecorderCubit(service: service);
    await cubit.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.liveText, isNotEmpty);

    // Mid-take it must change nothing: a real session owns the state.
    cubit.prepareTake();
    expect(cubit.state.isRecording, isTrue);
    expect(cubit.state.liveText, isNotEmpty);

    // Complete: the sheet pops, the stop finalizes behind it, and the state
    // still wears the old take's text. A new sheet attaching NOW must see a
    // clean state, not the previous transcription.
    final stopping = cubit.stop();
    expect(cubit.state.liveText, isNotEmpty);
    cubit.prepareTake();
    expect(cubit.state.isBusy, isFalse);
    expect(cubit.state.liveText, isEmpty);

    expect(await stopping, isNotNull);
    expect(cubit.state.isBusy, isFalse);
    expect(cubit.state.liveText, isEmpty);

    await cubit.close();
    await service.dispose();
  });

  test('a fresh take never inherits a stranded one', () async {
    // The cubit outlives the recorder screen, so a state left BUSY with no
    // capture behind it (a stop that no-opped, an interruption left hanging)
    // would otherwise hand the next screen the previous take's text and clock.
    final (cubit, service) = build();
    await cubit.start();
    await service.cancelRecording();
    expect(cubit.state.isBusy, isTrue, reason: 'the cubit does not know it lost the session');

    await cubit.start();
    expect(cubit.state.status, RecorderStatus.recording);
    expect(cubit.state.liveText, isEmpty);
    expect(cubit.state.elapsed, Duration.zero);
    expect(service.isRecording, isTrue);

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });

  test('a start while one is genuinely in flight is still a no-op', () async {
    final (cubit, service) = build();
    final first = cubit.start();
    // Synchronous, so it lands inside the first start's platform round trip.
    final second = cubit.start();
    await Future.wait([first, second]);

    expect(cubit.state.takeId, 1);
    expect(service.entries(), isEmpty);

    await cubit.stop();
    await cubit.close();
    await service.dispose();
  });
}
