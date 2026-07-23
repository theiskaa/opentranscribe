import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  late LocalService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
  });

  test('defaults to excluded from backup and applies it', () async {
    final recorder = FakeAudioRecorder();
    final settings = AudioStorageSettings(storage: storage, recorder: recorder);

    expect(settings.backupExcluded, isTrue);

    await settings.apply();
    expect(recorder.backupExcluded, isTrue);
  });

  test('setExcluded persists and applies the preference', () async {
    final recorder = FakeAudioRecorder();
    final settings = AudioStorageSettings(storage: storage, recorder: recorder);

    await settings.setExcluded(false);

    expect(settings.backupExcluded, isFalse);
    expect(recorder.backupExcluded, isFalse);

    // Survives a fresh instance reading the same storage.
    final reloaded = AudioStorageSettings(storage: storage, recorder: FakeAudioRecorder());
    expect(reloaded.backupExcluded, isFalse);
  });

  test('an undecryptable stored value fails safe to excluded', () async {
    final recorder = FakeAudioRecorder();
    await AudioStorageSettings(storage: storage, recorder: recorder).setExcluded(false);
    // Reopen the same prefs under a different key: the stored value no longer
    // decrypts, and the getter must fail safe toward the one rule.
    final other = LocalService();
    await other.init(encryptionKey: 'a-completely-different-key-000000');
    final reopened = AudioStorageSettings(storage: other, recorder: recorder);

    expect(reopened.backupExcluded, isTrue);
  });

  test('apply swallows a native failure so startup is never blocked', () async {
    final recorder = FakeAudioRecorder(throwOnSetBackup: true);
    final settings = AudioStorageSettings(storage: storage, recorder: recorder);

    await settings.apply(); // must not throw

    expect(recorder.backupExcluded, isNull);
  });
}
