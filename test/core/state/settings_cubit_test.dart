import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

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
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    recorder = FakeAudioRecorder();
    engine = FakeManagedEngine(supportedLocaleTags: ['en-US', 'de-DE']);
    service = TranscriptionService(
      recorder: recorder,
      engine: engine,
      store: EntryStore(storage),
      composer: FakeAudioComposer(),
    );
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

  (SettingsCubit, TranscriptionService, _RefusingEngine) buildRefusing() {
    final refusing = _RefusingEngine();
    final scoped = TranscriptionService(
      recorder: recorder,
      engine: refusing,
      store: EntryStore(storage),
      composer: FakeAudioComposer(),
    );
    final cubit = SettingsCubit(
      service: scoped,
      transcription: TranscriptionSettings(
        storage: storage,
        service: scoped,
        deviceTag: () => 'en-US',
      ),
      audioStorage: audioStorage,
    );
    return (cubit, scoped, refusing);
  }

  test('a refusing engine leaves the rows as they were and never throws', () async {
    final (cubit, scoped, refusing) = buildRefusing();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.languages, isEmpty);

    refusing.refuse = false;
    await cubit.load();
    expect(cubit.state.languages, isNotEmpty);

    refusing.refuse = true;
    await cubit.load();
    expect(cubit.state.languages, isNotEmpty);

    await cubit.close();
    await scoped.dispose();
  });

  test('a refused load says so until the next one lands', () async {
    final (cubit, scoped, refusing) = buildRefusing();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.loadFailed, isTrue);
    expect(cubit.state.defaultLanguage, isNull);

    refusing.refuse = false;
    await cubit.load();
    expect(cubit.state.loadFailed, isFalse);

    await cubit.close();
    await scoped.dispose();
  });

  // A cubit over its own engine with [tags], its default derived from
  // [deviceTag] and resolved the way Deps.init does. Caller closes the cubit;
  // the service dies with the shared tearDown recorder.
  Future<(SettingsCubit, TranscriptionService)> buildResolved({
    required List<String> tags,
    required String deviceTag,
  }) async {
    final scopedService = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: recorder,
      engine: FakeManagedEngine(supportedLocaleTags: tags),
      store: EntryStore(storage),
    );
    final scopedTranscription = TranscriptionSettings(
      storage: storage,
      service: scopedService,
      deviceTag: () => deviceTag,
    );
    await scopedTranscription.apply();
    final cubit = SettingsCubit(
      service: scopedService,
      transcription: scopedTranscription,
      audioStorage: audioStorage,
    );
    await Future<void>.delayed(Duration.zero);
    return (cubit, scopedService);
  }

  test('a derived device tag the engine cannot run never becomes a row', () async {
    // The Turkish-phone-in-Georgia bug: tr-GE resolves to tr-TR before this
    // surface ever sees it, so no phantom unsupported row appears.
    final (cubit, scoped) = await buildResolved(tags: ['en-US', 'tr-TR'], deviceTag: 'tr-GE');

    expect(cubit.state.localeId, 'tr-TR');
    expect(cubit.state.defaultLanguage?.tag, 'tr-TR');
    expect([for (final row in cubit.state.languages) row.tag], isNot(contains('tr-GE')));
    expect(cubit.state.deviceLanguageUnsupported, isFalse);

    await cubit.close();
    await scoped.dispose();
  });

  test('a device language with no model at all raises the fallback notice', () async {
    final (cubit, scoped) = await buildResolved(tags: ['en-US', 'tr-TR'], deviceTag: 'ka-GE');

    expect(cubit.state.localeId, 'en-US');
    expect(cubit.state.deviceLanguageUnsupported, isTrue);

    await cubit.close();
    await scoped.dispose();
  });

  test('rows come major languages first, one order for every surface', () async {
    final (cubit, scoped) = await buildResolved(
      tags: ['ar-SA', 'da-DK', 'en-GB', 'en-US', 'tr-TR'],
      deviceTag: 'en-US',
    );

    expect(
      [for (final row in cubit.state.languages) row.tag],
      ['en-US', 'en-GB', 'ar-SA', 'tr-TR', 'da-DK'],
    );

    await cubit.close();
    await scoped.dispose();
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

  test('setKeepAudio round-trips through the storage setting', () async {
    final cubit = build();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.keepAudio, isTrue);

    await cubit.setKeepAudio(false);

    expect(cubit.state.keepAudio, isFalse);
    expect(audioStorage.keepAudio, isFalse);
    // Storage only: flipping keep-audio never touches the native layer.
    expect(recorder.backupExcluded, isNull);

    await cubit.close();
  });

  test('setKeepAudio reflects the tap immediately, then settles on the truth', () async {
    // Optimistic: a slow encrypted write must not spring the toggle back and
    // forward; the first emit lands before the write, the last from storage.
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    final pending = cubit.setKeepAudio(false);
    expect(cubit.state.keepAudio, isFalse);
    await pending;

    expect(cubit.state.keepAudio, isFalse);
    expect(audioStorage.keepAudio, isFalse);

    await cubit.close();
  });

  test('load surfaces a keepAudio choice persisted before this session', () async {
    await audioStorage.setKeepAudio(false);
    final cubit = build();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.keepAudio, isFalse);

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
        composer: FakeAudioComposer(),
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

    test('a refused removal marks the row and a successful retry clears it', () async {
      // Nothing installed: FakeManagedEngine.removeLanguage reports false.
      final cubit = build();
      await Future<void>.delayed(Duration.zero);

      await cubit.remove('de-DE');

      expect(row(cubit, 'de-DE').failure?.kind, LanguageFailureKind.removeFailed);
      expect(row(cubit, 'en-US').failure, isNull, reason: 'only the refused row is marked');

      // The failure survives reloads even once the row reads ready: a removal
      // failure lives on a ready row by nature, readiness must not clear it.
      engine.installed = true;
      await cubit.load();
      expect(row(cubit, 'de-DE').isReady, isTrue);
      expect(row(cubit, 'de-DE').failure?.kind, LanguageFailureKind.removeFailed);

      // A retry that actually releases clears the verdict.
      await cubit.remove('de-DE');
      expect(row(cubit, 'de-DE').failure, isNull);

      await cubit.close();
    });

    test('a removal in flight swallows the duplicate tap', () async {
      // The disc stays tappable while the round trip runs; the duplicate used
      // to find nothing left to release and stamp "couldn't remove" over a
      // removal that just succeeded.
      engine.installed = true;
      final cubit = build();
      await Future<void>.delayed(Duration.zero);

      final first = cubit.remove('de-DE');
      final second = cubit.remove('de-DE');

      expect(await second, isFalse);
      expect(await first, isTrue);
      expect(row(cubit, 'de-DE').failure, isNull);

      await cubit.close();
    });

    test('an install retry clears a standing removeFailed verdict', () async {
      final cubit = build();
      await Future<void>.delayed(Duration.zero);
      await cubit.remove('de-DE');
      expect(row(cubit, 'de-DE').failure?.kind, LanguageFailureKind.removeFailed);

      cubit.install('de-DE');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(row(cubit, 'de-DE').failure, isNull);
      expect(row(cubit, 'de-DE').isReady, isTrue);

      await cubit.close();
    });

    test('evictAndInstall frees the slot then retries the blocked language', () async {
      engine.installed = true;
      final cubit = build();
      await Future<void>.delayed(Duration.zero);

      await cubit.evictAndInstall('en-US', 'de-DE');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        row(cubit, 'de-DE').isReady,
        isTrue,
        reason: 'the blocked install ran after the evict',
      );
      expect(row(cubit, 'de-DE').failure, isNull);

      await cubit.close();
    });

    test('evictAndInstall skips the retry when nothing was released', () async {
      // Nothing installed: the eviction is refused, so the blocked language
      // must not start a download it has no slot for.
      final cubit = build();
      await Future<void>.delayed(Duration.zero);

      await cubit.evictAndInstall('en-US', 'de-DE');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(row(cubit, 'en-US').failure?.kind, LanguageFailureKind.removeFailed);
      expect(row(cubit, 'de-DE').installing, isFalse);
      expect(row(cubit, 'de-DE').isReady, isFalse);

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

  test('a load on a readiness-probing engine ends with honest rows', () async {
    final dictationService = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(),
      engine: FakeDictationEngine(
        availability: const Availability(AvailabilityStatus.onDeviceUnavailable),
        supportedLocaleTags: ['en-US', 'de-DE'],
      ),
      store: EntryStore(storage),
    );
    final cubit = SettingsCubit(
      service: dictationService,
      transcription: TranscriptionSettings(
        storage: storage,
        service: dictationService,
        deviceTag: () => 'en-US',
      ),
      audioStorage: audioStorage,
    );
    await pumpEventQueue();

    expect(
      cubit.state.languages.map((row) => row.status),
      everyElement(ModelAssetStatus.unsupported),
    );

    await cubit.close();
    await dictationService.dispose();
  });

  test('an engine switch drops the previous engine\'s failure stamps', () async {
    engine.failInstall = true;
    final cubit = build();
    await pumpEventQueue();
    cubit.install();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.defaultLanguage?.failure, isNotNull);

    service.useEngine(FakeDictationEngine(supportedLocaleTags: ['en-US', 'de-DE']));
    await pumpEventQueue();

    expect(cubit.state.languages.every((row) => row.failure == null), isTrue);

    await cubit.close();
  });

  test('an engine switch cancels the previous engine\'s install tracking', () async {
    final gate = Completer<void>();
    engine.installSteps = [0.3];
    engine.installGate = gate.future;
    final cubit = build();
    await pumpEventQueue();
    cubit.install();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.defaultLanguage?.installing, isTrue);

    service.useEngine(FakeDictationEngine(supportedLocaleTags: ['en-US', 'de-DE']));
    await pumpEventQueue();

    expect(cubit.state.languages.every((row) => row.installFraction == null), isTrue);

    gate.complete();
    await cubit.close();
  });

  test('removing the old default while a new pick is in storage keeps the pick', () async {
    engine.installed = true;
    final cubit = build();
    await pumpEventQueue();

    await transcription.setLocaleId('de-DE');
    expect(cubit.state.localeId, 'en-US');

    await cubit.remove('en-US');

    expect(transcription.localeId, 'de-DE');

    await cubit.close();
  });

  test('a degraded managed engine still reads as managing models', () async {
    final degraded = FakeStreamingEngine(maxReservedLocales: 0);
    final svc = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(),
      engine: degraded,
      store: EntryStore(storage),
    );
    final cubit = SettingsCubit(
      service: svc,
      transcription: TranscriptionSettings(
        storage: storage,
        service: svc,
        deviceTag: () => 'en-US',
      ),
      audioStorage: audioStorage,
    );
    await pumpEventQueue();

    expect(cubit.state.reservationMax, 0);
    expect(cubit.state.managesModels, isTrue);
    expect(cubit.state.engineId, 'fake.streaming');

    await cubit.close();
    await svc.dispose();
  });
}

class _RefusingEngine extends FakeManagedEngine {
  bool refuse = true;

  @override
  Future<List<String>> supportedLocales() async {
    if (refuse) throw StateError('channel refused');
    return super.supportedLocales();
  }
}
