import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  late LocalService storage;
  late FakeAudioRecorder recorder;
  late FakeManagedEngine engine;
  late TranscriptionService service;
  late TranscriptionSettings transcription;
  late AudioStorageSettings audioStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    recorder = FakeAudioRecorder();
    engine = FakeManagedEngine(supportedLocaleTags: ['en-US', 'de-DE']);
    service = TranscriptionService(recorder: recorder, engine: engine, store: EntryStore(storage));
    transcription = TranscriptionSettings(
      storage: storage,
      service: service,
      deviceTag: () => 'en-US',
    );
    audioStorage = AudioStorageSettings(storage: storage, recorder: recorder);
  });

  tearDown(() => service.dispose());

  SettingsCubit build() =>
      SettingsCubit(service: service, transcription: transcription, audioStorage: audioStorage);

  test('load surfaces locale, supported tags, readiness, and backup state', () async {
    engine.installed = true;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.localeId, 'en-US');
    expect(cubit.state.supportedLocales, ['en-US', 'de-DE']);
    expect(cubit.state.modelInstalled, isTrue);
    expect(cubit.state.availability?.isAvailable, isTrue);
    expect(cubit.state.backupExcluded, isTrue);

    await cubit.close();
  });

  test('setLocale persists and refreshes per-locale readiness', () async {
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.setLocale('de-DE');

    expect(cubit.state.localeId, 'de-DE');
    // A fresh settings reader sees the persisted choice.
    final reread = TranscriptionSettings(
      storage: storage,
      service: service,
      deviceTag: () => 'en-US',
    );
    expect(reread.localeId, 'de-DE');

    await cubit.close();
  });

  test('install maps progress and lands installed', () async {
    engine.installSteps = [0.3, 0.7];
    final cubit = build();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.modelInstalled, isFalse);

    final fractions = <double?>[];
    final sub = cubit.stream.listen((s) => fractions.add(s.installProgress));
    cubit.install();
    // A second tap while installing is a no-op by the single-flight promise.
    cubit.install();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(fractions, containsAllInOrder([0.0, 0.3, 0.7, null]));
    expect(cubit.state.modelInstalled, isTrue);
    expect(cubit.state.installing, isFalse);

    await sub.cancel();
    await cubit.close();
  });

  test('a failed install surfaces installFailed and clears progress', () async {
    engine.failInstall = true;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    cubit.install();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.installFailed, isTrue);
    expect(cubit.state.installing, isFalse);

    await cubit.close();
  });

  test('setBackupExcluded round-trips through the storage setting', () async {
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    await cubit.setBackupExcluded(false);

    expect(cubit.state.backupExcluded, isFalse);
    expect(recorder.backupExcluded, isFalse);

    await cubit.close();
  });

  test('locale display names render natively and fall back to the tag', () {
    expect(localeDisplayName('en-US'), 'English (US)');
    expect(localeDisplayName('de-DE'), 'Deutsch (DE)');
    expect(localeDisplayName('yue'), '粵語');
    expect(localeDisplayName('xx-XX'), 'xx-XX');
  });
}
