import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  late LocalService storage;
  late EntryStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    store = EntryStore(storage);
  });

  TranscriptionService build(TranscriptionEngine engine, {FakeAudioRecorder? recorder}) =>
      TranscriptionService(
        recorder: recorder ?? FakeAudioRecorder(),
        engine: engine,
        store: store,
        composer: FakeAudioComposer(),
        clock: () => DateTime.utc(2026, 9, 6),
        idGenerator: () => 'id-0',
      );

  test('the model choice surfaces mirror the engine', () async {
    final engine = FakeModelChoiceEngine(installed: {'small'});
    final svc = build(engine);

    expect(svc.offersModelChoice, isTrue);
    expect(svc.modelChoices.map((m) => m.id), ['small', 'large']);
    expect(svc.selectedModelId, 'small');
    expect(await svc.installedModels(), {'small'});

    await svc.selectModel('large');
    expect(svc.selectedModelId, 'large');
    await svc.dispose();
  });

  test('a select, an install landing, and a real removal poke the model surfaces', () async {
    final engine = FakeModelChoiceEngine(installed: {'small'});
    final svc = build(engine);
    var pokes = 0;
    final sub = svc.modelStateChanged.listen((_) => pokes++);

    await svc.selectModel('large');
    await svc.installModelById('large').drain<void>();
    expect(await svc.removeModel('small'), isTrue);
    expect(await svc.removeModel('small'), isFalse);
    await pumpEventQueue();

    expect(pokes, 3);
    await sub.cancel();
    await svc.dispose();
  });

  test('an engine without a choice answers empty, none, done, and false', () async {
    final svc = build(FakeBatchEngine());

    expect(svc.offersModelChoice, isFalse);
    expect(svc.modelChoices, isEmpty);
    expect(svc.selectedModelId, isNull);
    expect(await svc.installedModels(), isEmpty);
    expect((await svc.installModelById('x').single).done, isTrue);
    expect(await svc.removeModel('x'), isFalse);
    await svc.selectModel('x');
    await svc.dispose();
  });

  test('a paced engine sets its own batch budget, so a zero budget times out at once', () async {
    final engine = FakeModelChoiceEngine(
      installed: {'small'},
      budgetFactor: 0,
      batchDelay: const Duration(milliseconds: 200),
    );
    final svc = build(engine, recorder: FakeAudioRecorder(duration: const Duration(seconds: 5)));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript, isNull);
    expect(engine.cancelBatchesCalls, 1);
    await svc.dispose();
  });

  test('a paced engine with a real budget lands its transcript', () async {
    final engine = FakeModelChoiceEngine(installed: {'small'});
    final svc = build(engine, recorder: FakeAudioRecorder(duration: const Duration(seconds: 5)));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript?.fullText, 'batch transcript');
    await svc.dispose();
  });

  test('a choice engine missing its model downloads it untimed before the budgeted run', () async {
    final engine = FakeModelChoiceEngine(budgetFactor: 0);
    final svc = build(engine, recorder: FakeAudioRecorder(duration: const Duration(seconds: 5)));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(engine.installs, ['small']);
    expect(entry.transcript?.fullText, 'batch transcript');
    await svc.dispose();
  });

  test('switching away from an engine that can release its memory releases it', () async {
    final whisperLike = FakeModelChoiceEngine(installed: {'small'});
    final svc = build(whisperLike);

    expect(svc.useEngine(FakeBatchEngine()), isTrue);
    await pumpEventQueue();

    expect(whisperLike.releases, 1);
    await svc.dispose();
  });

  test('a first-use download reports its model and progress, and its failure', () async {
    final engine = FakeModelChoiceEngine(installSteps: const [0.25]);
    final svc = build(engine, recorder: FakeAudioRecorder(duration: const Duration(seconds: 5)));
    final events = <FirstUseInstall>[];
    final errors = <Object>[];
    final sub = svc.firstUseInstalls.listen(events.add, onError: errors.add);

    await svc.startRecording();
    await svc.stopRecording();
    await pumpEventQueue();
    expect(events.map((e) => e.modelId).toSet(), {'small'});
    expect(events.map((e) => e.progress.fraction), [0.25, 1]);
    expect(events.last.progress.done, isTrue);

    engine.installed.clear();
    engine.failInstall = ModelInstallReason.noSpace;
    await svc.startRecording();
    final entry = await svc.stopRecording();
    await pumpEventQueue();
    expect(entry.transcript, isNull);
    expect(errors.single, isA<ModelInstallFailed>());

    await sub.cancel();
    await svc.dispose();
  });

  test('an idle releasable engine gives its memory back, a busy one keeps it', () async {
    final engine = FakeModelChoiceEngine(installed: {'small'});
    final svc = build(engine, recorder: FakeAudioRecorder(duration: const Duration(seconds: 5)));

    await svc.startRecording();
    await svc.releaseIdleEngine();
    expect(engine.releases, 0);

    await svc.stopRecording();
    await svc.releaseIdleEngine();
    expect(engine.releases, 1);
    await svc.dispose();
  });

  test('a switch under a user re-transcription defers the release until it lands', () async {
    final whisperLike = FakeModelChoiceEngine(
      installed: {'small'},
      batchDelay: const Duration(milliseconds: 50),
    );
    final svc = build(whisperLike);
    await svc.startRecording();
    final entry = await svc.stopRecording();

    final run = svc.retranscribe(entry);
    await Future<void>.delayed(Duration.zero);
    expect(svc.useEngine(FakeBatchEngine()), isTrue);
    await pumpEventQueue();
    expect(whisperLike.releases, 0);

    expect((await run).transcript?.fullText, 'batch transcript');
    await pumpEventQueue();
    expect(whisperLike.releases, 1);
    await svc.dispose();
  });
}
