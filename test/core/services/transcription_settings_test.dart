import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  late LocalService storage;
  late TranscriptionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
    service = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(),
      store: EntryStore(storage),
    );
  });

  tearDown(() => service.dispose());

  TranscriptionSettings build({String deviceTag = 'de-DE'}) =>
      TranscriptionSettings(storage: storage, service: service, deviceTag: () => deviceTag);

  test('defaults to the device locale so speech works with no setting touched', () {
    final settings = build();

    expect(settings.localeId, 'de-DE');

    settings.apply();
    expect(service.localeId, 'de-DE');
  });

  test('a stored choice wins over the device locale', () async {
    await build().setLocaleId('az-AZ');

    // A fresh instance reading the same storage sees the choice, not the device.
    final reloaded = build();
    expect(reloaded.localeId, 'az-AZ');
    reloaded.apply();
    expect(service.localeId, 'az-AZ');
  });

  test('an undecryptable stored value falls back to the device locale', () async {
    await build().setLocaleId('az-AZ');
    // Reopen the same prefs under a different key: the stored tag no longer
    // decrypts, and the getter must fall back rather than throw.
    final other = LocalService();
    await other.init(encryptionKey: 'a-completely-different-key-000000');
    final settings = TranscriptionSettings(
      storage: other,
      service: service,
      deviceTag: () => 'de-DE',
    );

    expect(settings.localeId, 'de-DE');
  });

  test('setLocaleId persists and pushes immediately', () async {
    final settings = build();

    await settings.setLocaleId('en-GB');

    expect(settings.localeId, 'en-GB');
    expect(service.localeId, 'en-GB');
  });
}
