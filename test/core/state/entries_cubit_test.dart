import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  late TranscriptionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    service = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(),
      store: EntryStore(storage),
    );
  });

  tearDown(() => service.dispose());

  Future<EntriesCubit> seeded() async {
    await service.startRecording();
    await service.stopRecording();
    return EntriesCubit(service: service);
  }

  test('seeds from the service so a fresh cubit is never empty', () async {
    final cubit = await seeded();
    expect(cubit.state.entries, hasLength(1));
    await cubit.close();
  });

  test('rename updates the list and clears busy', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;

    await cubit.rename(entry, 'Morning pages');

    expect(cubit.state.entries.single.title, 'Morning pages');
    expect(cubit.state.busyId, isNull);
    expect(cubit.state.error, isNull);

    await cubit.close();
  });

  test('a rename failure surfaces on error and still refreshes', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    await service.deleteEntry(entry);

    await cubit.rename(entry, 'ghost');

    expect(cubit.state.error, isNotNull);
    expect(cubit.state.entries, isEmpty);
    expect(cubit.state.busyId, isNull);

    await cubit.close();
  });

  test('delete removes the entry from the list', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;

    await cubit.delete(entry);

    expect(cubit.state.entries, isEmpty);
    await cubit.close();
  });

  test('retranscribe swaps in the fresh transcript', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;

    await cubit.retranscribe(entry);

    expect(cubit.state.entries.single.isTranscribed, isTrue);
    await cubit.close();
  });

  test('a failure is pinned to its entry, invisible on any other', () async {
    final cubit = await seeded();
    final entry = cubit.state.entries.single;
    await service.deleteEntry(entry);

    await cubit.rename(entry, 'ghost');

    expect(cubit.state.error?.entryId, entry.id);
    expect(cubit.state.errorFor(entry.id), EntriesError.generic);
    expect(cubit.state.errorFor('someone-else'), isNull);

    cubit.clearError();
    expect(cubit.state.errorFor(entry.id), isNull);

    await cubit.close();
  });
}
