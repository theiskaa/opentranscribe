import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

/// The per-language model-management surface of the service: pass-throughs to a
/// managed engine, honest answers for an unmanaged one, and the
/// [TranscriptionService.modelStateChanged] signal state layers depend on.
void main() {
  const key = 'test-encryption-key-0123456789ab';
  final fixedClock = DateTime.utc(2026, 3, 4, 12);

  late LocalService storage;
  late EntryStore store;
  var idCounter = 0;

  TranscriptionService build(TranscriptionEngine engine) {
    idCounter = 0;
    return TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: engine,
      store: store,
      clock: () => fixedClock,
      idGenerator: () => 'id-${idCounter++}',
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
    store = EntryStore(storage);
  });

  group('pass-throughs to a managed engine', () {
    test('installedLocales and localeStatus reflect the engine state', () async {
      final engine = FakeManagedEngine(supportedLocaleTags: ['en-US', 'ru-RU']);
      final svc = build(engine);

      expect(await svc.installedLocales(), isEmpty);
      expect((await svc.localeStatus('en-US')).status, ModelAssetStatus.supported);
      expect((await svc.localeStatus('fr-FR')).status, ModelAssetStatus.unsupported);

      engine.installed = true;
      expect(await svc.installedLocales(), ['en-US', 'ru-RU']);
      final status = await svc.localeStatus('en-US');
      expect(status.status, ModelAssetStatus.installed);
      expect(status.isReady, isTrue);

      await svc.dispose();
    });

    test('removeLanguage releases and reports, reservationInfo carries the cap', () async {
      final engine = FakeManagedEngine(installed: true);
      final svc = build(engine);

      expect((await svc.reservationInfo()).max, 3);
      expect((await svc.reservationInfo()).reservedTags, ['en-US']);

      expect(await svc.removeLanguage('en-US'), isTrue);
      expect(await svc.removeLanguage('en-US'), isFalse); // nothing left to release
      expect((await svc.reservationInfo()).reservedTags, isEmpty);

      await svc.dispose();
    });

    test('a full cap surfaces as ReservationCapReached from installModel', () async {
      final engine = FakeManagedEngine()..capReached = true;
      final svc = build(engine);

      await expectLater(
        svc.installModel(localeId: 'ru-RU').toList(),
        throwsA(
          isA<ReservationCapReached>().having((e) => e.reservedTags, 'reservedTags', ['en-US']),
        ),
      );

      await svc.dispose();
    });
  });

  group('an engine with no managed model', () {
    test('is ready for everything it supports, and only that', () async {
      final svc = build(FakeBatchEngine(supportedLocaleTags: ['en-US', 'de-DE']));

      expect(await svc.installedLocales(), ['en-US', 'de-DE']);
      final supported = await svc.localeStatus('de-DE');
      expect(supported.status, ModelAssetStatus.installed);
      expect(supported.reserved, isTrue);
      expect((await svc.localeStatus('fr-FR')).status, ModelAssetStatus.unsupported);

      expect(await svc.removeLanguage('en-US'), isFalse);
      expect((await svc.reservationInfo()).max, 0);

      await svc.dispose();
    });
  });

  group('modelStateChanged', () {
    test('fires on install done, remove, and a settled batch, not on failure', () async {
      final engine = FakeManagedEngine();
      final svc = build(engine);
      var changes = 0;
      final sub = svc.modelStateChanged.listen((_) => changes++);

      // A failed install changes nothing.
      engine.failInstall = true;
      await expectLater(svc.installModel().toList(), throwsA(isA<ModelInstallFailed>()));
      await Future<void>.delayed(Duration.zero);
      expect(changes, 0);

      // Install completing fires once.
      engine.failInstall = false;
      await svc.installModel().toList();
      await Future<void>.delayed(Duration.zero);
      expect(changes, 1);

      // Removal fires once; a removal that released nothing does not.
      await svc.removeLanguage('en-US');
      await svc.removeLanguage('en-US');
      await Future<void>.delayed(Duration.zero);
      expect(changes, 2);

      await sub.cancel();
      await svc.dispose();
    });

    test('fires after a recording settles its batch (first-use install path)', () async {
      final svc = build(FakeBatchEngine(cannedText: 'settled'));
      var changes = 0;
      final sub = svc.modelStateChanged.listen((_) => changes++);

      await svc.startRecording();
      final entry = await svc.stopRecording();
      await Future<void>.delayed(Duration.zero);

      expect(entry.transcript?.fullText, 'settled');
      expect(changes, 1);

      // A retranscribe settles a batch too.
      await svc.retranscribe(entry);
      await Future<void>.delayed(Duration.zero);
      expect(changes, 2);

      await sub.cancel();
      await svc.dispose();
    });
  });
}
