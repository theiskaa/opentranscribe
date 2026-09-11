import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/engine_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  late LocalService storage;
  late FakeModelChoiceEngine engine;
  late TranscriptionService service;
  late EngineSettings engineSettings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    engine = FakeModelChoiceEngine(installed: {'small'});
    final recorder = FakeAudioRecorder();
    service = TranscriptionService(
      recorder: recorder,
      engine: engine,
      store: EntryStore(storage),
      composer: FakeAudioComposer(),
    );
    engineSettings = EngineSettings(storage: storage);
  });

  tearDown(() => service.dispose());

  ModelsCubit buildFor(TranscriptionService scoped, {int? memory}) {
    final cubit = ModelsCubit(
      service: scoped,
      engineSettings: engineSettings,
      physicalMemoryBytes: memory,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  ModelsCubit build({int? memory}) => buildFor(service, memory: memory);

  SettingsCubit settingsOver(ModelsCubit models) {
    final cubit = SettingsCubit(
      service: service,
      transcription: TranscriptionSettings(
        storage: storage,
        service: service,
        deviceTag: () => 'en-US',
      ),
      audioStorage: AudioStorageSettings(storage: storage, recorder: FakeAudioRecorder()),
      models: models,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  (ModelsCubit, FakeModelChoiceEngine) buildAccelerating({
    bool accelerated = false,
    Set<String> acceleratedModelIds = const {},
    Future<void>? prepareGate,
    Future<void>? installGate,
  }) {
    final accelerating = FakeModelChoiceEngine(
      installed: {'small'},
      canAccelerate: true,
      accelerated: accelerated,
      acceleratedModelIds: acceleratedModelIds,
      installGate: installGate,
    )..prepareGate = prepareGate;
    final scoped = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: accelerating,
      store: EntryStore(storage),
      composer: FakeAudioComposer(),
    );
    addTearDown(scoped.dispose);
    return (buildFor(scoped), accelerating);
  }

  ModelRowState rowOf(ModelsCubit cubit, String id) =>
      cubit.state.models.firstWhere((r) => r.option.id == id);

  test('the model rows follow the engine: installed, selected, and heavy per phone', () async {
    final cubit = build(memory: 6000);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.offersModelChoice, isTrue);
    expect(cubit.state.models.map((r) => r.option.id), ['small', 'large']);
    expect(rowOf(cubit, 'small').installed, isTrue);
    expect(rowOf(cubit, 'small').selected, isTrue);
    expect(rowOf(cubit, 'small').heavy, isFalse);
    expect(rowOf(cubit, 'large').installed, isFalse);
    expect(rowOf(cubit, 'large').heavy, isTrue);
  });

  test('an engine without acceleration offers no switch', () async {
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.offersAcceleration, isFalse);
    expect(cubit.state.accelerated, isFalse);
  });

  test(
    'turning acceleration on persists it and fetches every installed model\'s extra file',
    () async {
      final (cubit, accelerating) = buildAccelerating();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.offersAcceleration, isTrue);

      await cubit.setAccelerated(true);
      await pumpEventQueue();

      expect(cubit.state.accelerated, isTrue);
      expect(engineSettings.acceleratedFor(accelerating.id), isTrue);
      expect(accelerating.accelerationInstalls, ['small']);
      expect(rowOf(cubit, 'small').accelerated, isTrue);
      expect(rowOf(cubit, 'small').installing, isFalse);
      expect(rowOf(cubit, 'large').accelerated, isFalse);
    },
  );

  test('a preparing install shows no percent and cannot be cancelled', () async {
    final gate = Completer<void>();
    final (cubit, _) = buildAccelerating(prepareGate: gate.future);
    await Future<void>.delayed(Duration.zero);

    await cubit.setAccelerated(true);
    await pumpEventQueue();
    expect(rowOf(cubit, 'small').installing, isTrue);
    expect(rowOf(cubit, 'small').preparing, isTrue);
    expect(rowOf(cubit, 'small').cancellable, isFalse);

    gate.complete();
    await pumpEventQueue();
    expect(rowOf(cubit, 'small').installing, isFalse);
    expect(rowOf(cubit, 'small').accelerated, isTrue);
  });

  test('turning acceleration off leaves every row plain', () async {
    final (cubit, accelerating) = buildAccelerating(
      accelerated: true,
      acceleratedModelIds: {'small'},
    );
    await Future<void>.delayed(Duration.zero);
    expect(rowOf(cubit, 'small').accelerated, isTrue);

    await cubit.setAccelerated(false);
    await pumpEventQueue();

    expect(cubit.state.accelerated, isFalse);
    expect(engineSettings.acceleratedFor(accelerating.id), isFalse);
    expect(rowOf(cubit, 'small').accelerated, isFalse);
  });

  test('turning the switch off ends the downloads it started', () async {
    final gate = Completer<void>();
    final (cubit, accelerating) = buildAccelerating(installGate: gate.future);
    await Future<void>.delayed(Duration.zero);
    await cubit.setAccelerated(true);
    await pumpEventQueue();
    expect(rowOf(cubit, 'small').installing, isTrue);

    await cubit.setAccelerated(false);
    gate.complete();
    await pumpEventQueue();

    expect(rowOf(cubit, 'small').installing, isFalse);
    expect(rowOf(cubit, 'small').accelerated, isFalse);
    expect(accelerating.acceleratedIds, isEmpty);
  });

  test('a failed encoder download stays on an installed row while the switch is on', () async {
    final (cubit, accelerating) = buildAccelerating();
    await Future<void>.delayed(Duration.zero);
    accelerating.failInstall = ModelInstallReason.rejected;

    await cubit.setAccelerated(true);
    await pumpEventQueue();

    expect(rowOf(cubit, 'small').installed, isTrue);
    expect(rowOf(cubit, 'small').failure, ModelInstallReason.rejected);
  });

  test('a download alone on the engine never reads as queued', () async {
    final gate = Completer<void>();
    engine.startGate = gate.future;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await pumpEventQueue();

    expect(rowOf(cubit, 'large').installing, isTrue);
    expect(rowOf(cubit, 'large').queued, isFalse);
    gate.complete();
    await pumpEventQueue();
  });

  test('a download started behind another waits in the queue until its turn', () async {
    final gate = Completer<void>();
    final busy = FakeModelChoiceEngine()..startGate = gate.future;
    final scoped = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: busy,
      store: EntryStore(storage),
      composer: FakeAudioComposer(),
    );
    addTearDown(scoped.dispose);
    final cubit = buildFor(scoped);
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('small');
    await cubit.installModelById('large');
    await pumpEventQueue();

    expect(rowOf(cubit, 'small').queued, isFalse);
    expect(rowOf(cubit, 'large').queued, isTrue);
    expect(rowOf(cubit, 'large').cancellable, isTrue);

    gate.complete();
    await pumpEventQueue();
    expect(rowOf(cubit, 'large').queued, isFalse);
    expect(rowOf(cubit, 'large').installed, isTrue);
  });

  test('an unknown memory figure dims nothing', () async {
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.models.every((r) => !r.heavy), isTrue);
  });

  test('selecting a model moves the mark and persists the choice per engine', () async {
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.selectModel('large');
    await Future<void>.delayed(Duration.zero);

    expect(rowOf(cubit, 'large').selected, isTrue);
    expect(rowOf(cubit, 'small').selected, isFalse);
    expect(engineSettings.modelIdFor(engine.id), 'large');
  });

  test('an install streams its fraction, lands installed, and selects the model', () async {
    engine.installSteps = [0.3, 0.7];
    final gate = Completer<void>();
    engine.installGate = gate.future;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await Future<void>.delayed(Duration.zero);
    expect(rowOf(cubit, 'large').installing, isTrue);
    expect(rowOf(cubit, 'large').installFraction, 0.7);

    gate.complete();
    await pumpEventQueue();

    expect(rowOf(cubit, 'large').installing, isFalse);
    expect(rowOf(cubit, 'large').installed, isTrue);
    expect(rowOf(cubit, 'large').selected, isTrue);
    expect(engineSettings.modelIdFor(engine.id), 'large');
  });

  test('an install landing after the choice moved on leaves the new choice alone', () async {
    final gate = Completer<void>();
    const medium = ModelOption(
      id: 'medium',
      displayName: 'Medium',
      bytes: 300,
      quality: ModelQuality.best,
      peakMemoryBytes: 3000,
    );
    final three = FakeModelChoiceEngine(
      models: [...engine.models, medium],
      installed: {'small', 'medium'},
      installGate: gate.future,
    );
    final scoped = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: three,
      store: EntryStore(storage),
      composer: FakeAudioComposer(),
    );
    addTearDown(scoped.dispose);
    final cubit = buildFor(scoped);
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await Future<void>.delayed(Duration.zero);
    await cubit.selectModel('medium');
    gate.complete();
    await pumpEventQueue();

    expect(rowOf(cubit, 'large').installed, isTrue);
    expect(rowOf(cubit, 'medium').selected, isTrue);
    expect(engineSettings.modelIdFor(three.id), 'medium');
  });

  test('a second tap on an installing model is a no-op', () async {
    final gate = Completer<void>();
    engine.installGate = gate.future;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await cubit.installModelById('large');
    await Future<void>.delayed(Duration.zero);

    expect(engine.installs, ['large']);
    gate.complete();
  });

  test('a failed install lands its reason on the row and a retry clears it', () async {
    engine.failInstall = ModelInstallReason.offline;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await pumpEventQueue();
    expect(rowOf(cubit, 'large').failure, ModelInstallReason.offline);
    expect(rowOf(cubit, 'large').installed, isFalse);

    engine.failInstall = null;
    await cubit.installModelById('large');
    await Future<void>.delayed(Duration.zero);
    expect(rowOf(cubit, 'large').failure, isNull);
  });

  test('a failed download neither selects the model nor saves it as the choice', () async {
    engine.failInstall = ModelInstallReason.offline;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await pumpEventQueue();

    expect(engine.selectedModelId, 'small');
    expect(engineSettings.modelIdFor(engine.id), isNot('large'));
    expect(rowOf(cubit, 'large').failure, ModelInstallReason.offline);
  });

  test('a model that would not open keeps saying so through a reload', () async {
    final (cubit, accelerating) = buildAccelerating();
    await Future<void>.delayed(Duration.zero);
    accelerating.failInstall = ModelInstallReason.loadFailed;

    await cubit.setAccelerated(true);
    await pumpEventQueue();
    await cubit.load();

    expect(rowOf(cubit, 'small').installed, isTrue);
    expect(rowOf(cubit, 'small').failure, ModelInstallReason.loadFailed);
  });

  test('a retry on a model that would not open removes its file and downloads it afresh', () async {
    final (cubit, accelerating) = buildAccelerating();
    await Future<void>.delayed(Duration.zero);
    accelerating.failInstall = ModelInstallReason.loadFailed;
    await cubit.setAccelerated(true);
    await pumpEventQueue();
    accelerating.failInstall = null;

    expect(await cubit.installModelById('small'), isTrue);
    await pumpEventQueue();

    expect(accelerating.removals, ['small']);
    expect(accelerating.installs, ['small']);
    expect(accelerating.installed, contains('small'));
    expect(rowOf(cubit, 'small').failure, isNull);
    expect(rowOf(cubit, 'small').installed, isTrue);
  });

  test('a retry whose removal a run refuses keeps the failure and downloads nothing', () async {
    final (cubit, accelerating) = buildAccelerating();
    await Future<void>.delayed(Duration.zero);
    accelerating.failInstall = ModelInstallReason.loadFailed;
    await cubit.setAccelerated(true);
    await pumpEventQueue();
    accelerating
      ..failInstall = null
      ..refuseRemove = true;

    expect(await cubit.installModelById('small'), isFalse);
    await pumpEventQueue();

    expect(accelerating.installs, isEmpty);
    expect(rowOf(cubit, 'small').failure, ModelInstallReason.loadFailed);
  });

  test('two quick retries on a model that would not open remove it once', () async {
    final (cubit, accelerating) = buildAccelerating();
    await Future<void>.delayed(Duration.zero);
    accelerating.failInstall = ModelInstallReason.loadFailed;
    await cubit.setAccelerated(true);
    await pumpEventQueue();
    accelerating.failInstall = null;

    await Future.wait([cubit.installModelById('small'), cubit.installModelById('small')]);
    await pumpEventQueue();

    expect(accelerating.removals, ['small']);
  });

  test('removing a model that would not open drops its failure with the file', () async {
    final (cubit, accelerating) = buildAccelerating();
    await Future<void>.delayed(Duration.zero);
    accelerating.failInstall = ModelInstallReason.loadFailed;
    await cubit.setAccelerated(true);
    await pumpEventQueue();

    expect(await cubit.removeModel('small'), isTrue);
    await pumpEventQueue();

    expect(rowOf(cubit, 'small').installed, isFalse);
    expect(rowOf(cubit, 'small').failure, isNull);
  });

  test('removing a model drops it from installed and leaves the selection', () async {
    engine.installed.add('large');
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    expect(await cubit.removeModel('large'), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(rowOf(cubit, 'large').installed, isFalse);
    expect(rowOf(cubit, 'small').selected, isTrue);
  });

  test('a refused removal answers false and changes nothing', () async {
    engine.refuseRemove = true;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    expect(await cubit.removeModel('small'), isFalse);
    expect(rowOf(cubit, 'small').installed, isTrue);
  });

  test('a model-side change on the service reaches the rows without a tap', () async {
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    engine.installed.add('large');
    await service.installModelById('large').drain<void>();
    await Future<void>.delayed(Duration.zero);

    expect(rowOf(cubit, 'large').installed, isTrue);
  });

  test('an engine without a choice offers no rows', () async {
    final scoped = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeManagedEngine(),
      store: EntryStore(storage),
      composer: FakeAudioComposer(),
    );
    addTearDown(scoped.dispose);
    final cubit = buildFor(scoped);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.offersModelChoice, isFalse);
    expect(cubit.state.models, isEmpty);
  });

  test('a language install under a model choice downloads the selected model instead', () async {
    engine.installed.clear();
    final gate = Completer<void>();
    engine.installGate = gate.future;
    final cubit = build();
    final settings = settingsOver(cubit);
    await Future<void>.delayed(Duration.zero);

    settings.install('en-US');
    await Future<void>.delayed(Duration.zero);

    expect(engine.installs, ['small']);
    expect(rowOf(cubit, 'small').installing, isTrue);
    final defaultRow = settings.state.languages.firstWhere((r) => r.isDefault);
    expect(defaultRow.installing, isTrue);
    expect(defaultRow.installFraction, rowOf(cubit, 'small').installFraction);
    gate.complete();
  });

  test(
    'a first-use download a batch started shows on the selected model and default rows',
    () async {
      engine.installed.clear();
      engine.installSteps = [0.4];
      final gate = Completer<void>();
      engine.installGate = gate.future;
      final cubit = build();
      final settings = settingsOver(cubit);
      await Future<void>.delayed(Duration.zero);

      await service.startRecording();
      final stop = service.stopRecording();
      await pumpEventQueue();

      expect(rowOf(cubit, 'small').installFraction, 0.4);
      expect(settings.state.languages.firstWhere((r) => r.isDefault).installFraction, 0.4);
      gate.complete();
      await stop;
      await pumpEventQueue();

      expect(rowOf(cubit, 'small').installed, isTrue);
      expect(rowOf(cubit, 'small').installing, isFalse);
      expect(settings.state.languages.firstWhere((r) => r.isDefault).installing, isFalse);
    },
  );

  test('a download of a model other than the choice never reaches the default language', () async {
    final gate = Completer<void>();
    engine.installGate = gate.future;
    final cubit = build();
    final settings = settingsOver(cubit);
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await pumpEventQueue();

    expect(rowOf(cubit, 'large').installing, isTrue);
    expect(settings.state.languages.firstWhere((r) => r.isDefault).installing, isFalse);
    gate.complete();
  });

  test('a switch to an engine without a choice clears the mirrored download', () async {
    engine.installed.clear();
    final gate = Completer<void>();
    engine.installGate = gate.future;
    final cubit = build();
    final settings = settingsOver(cubit);
    await Future<void>.delayed(Duration.zero);
    settings.install('en-US');
    await pumpEventQueue();
    expect(settings.state.languages.firstWhere((r) => r.isDefault).installing, isTrue);

    expect(service.useEngine(FakeBatchEngine()), isTrue);
    await cubit.load();
    await settings.load();

    expect(settings.state.languages.firstWhere((r) => r.isDefault).installing, isFalse);
    gate.complete();
  });

  test('a first-use download that fails clears the rows and wears its reason', () async {
    engine.installed.clear();
    engine.installSteps = [0.4];
    engine.failInstall = ModelInstallReason.offline;
    final cubit = build();
    final settings = settingsOver(cubit);
    await Future<void>.delayed(Duration.zero);

    await service.startRecording();
    await service.stopRecording();
    await pumpEventQueue();

    expect(rowOf(cubit, 'small').installing, isFalse);
    expect(rowOf(cubit, 'small').failure, ModelInstallReason.offline);
    expect(settings.state.languages.firstWhere((r) => r.isDefault).installing, isFalse);
  });

  test('a first-use download paints the model it fetches, not a choice made meanwhile', () async {
    engine.installed
      ..clear()
      ..add('large');
    engine.installSteps = [0.4];
    final gate = Completer<void>();
    engine.installGate = gate.future;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await service.startRecording();
    final stop = service.stopRecording();
    await pumpEventQueue();
    await cubit.selectModel('large');
    await pumpEventQueue();

    expect(rowOf(cubit, 'small').installFraction, 0.4);
    expect(rowOf(cubit, 'large').installing, isFalse);
    gate.complete();
    await stop;
    await pumpEventQueue();
    await cubit.load();

    expect(rowOf(cubit, 'small').installing, isFalse);
    expect(rowOf(cubit, 'small').installed, isTrue);
  });

  test('another pass starting its run leaves a painted download alone', () async {
    final cubit = build();
    await Future<void>.delayed(Duration.zero);
    await service.startRecording();
    final earlier = await service.stopRecording();
    engine.installed.clear();
    engine.installSteps = [0.4];
    final gate = Completer<void>();
    engine.installGate = gate.future;
    await service.startRecording();
    final stop = service.stopRecording();
    await pumpEventQueue();

    await service.retranscribe(earlier, using: FakeBatchEngine());
    await pumpEventQueue();

    expect(rowOf(cubit, 'small').installFraction, 0.4);
    gate.complete();
    await stop;
  });

  test('closing the cubit mid model install cancels the download', () async {
    engine.installed.clear();
    final gate = Completer<void>();
    engine.installGate = gate.future;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    gate.complete();
    await pumpEventQueue();

    expect(engine.installed, isNot(contains('large')));
  });

  test('a run whose model will not open lands that on the row while its file stays', () async {
    engine.failRun = const ModelInstallFailed('fake', null, ModelInstallReason.loadFailed);
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await service.startRecording();
    await service.stopRecording();
    await pumpEventQueue();
    await cubit.load();

    expect(rowOf(cubit, 'small').installed, isTrue);
    expect(rowOf(cubit, 'small').failure, ModelInstallReason.loadFailed);
  });

  test('a run that fails for its words leaves the model row alone', () async {
    engine.failRun = const TranscriptionFailed('fake');
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await service.startRecording();
    await service.stopRecording();
    await pumpEventQueue();

    expect(rowOf(cubit, 'small').failure, isNull);
    expect(rowOf(cubit, 'small').installing, isFalse);
  });

  test('a first-use download that fails before its first byte still names its model', () async {
    engine.installed.clear();
    engine.installSteps = const [];
    engine.failInstall = ModelInstallReason.offline;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await service.startRecording();
    await service.stopRecording();
    await pumpEventQueue();

    expect(rowOf(cubit, 'small').failure, ModelInstallReason.offline);
  });

  test('cancelling a model download clears its row and keeps nothing installed', () async {
    engine.installed.clear();
    final gate = Completer<void>();
    engine.installGate = gate.future;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await Future<void>.delayed(Duration.zero);
    expect(rowOf(cubit, 'large').installing, isTrue);
    await cubit.cancelModelInstallById('large');
    gate.complete();
    await pumpEventQueue();

    expect(rowOf(cubit, 'large').installing, isFalse);
    expect(rowOf(cubit, 'large').installed, isFalse);
    expect(rowOf(cubit, 'large').failure, isNull);
  });

  test('a picker-started download can be cancelled and a first-use one cannot', () async {
    engine.installed.clear();
    final gate = Completer<void>();
    engine.installGate = gate.future;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.installModelById('large');
    await Future<void>.delayed(Duration.zero);
    expect(rowOf(cubit, 'large').cancellable, isTrue);
    await cubit.cancelModelInstallById('large');
    engine.installSteps = [0.4];
    await service.startRecording();
    final stop = service.stopRecording();
    await pumpEventQueue();
    expect(rowOf(cubit, 'small').installing, isTrue);
    expect(rowOf(cubit, 'small').cancellable, isFalse);

    gate.complete();
    await stop;
  });

  group('modelTooHeavy', () {
    test('a model past three fifths of the phone is heavy', () {
      expect(modelTooHeavy(peakBytes: 61, physicalBytes: 100), isTrue);
      expect(modelTooHeavy(peakBytes: 60, physicalBytes: 100), isFalse);
    });

    test('an unknown phone memory dims nothing', () {
      expect(modelTooHeavy(peakBytes: 1 << 40, physicalBytes: null), isFalse);
    });
  });
}
