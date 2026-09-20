import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/batch_progress_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  late TranscriptionService service;
  late FakeModelChoiceEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    engine = FakeModelChoiceEngine(installed: {'small'}, progressSteps: const [0.5]);
    service = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(duration: const Duration(seconds: 5)),
      engine: engine,
      store: EntryStore(storage),
    );
  });

  tearDown(() => service.dispose());

  test('a take being saved shows under the take slot and leaves on its done', () async {
    final cubit = BatchProgressCubit(service: service);
    final seen = <BatchProgressState>[];
    final sub = cubit.stream.listen(seen.add);

    await service.startRecording();
    await service.stopRecording();
    await pumpEventQueue();

    expect(seen.map((s) => s.take?.fraction), [0.0, 0.5, null]);
    expect(seen.first.take?.step, BatchStep.transcribing);
    expect(cubit.state, const BatchProgressState());
    await sub.cancel();
    await cubit.close();
  });

  test('a re-transcription shows under its entry and nowhere else', () async {
    await service.startRecording();
    final entry = await service.stopRecording();
    final cubit = BatchProgressCubit(service: service);
    final seen = <BatchProgressState>[];
    final sub = cubit.stream.listen(seen.add);

    await service.retranscribe(entry);
    await pumpEventQueue();

    expect(seen.map((s) => s.forEntry(entry.id)?.fraction), [0.0, 0.5, null]);
    expect(seen.first.take, isNull);
    await sub.cancel();
    await cubit.close();
  });

  test('a pass with nothing to report still opens and closes the take', () async {
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final plain = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(duration: const Duration(seconds: 5)),
      engine: FakeBatchEngine(),
      store: EntryStore(storage),
    );
    final cubit = BatchProgressCubit(service: plain);
    final seen = <BatchProgressState>[];
    final sub = cubit.stream.listen(seen.add);

    await plain.startRecording();
    await plain.stopRecording();
    await pumpEventQueue();

    expect(seen.map((s) => s.take?.step), [BatchStep.transcribing, null]);
    await sub.cancel();
    await cubit.close();
    await plain.dispose();
  });
}
