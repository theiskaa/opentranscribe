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
    await storage.init(legacyKey: key);
    service = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(supportedLocaleTags: ['en-US', 'de-DE', 'tr-TR']),
      store: EntryStore(storage),
    );
  });

  tearDown(() => service.dispose());

  TranscriptionSettings build({String deviceTag = 'de-DE'}) =>
      TranscriptionSettings(storage: storage, service: service, deviceTag: () => deviceTag);

  test('defaults to the device locale so speech works with no setting touched', () async {
    final settings = build();

    expect(settings.localeId, 'de-DE');

    await settings.apply();
    expect(service.localeId, 'de-DE');
  });

  test('a stored choice wins over the device locale', () async {
    await build().setLocaleId('az-AZ');

    // A fresh instance reading the same storage sees the choice, not the device.
    final reloaded = build();
    expect(reloaded.localeId, 'az-AZ');
    await reloaded.apply();
    expect(service.localeId, 'az-AZ');
  });

  test('a device region no model ships for resolves to the language, never fails it', () async {
    // The Turkish-phone-in-Georgia bug: tr-GE must transcribe as tr-TR.
    final settings = build(deviceTag: 'tr-GE');

    await settings.apply();

    expect(settings.localeId, 'tr-TR');
    expect(settings.deviceLocaleId, 'tr-TR');
    expect(settings.deviceLanguageUnsupported, isFalse);
    expect(service.localeId, 'tr-TR');
  });

  test('a device language with no model at all falls back to English, and says so', () async {
    final settings = build(deviceTag: 'ka-GE');

    await settings.apply();

    expect(settings.localeId, 'en-US');
    expect(settings.deviceLanguageUnsupported, isTrue);
  });

  test('without English the fallback is the engine\'s first language', () async {
    final bare = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(supportedLocaleTags: ['de-DE']),
      store: EntryStore(storage),
    );
    final settings = TranscriptionSettings(
      storage: storage,
      service: bare,
      deviceTag: () => 'ka-GE',
    );

    await settings.apply();

    expect(settings.localeId, 'de-DE');
    await bare.dispose();
  });

  test('an engine that answers no languages resolves nothing, keeping the raw tag', () async {
    final mute = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(supportedLocaleTags: []),
      store: EntryStore(storage),
    );
    final settings = TranscriptionSettings(
      storage: storage,
      service: mute,
      deviceTag: () => 'tr-GE',
    );

    await settings.apply();

    expect(settings.localeId, 'tr-GE');
    expect(settings.deviceLanguageUnsupported, isFalse);
    await mute.dispose();
  });

  test('a stored choice whose language lost support entirely is kept as chosen', () async {
    final settings = build(deviceTag: 'tr-GE');
    await settings.setLocaleId('az-AZ');

    await settings.apply();

    expect(settings.localeId, 'az-AZ');
    expect(service.localeId, 'az-AZ');
  });

  test('a stored raw regional tag migrates to its language\'s supported spelling', () async {
    // Pre-resolution builds could persist the raw device tag (tr-GE) through
    // the picker or a default reset; it must heal, not duplicate tr-TR.
    final settings = build(deviceTag: 'tr-GE');
    await settings.setLocaleId('tr-GE');

    await settings.apply();

    expect(settings.localeId, 'tr-TR');
    expect(service.localeId, 'tr-TR');
    // Persisted, not just resolved in memory: a fresh reader sees tr-TR.
    expect(build().localeId, 'tr-TR');
  });

  test('an undecryptable stored value falls back to the device locale', () async {
    // A record that cannot decrypt (a corrupt store, or a STORAGE_KEY changed
    // between builds): the getter must fall back rather than throw. Seeded
    // malformed so the decrypt throws deterministically - a wrong-key reopen
    // only sometimes fails PKCS7 padding, sometimes decrypts to garbage.
    SharedPreferences.setMockInitialValues({'transcribe.localeId': 'v2:corrupt'});
    final other = LocalService();
    await other.init(legacyKey: key);
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
