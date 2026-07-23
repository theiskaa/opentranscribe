import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  final fixedClock = DateTime.utc(2026, 3, 4, 12);

  late EntryStore store;
  var idCounter = 0;

  /// Builds a service, letting each test provide the engine as a function of the
  /// recorder so a streaming engine can be wired to the recorder's stop signal.
  TranscriptionService build(
    TranscriptionEngine Function(FakeAudioRecorder) engine, {
    FakeAudioRecorder? recorder,
  }) {
    final rec = recorder ?? FakeAudioRecorder();
    idCounter = 0;
    return TranscriptionService(
      recorder: rec,
      engine: engine(rec),
      store: store,
      clock: () => fixedClock,
      idGenerator: () => 'id-${idCounter++}',
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(encryptionKey: key);
    store = EntryStore(storage);
  });

  test('streaming engine: live streams for UI, batch is the persisted transcript', () async {
    // Live text and batch text differ so the persisted transcript proves it is the
    // batch result, while the live events prove real-time streaming.
    final svc = build(
      (rec) => FakeStreamingEngine(
        cannedText: 'live partial words',
        batchText: 'settled batch transcript',
        stopSignal: rec.stopped,
      ),
    );
    final events = <String>[];
    final sub = svc.liveEvents.listen((e) => events.add(e.text));

    await svc.startRecording();
    expect(svc.isRecording, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final entry = await svc.stopRecording();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(entry.transcript?.fullText, 'settled batch transcript');
    expect(entry.transcript?.engineId, 'fake.streaming');
    expect(svc.isRecording, isFalse);
    expect(events, isNotEmpty);
    expect(store.read('id-0'), entry);

    await svc.dispose();
  });

  test('batch-only engine: kept file is transcribed on stop', () async {
    final svc = build((_) => FakeBatchEngine(cannedText: 'batch result'));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript?.fullText, 'batch result');
    expect(entry.transcript?.engineId, 'fake.batch');
    expect(entry.transcript?.segments, isNotEmpty);
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('live-stream error is surfaced but the batch transcript still persists', () async {
    final svc = build(
      (rec) => FakeStreamingEngine(
        cannedText: 'live words',
        batchText: 'safe transcript',
        stopSignal: rec.stopped,
        failLive: true,
      ),
    );
    Object? forwardedError;
    final sub = svc.liveEvents.listen((_) {}, onError: (Object e) => forwardedError = e);

    await svc.startRecording();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final entry = await svc.stopRecording();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(entry.transcript?.fullText, 'safe transcript');
    expect(forwardedError, isNotNull);
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('transcription failure keeps the recording untranscribed, not lost', () async {
    final svc = build((_) => FakeBatchEngine(failBatch: true));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    // The recording is saved with its audio; the transcript is null and can be
    // produced later by re-transcription.
    expect(entry.transcript, isNull);
    expect(entry.isTranscribed, isFalse);
    expect(entry.audioPath, '/tmp/fake-recording.m4a');
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('retranscribe replaces the transcript with another engine', () async {
    final svc = build(
      (rec) => FakeStreamingEngine(
        cannedText: 'first',
        batchText: 'first pass',
        stopSignal: rec.stopped,
      ),
    );

    await svc.startRecording();
    final original = await svc.stopRecording();
    expect(original.transcript?.fullText, 'first pass');

    final updated = await svc.retranscribe(
      original,
      using: FakeBatchEngine(cannedText: 'sharper pass'),
    );

    expect(updated.id, original.id);
    expect(updated.audioPath, original.audioPath);
    expect(updated.transcript?.fullText, 'sharper pass');
    expect(store.read(original.id)?.transcript?.fullText, 'sharper pass');

    await svc.dispose();
  });

  test('rejects an engine that is not on-device only', () {
    expect(
      () =>
          TranscriptionService(recorder: FakeAudioRecorder(), engine: _CloudEngine(), store: store),
      throwsArgumentError,
    );
  });

  test('startRecording twice throws', () async {
    final svc = build((rec) => FakeStreamingEngine(stopSignal: rec.stopped));

    await svc.startRecording();
    await expectLater(svc.startRecording, throwsStateError);

    await svc.stopRecording();
    await svc.dispose();
  });

  test('stopRecording without starting throws', () async {
    final svc = build((_) => FakeBatchEngine());

    await expectLater(svc.stopRecording, throwsStateError);

    await svc.dispose();
  });

  test('a non-taxonomy engine error still saves the recording untranscribed', () async {
    // A generic throw (not a TranscriptionException) must never orphan the audio.
    final svc = build((_) => FakeBatchEngine(throwGeneric: true));

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript, isNull);
    expect(store.read(entry.id), entry);

    await svc.dispose();
  });

  test('batch timeout keeps the recording untranscribed', () async {
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(duration: Duration.zero),
      engine: FakeBatchEngine(delay: const Duration(milliseconds: 200)),
      store: store,
      batchTimeout: const Duration(milliseconds: 10),
      clock: () => fixedClock,
      idGenerator: () => 'id-0',
    );

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.transcript, isNull);

    await svc.dispose();
  });

  test('startRecording throws PermissionDenied when the mic is denied', () async {
    final svc = build(
      (_) => FakeBatchEngine(),
      recorder: FakeAudioRecorder(permission: PermissionStatus.denied),
    );

    await expectLater(svc.startRecording, throwsA(isA<PermissionDenied>()));
    expect(svc.isRecording, isFalse);

    await svc.dispose();
  });

  test('deleteEntry removes the audio file and the record', () async {
    final svc = build((_) => FakeBatchEngine());
    final dir = await Directory.systemTemp.createTemp('otr-test');
    final file = File('${dir.path}/audio.m4a');
    await file.writeAsString('audio');
    final entry = Entry(
      id: 'e1',
      createdAt: fixedClock,
      audioPath: file.path,
      duration: const Duration(seconds: 3),
    );
    await store.save(entry);

    await svc.deleteEntry(entry);

    expect(file.existsSync(), isFalse);
    expect(store.read('e1'), isNull);

    await dir.delete(recursive: true);
    await svc.dispose();
  });

  test('deleteEntry removes the record even when the audio file is missing', () async {
    final svc = build((_) => FakeBatchEngine());
    final entry = Entry(
      id: 'e2',
      createdAt: fixedClock,
      audioPath: '/no/such/file.m4a',
      duration: Duration.zero,
    );
    await store.save(entry);

    await svc.deleteEntry(entry);

    expect(store.read('e2'), isNull);

    await svc.dispose();
  });

  test('retranscribe failure throws and leaves the old transcript intact', () async {
    final svc = build((rec) => FakeStreamingEngine(batchText: 'original', stopSignal: rec.stopped));
    await svc.startRecording();
    final entry = await svc.stopRecording();
    expect(entry.transcript?.fullText, 'original');

    await expectLater(
      svc.retranscribe(entry, using: FakeBatchEngine(failBatch: true)),
      throwsA(isA<TranscriptionFailed>()),
    );
    expect(store.read(entry.id)?.transcript?.fullText, 'original');

    await svc.dispose();
  });

  test('retranscribe rejects a non-on-device engine', () async {
    final svc = build((rec) => FakeStreamingEngine(stopSignal: rec.stopped));
    await svc.startRecording();
    final entry = await svc.stopRecording();

    await expectLater(svc.retranscribe(entry, using: _CloudEngine()), throwsArgumentError);

    await svc.dispose();
  });

  test('persists createdAt as UTC even from a local clock', () async {
    final localClock = DateTime(2026, 3, 4, 12);
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(),
      engine: FakeBatchEngine(clock: () => localClock),
      store: store,
      clock: () => localClock,
      idGenerator: () => 'id-0',
    );

    await svc.startRecording();
    final entry = await svc.stopRecording();

    expect(entry.createdAt.isUtc, isTrue);
    expect(entry.createdAt, localClock.toUtc());
    expect(entry.transcript?.createdAt.isUtc, isTrue);

    await svc.dispose();
  });
}

/// An engine that would route off-device. Used only to prove the service rejects it.
class _CloudEngine implements TranscriptionEngine {
  @override
  String get id => 'cloud';

  @override
  bool get onDeviceOnly => false;

  @override
  Future<Availability> checkAvailability({required String localeId}) async =>
      const Availability.available();

  @override
  Future<Transcript> transcribeFile(File audio, {required String localeId}) async =>
      throw UnimplementedError();
}
