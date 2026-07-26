import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
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
    expect(cubit.state.defaultLanguage?.isReady, isTrue);
    expect(cubit.state.defaultLanguage?.status, ModelAssetStatus.installed);
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
    expect(cubit.state.defaultLanguage?.isReady, isFalse);

    final fractions = <double?>[];
    final sub = cubit.stream.listen((s) => fractions.add(s.defaultLanguage?.installFraction));
    cubit.install();
    // A second tap while installing is a no-op by the single-flight promise.
    cubit.install();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(fractions, containsAllInOrder([0.0, 0.3, 0.7, null]));
    expect(cubit.state.defaultLanguage?.isReady, isTrue);
    expect(cubit.state.defaultLanguage?.installing, isFalse);

    await sub.cancel();
    await cubit.close();
  });

  test('a failed install surfaces installFailed and clears progress', () async {
    engine.failInstall = true;
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    cubit.install();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.defaultLanguage?.failure?.kind, LanguageFailureKind.installFailed);
    expect(cubit.state.defaultLanguage?.installing, isFalse);

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

  group('per-language rows', () {
    LanguageModelState row(SettingsCubit cubit, String tag) =>
        cubit.state.languages.firstWhere((r) => r.tag == tag);

    test('switching the default leaves other rows installed (the F1 regression)', () async {
      // The original bug: EN -> FR flipped the whole surface to "not
      // installed" because installed-ness was one bool for the default.
      final multi = FakeStreamingEngine(
        supportedLocaleTags: ['en-US', 'fr-FR'],
        installedLocaleTags: ['en-US'],
      );
      final multiService = TranscriptionService(
        recorder: FakeAudioRecorder(),
        engine: multi,
        store: EntryStore(storage),
      );
      final cubit = SettingsCubit(
        service: multiService,
        transcription: TranscriptionSettings(
          storage: storage,
          service: multiService,
          deviceTag: () => 'en-US',
        ),
        audioStorage: audioStorage,
      );
      await Future<void>.delayed(Duration.zero);
      expect(row(cubit, 'en-US').isReady, isTrue);

      await cubit.setLocale('fr-FR');

      expect(cubit.state.localeId, 'fr-FR');
      expect(row(cubit, 'en-US').isReady, isTrue, reason: 'EN stays installed');
      expect(row(cubit, 'fr-FR').status, ModelAssetStatus.supported);
      expect(row(cubit, 'fr-FR').isDefault, isTrue);
      expect(cubit.state.defaultLanguage?.isReady, isFalse, reason: 'the new default is not ready');

      await cubit.close();
      await multiService.dispose();
    });

    test('an install failure marks only its row and survives reloads until retry', () async {
      engine.failInstall = true;
      final cubit = build();
      await Future<void>.delayed(Duration.zero);

      cubit.install('de-DE');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(row(cubit, 'de-DE').failure?.kind, LanguageFailureKind.installFailed);
      expect(row(cubit, 'de-DE').installing, isFalse, reason: 'onError cleared the fraction');
      expect(row(cubit, 'en-US').failure, isNull, reason: 'only the failing row is marked');
      expect(cubit.state.languages, isNotEmpty, reason: 'onError re-ran load');

      // A reload keeps the standing failure; a retry clears it.
      await cubit.load();
      expect(row(cubit, 'de-DE').failure, isNotNull);
      engine.failInstall = false;
      cubit.install('de-DE');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(row(cubit, 'de-DE').failure, isNull);
      expect(row(cubit, 'de-DE').isReady, isTrue);

      await cubit.close();
    });

    test('a full cap surfaces as an eviction choice, not a retry', () async {
      engine.capReached = true;
      final cubit = build();
      await Future<void>.delayed(Duration.zero);

      cubit.install('de-DE');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final failure = row(cubit, 'de-DE').failure;
      expect(failure?.kind, LanguageFailureKind.capReached);
      expect(failure?.reservedTags, ['en-US', 'de-DE']);

      await cubit.close();
    });

    test('an in-flight fraction survives a load() rebuild', () async {
      final gate = Completer<void>();
      engine.installSteps = [0.4];
      // Hold the install open past its first fraction so a load() lands mid-flight.
      engine.installGate = gate.future;
      final cubit = build();
      await Future<void>.delayed(Duration.zero);

      cubit.install('en-US');
      await Future<void>.delayed(Duration.zero);
      expect(row(cubit, 'en-US').installFraction, 0.4);

      await cubit.load();
      expect(row(cubit, 'en-US').installFraction, 0.4, reason: 'rebuild kept the fraction');

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(row(cubit, 'en-US').isReady, isTrue);

      await cubit.close();
    });

    test('a standing failure clears when the language becomes ready elsewhere', () async {
      engine.failInstall = true;
      final cubit = build();
      await Future<void>.delayed(Duration.zero);
      cubit.install('en-US');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(row(cubit, 'en-US').failure, isNotNull);

      // A first-use install succeeds through the SERVICE (a transcription's
      // piggyback): the row must not keep wearing "download failed".
      engine.failInstall = false;
      await service.installModel().drain<void>();
      await Future<void>.delayed(Duration.zero);

      expect(row(cubit, 'en-US').isReady, isTrue);
      expect(row(cubit, 'en-US').failure, isNull);

      await cubit.close();
    });

    test('a removal that releases nothing never resets the default', () async {
      // Nothing installed: FakeManagedEngine.removeLanguage reports false.
      final cubit = build();
      await Future<void>.delayed(Duration.zero);
      await cubit.setLocale('de-DE');

      await cubit.remove('de-DE');

      expect(cubit.state.localeId, 'de-DE', reason: 'a no-op removal has no side effect');

      await cubit.close();
    });

    test('removing the default falls back to the device locale', () async {
      engine.installed = true;
      final cubit = build();
      await Future<void>.delayed(Duration.zero);
      await cubit.setLocale('de-DE');

      await cubit.remove('de-DE');

      expect(cubit.state.localeId, 'en-US', reason: 'device tag, never another language');
      expect(service.localeId, 'en-US', reason: 'the service default followed');

      await cubit.close();
    });

    test('a model change elsewhere (first-use install) refreshes this surface', () async {
      final cubit = build();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.defaultLanguage?.isReady, isFalse);

      // Installed OUTSIDE the cubit, as a transcription's first-use download
      // would: the modelStateChanged signal alone must update the rows.
      await service.installModel().drain<void>();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.defaultLanguage?.isReady, isTrue);
      expect(row(cubit, 'en-US').isReady, isTrue);

      await cubit.close();
    });
  });
}
