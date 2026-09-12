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
  const window = Duration(milliseconds: 100);

  late LocalService storage;
  late EntryStore store;
  late Directory dir;
  late FakeAudioRecorder recorder;
  var now = Duration.zero;
  var wall = fixedClock;
  var idCounter = 0;

  TranscriptionService build(TranscriptionEngine engine) {
    idCounter = 0;
    return TranscriptionService(
      recorder: recorder,
      engine: engine,
      store: store,
      composer: FakeAudioComposer(
        name: 'merged.m4a',
        durations: const {'base.m4a': Duration(seconds: 10), 'tail.m4a': Duration(seconds: 2)},
      ),
      clock: () => wall,
      monotonic: () => now,
      idGenerator: () => 'id-${idCounter++}',
      fileDeleter: (f) async => f.deleteSync(),
    );
  }

  Future<void> speak(double level, int windows) async {
    for (var i = 0; i < windows; i++) {
      now += window;
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
    now = Duration.zero;
    wall = fixedClock;
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('every event of a fresh take\'s pass carries its forecast', () async {
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
    expect(forecast.characters, 32);
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
    final svc = build(FakeBatchEngine(cannedText: 'words'));
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.startRecording();
    await speak(0.1, 10);
    await speak(0.8, 10);
    await svc.pauseRecording();
    now += const Duration(minutes: 3);
    await svc.resumeRecording();
    await speak(0.8, 10);
    await svc.stopRecording();
    await pumpEventQueue();

    expect(events.first.forecast?.speech, const Duration(seconds: 2));

    await svc.dispose();
  });

  test('a two-language take forecasts each span at its own pace', () async {
    recorder = FakeAudioRecorder(
      recordingsDir: dir.path,
      path: 'tail.m4a',
      duration: const Duration(seconds: 10),
    );
    final svc = build(
      FakeBatchEngine(cannedText: 'words', supportedLocaleTags: ['en-US', 'ja-JP']),
    );
    final events = <BatchProgress>[];
    svc.batchProgress.listen(events.add);

    await svc.startRecording();
    wall = wall.add(const Duration(seconds: 5));
    await svc.setSessionLocale('ja-JP');
    await speak(0.1, 10);
    await speak(0.8, 20);
    await svc.stopRecording();
    await pumpEventQueue();

    expect(events.first.forecast?.characters, 23);
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
}
