import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/recorder_cubit.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

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

  test('a second resume inside the first one is a quiet no-op', () async {
    final (cubit, service) = build();
    await cubit.start();
    await cubit.pause();

    // Both taps see `paused` before either round trip lands.
    await Future.wait([cubit.resume(), cubit.resume()]);
    expect(cubit.state.status, RecorderStatus.recording);
    expect(cubit.state.error, isNull, reason: 'a double tap is not the user erring');

    // One timer, not two: elapsed must advance once per second.
    final before = cubit.state.elapsed;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(cubit.state.elapsed - before, const Duration(seconds: 1));

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
