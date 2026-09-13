import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/speaking_pace.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_recorder.dart';

class _BrokenPace extends SpeakingPace {
  _BrokenPace(LocalService storage) : super(storage: storage);

  @override
  Future<void> learn(String localeId, {required int characters, required Duration speech}) =>
      throw StateError('storage gone');
}

void main() {
  const key = 'test-encryption-key-0123456789ab';
  final fixedClock = DateTime.utc(2026, 3, 4, 12);
  const window = Duration(milliseconds: 100);

  late LocalService storage;
  late EntryStore store;
  late Directory dir;
  late FakeAudioRecorder recorder;
  var wall = fixedClock;
  var idCounter = 0;

  TranscriptionService build(
    TranscriptionEngine engine, {
    SpeakingPace? pace,
    FakeAudioComposer? composer,
  }) {
    idCounter = 0;
    return TranscriptionService(
      recorder: recorder,
      engine: engine,
      store: store,
      composer:
          composer ??
          FakeAudioComposer(
            name: 'merged.m4a',
            durations: const {'base.m4a': Duration(seconds: 10), 'tail.m4a': Duration(seconds: 2)},
          ),
      clock: () => wall,
      idGenerator: () => 'id-${idCounter++}',
      fileDeleter: (f) async => f.deleteSync(),
      pace: pace,
    );
  }

  void recordTakeOf(int windows) => recorder = FakeAudioRecorder(
    recordingsDir: dir.path,
    path: 'tail.m4a',
    duration: window * windows,
  );

  Future<void> speak(double level, int windows) async {
    for (var i = 0; i < windows; i++) {
      recorder.levelController.add(level);
      await pumpEventQueue();
    }
  }

  Future<Entry> seedBase({Transcript? transcript}) async {
    final entry = Entry(
      id: 'base',
      createdAt: fixedClock,
      audioPath: 'base.m4a',
      duration: const Duration(seconds: 10),
      transcript: transcript,
      recordedLocaleId: 'en-US',
    );
    await store.save(entry);
    return entry;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    store = EntryStore(storage);
    dir = await Directory.systemTemp.createTemp('otr-forecast');
    File('${dir.path}/base.m4a').writeAsStringSync('base');
    File('${dir.path}/tail.m4a').writeAsStringSync('tail');
    recorder = FakeAudioRecorder(recordingsDir: dir.path, path: 'tail.m4a');
    wall = fixedClock;
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('every event of a fresh take\'s pass carries its forecast', () async {
    recordTakeOf(30);
    final svc = build(FakeBatchEngine(cannedText: 'hello there'));
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.startRecording();
    await speak(0.1, 10);
    await speak(0.8, 20);
    await svc.stopRecording();
    await pumpEventQueue();

    expect(events, isNotEmpty);
    final forecast = events.first.forecast!;
    expect(forecast.audio, recorder.duration);
    expect(forecast.speech, const Duration(seconds: 2));
    expect(forecast.localeId, 'en-US');
    expect(forecast.characters, 28);
    expect(forecast.liveWords, isEmpty);
    expect(
      events,
      everyElement(
        isA<BatchProgress>()
            .having((e) => e.forecast, 'forecast', forecast)
            .having((e) => e.entryId, 'entryId', isNull),
      ),
    );

    await svc.dispose();
  });

  test('a live take\'s forecast carries the words its live pass heard', () async {
    final svc = build(FakeStreamingEngine(cannedText: 'heard live', stopSignal: recorder.stopped));
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.startRecording();
    await svc.liveEvents.firstWhere((event) => event.text == 'heard live');
    await svc.stopRecording();
    await pumpEventQueue();

    expect(events.first.forecast?.liveWords, 'heard live');

    await svc.dispose();
  });

  test('a continuation\'s tail pass carries the take\'s forecast under the base', () async {
    await seedBase(
      transcript: Transcript(
        fullText: 'before',
        segments: const [
          TranscriptSegment(text: 'before', start: Duration.zero, end: Duration(seconds: 1)),
        ],
        localeId: 'en-US',
        engineId: 'fake',
        createdAt: fixedClock,
      ),
    );
    recordTakeOf(15);
    final svc = build(FakeBatchEngine(cannedText: 'after'));
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.startRecording(continuing: store.read('base'));
    await speak(0.1, 5);
    await speak(0.8, 10);
    await svc.stopRecording();
    await pumpEventQueue();

    expect(events, isNotEmpty);
    expect(events, everyElement(isA<BatchProgress>().having((e) => e.entryId, 'entryId', 'base')));
    expect(events.first.forecast?.speech, const Duration(seconds: 1));

    await svc.dispose();
  });

  test('an unheard base\'s whole-file pass carries no forecast', () async {
    await seedBase();
    final svc = build(FakeBatchEngine(cannedText: 'all of it'));
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.startRecording(continuing: store.read('base'));
    await speak(0.8, 10);
    await svc.stopRecording();
    await pumpEventQueue();

    expect(events, isNotEmpty);
    expect(
      events,
      everyElement(isA<BatchProgress>().having((e) => e.forecast, 'forecast', isNull)),
    );

    await svc.dispose();
  });

  test(
    'a never-transcribed base whose merge fails gives its take a pass without a forecast',
    () async {
      await seedBase();
      final svc = build(
        FakeBatchEngine(cannedText: 'tail words'),
        composer: FakeAudioComposer(throwOnConcatenate: true),
      );
      final events = <BatchProgress>[];
      svc.batchProgress.listen(events.add);

      await svc.startRecording(continuing: store.read('base'));
      await speak(0.8, 10);
      final saved = await svc.stopRecording();
      await pumpEventQueue();

      expect(saved.id, isNot('base'));
      expect(saved.transcript?.fullText, 'tail words');
      expect(events, isNotEmpty);
      expect(
        events,
        everyElement(isA<BatchProgress>().having((e) => e.forecast, 'forecast', isNull)),
      );

      await svc.dispose();
    },
  );

  test('a re-transcribe carries no forecast', () async {
    final svc = build(FakeBatchEngine(cannedText: 'words'));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.retranscribe(entry);
    await pumpEventQueue();

    expect(events, isNotEmpty);
    expect(
      events,
      everyElement(isA<BatchProgress>().having((e) => e.forecast, 'forecast', isNull)),
    );

    await svc.dispose();
  });

  test('a cancelled take\'s speech never reaches the next take\'s forecast', () async {
    recordTakeOf(15);
    final svc = build(FakeBatchEngine(cannedText: 'words'));
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.startRecording();
    await speak(0.8, 30);
    await svc.cancelRecording();
    await svc.startRecording();
    await speak(0.1, 10);
    await speak(0.8, 5);
    await svc.stopRecording();
    await pumpEventQueue();

    expect(events.first.forecast?.speech, const Duration(milliseconds: 500));

    await svc.dispose();
  });

  test('a paused stretch adds nothing to the speech time', () async {
    recordTakeOf(30);
    final svc = build(FakeBatchEngine(cannedText: 'words'));
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.startRecording();
    await speak(0.1, 10);
    await speak(0.8, 10);
    await svc.pauseRecording();
    await svc.resumeRecording();
    await speak(0.8, 10);
    await svc.stopRecording();
    await pumpEventQueue();

    expect(events.first.forecast?.speech, const Duration(seconds: 2));

    await svc.dispose();
  });

  test('a two-language take forecasts each span at its own pace', () async {
    recordTakeOf(100);
    final svc = build(
      FakeBatchEngine(cannedText: 'words', supportedLocaleTags: ['en-US', 'ja-JP']),
    );
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.startRecording();
    wall = wall.add(const Duration(seconds: 5));
    await svc.setSessionLocale('ja-JP');
    await speak(0.1, 50);
    await speak(0.8, 50);
    await svc.stopRecording();
    await pumpEventQueue();

    expect(events.first.forecast?.characters, 50);
    expect(events.first.forecast?.localeId, 'en-US');

    await svc.dispose();
  });

  group('the level windows stop feeding the take', () {
    test('once it is stopped', () async {
      final svc = build(FakeBatchEngine(cannedText: 'words'));
      await svc.startRecording();
      expect(recorder.levelController.hasListener, isTrue);
      await svc.stopRecording();
      expect(recorder.levelController.hasListener, isFalse);
      await svc.dispose();
    });

    test('when its stop fails', () async {
      recorder = FakeAudioRecorder(recordingsDir: dir.path, path: 'tail.m4a', throwOnStop: true);
      final svc = build(FakeBatchEngine(cannedText: 'words'));
      await svc.startRecording();
      await expectLater(svc.stopRecording(), throwsA(anything));
      expect(recorder.levelController.hasListener, isFalse);
      await svc.dispose();
    });

    test('once it is cancelled', () async {
      final svc = build(FakeBatchEngine(cannedText: 'words'));
      await svc.startRecording();
      await svc.cancelRecording();
      expect(recorder.levelController.hasListener, isFalse);
      await svc.dispose();
    });

    test('when it never started', () async {
      recorder = FakeAudioRecorder(recordingsDir: dir.path, path: 'tail.m4a', throwOnStart: true);
      final svc = build(FakeBatchEngine(cannedText: 'words'));
      await expectLater(svc.startRecording(), throwsA(anything));
      expect(recorder.levelController.hasListener, isFalse);
      await svc.dispose();
    });

    test('once the service is disposed mid-take', () async {
      final svc = build(FakeBatchEngine(cannedText: 'words'));
      await svc.startRecording();
      await svc.dispose();
      expect(recorder.levelController.hasListener, isFalse);
    });
  });

  group('the pace', () {
    final learnedFromTake = nextPace(null, observed: 100 / 4, starting: 14);

    Future<SpeakingPace> afterTake(
      TranscriptionEngine Function(FakeAudioRecorder recorder) engine, {
      int speaking = 40,
      String? secondLanguage,
      bool continuing = false,
      bool live = false,
    }) async {
      recordTakeOf(10 + speaking);
      final svc = build(engine(recorder), pace: SpeakingPace(storage: storage));
      await svc.startRecording(continuing: continuing ? store.read('base') : null);
      if (secondLanguage != null) {
        wall = wall.add(const Duration(seconds: 5));
        await svc.setSessionLocale(secondLanguage);
      }
      if (live) await svc.liveEvents.first;
      await speak(0.1, 10);
      await speak(0.8, speaking);
      await svc.stopRecording();
      await pumpEventQueue();
      await svc.dispose();
      return SpeakingPace(storage: storage);
    }

    test('learns from a one-language take that landed words', () async {
      final pace = await afterTake((_) => FakeBatchEngine(cannedText: 'x' * 100));
      expect(pace.of('en-US'), closeTo(learnedFromTake, 1e-9));
    });

    test('learns from a continuation\'s own words, not the entry they grew', () async {
      await seedBase(
        transcript: Transcript(
          fullText: 'y' * 200,
          segments: [
            TranscriptSegment(
              text: 'y' * 200,
              start: Duration.zero,
              end: const Duration(seconds: 9),
            ),
          ],
          localeId: 'en-US',
          engineId: 'fake',
          createdAt: fixedClock,
        ),
      );
      final pace = await afterTake((_) => FakeBatchEngine(cannedText: 'x' * 100), continuing: true);
      expect(pace.of('en-US'), closeTo(learnedFromTake, 1e-9));
    });

    test('learns nothing from an unheard entry\'s pass over the whole grown file', () async {
      await seedBase();
      final pace = await afterTake((_) => FakeBatchEngine(cannedText: 'x' * 100), continuing: true);
      expect(pace.of('en-US'), 14);
    });

    test('learns nothing from a take under three seconds of speech', () async {
      final pace = await afterTake((_) => FakeBatchEngine(cannedText: 'x' * 100), speaking: 20);
      expect(pace.of('en-US'), 14);
    });

    test('learns nothing from a two-language take, in either language', () async {
      final pace = await afterTake(
        (_) => FakeBatchEngine(cannedText: 'x' * 100, supportedLocaleTags: ['en-US', 'ja-JP']),
        secondLanguage: 'ja-JP',
      );
      expect(pace.of('en-US'), 14);
      expect(pace.of('ja-JP'), 6);
    });

    test('learns nothing from a pass that heard no words', () async {
      final pace = await afterTake((_) => FakeBatchEngine(cannedText: ''));
      expect(pace.of('en-US'), 14);
    });

    test('learns nothing from live words saved in place of a failed pass', () async {
      final pace = await afterTake(
        (rec) =>
            FakeStreamingEngine(cannedText: 'x' * 100, failBatch: true, stopSignal: rec.stopped),
        live: true,
      );
      expect(pace.of('en-US'), 14);
    });

    test('forecasts the next take at the pace it learned', () async {
      final learned = SpeakingPace(storage: storage);
      await learned.learn('en-US', characters: 250, speech: const Duration(seconds: 10));
      final svc = build(
        FakeBatchEngine(cannedText: 'words'),
        pace: SpeakingPace(storage: storage),
      );
      final events = <BatchProgress>[];
      svc.batchProgress.listen(events.add);

      await svc.startRecording();
      await speak(0.1, 10);
      await speak(0.8, 10);
      await svc.stopRecording();
      await pumpEventQueue();

      expect(events.first.forecast?.characters, learned.of('en-US').round());

      await svc.dispose();
    });

    test('a pace that cannot learn never costs the take its words', () async {
      final svc = build(FakeBatchEngine(cannedText: 'x' * 100), pace: _BrokenPace(storage));
      await svc.startRecording();
      await speak(0.1, 10);
      await speak(0.8, 40);
      final entry = await svc.stopRecording();
      await pumpEventQueue();

      expect(entry.transcript?.fullText, 'x' * 100);

      await svc.dispose();
    });
  });
}
