import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/cache_cubit.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  final fixedClock = DateTime.utc(2026, 3, 4, 12);

  late LocalService storage;
  late EntryStore store;
  late Directory dir;
  late TranscriptionService service;

  Transcript canned(String text) => Transcript(
    fullText: text,
    segments: [
      TranscriptSegment(text: text, start: Duration.zero, end: const Duration(seconds: 1)),
    ],
    localeId: 'en-US',
    engineId: 'fake',
    createdAt: fixedClock,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
    store = EntryStore(storage);
    dir = await Directory.systemTemp.createTemp('otr-cache');
    service = TranscriptionService(
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      engine: FakeBatchEngine(),
      store: store,
    );
  });

  tearDown(() async {
    await service.dispose();
    await dir.delete(recursive: true);
  });

  Future<void> seed() async {
    File('${dir.path}/done.m4a').writeAsStringSync('audio'); // 5 bytes, transcribed
    File('${dir.path}/raw.m4a').writeAsStringSync('raw'); // 3 bytes, untranscribed
    await store.save(
      Entry(
        id: 'done',
        createdAt: fixedClock,
        audioPath: 'done.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('done'),
      ),
    );
    await store.save(
      Entry(
        id: 'raw',
        createdAt: fixedClock,
        audioPath: 'raw.m4a',
        duration: const Duration(seconds: 1),
      ),
    );
  }

  test('measures usage on construction', () async {
    await seed();
    final cubit = CacheCubit(service: service);
    await pumpEventQueue();

    expect(cubit.state.usage, isNotNull);
    expect(cubit.state.usage!.totalBytes, 8);
    expect(cubit.state.usage!.totalCount, 2);
    expect(cubit.state.usage!.reclaimableBytes, 5);
    expect(cubit.state.usage!.reclaimableCount, 1);

    await cubit.close();
  });

  test('clear purges transcribed audio and re-measures in place', () async {
    await seed();
    final cubit = CacheCubit(service: service);
    await pumpEventQueue();

    await cubit.clear();

    expect(File('${dir.path}/done.m4a').existsSync(), isFalse);
    // Untranscribed audio is the only copy of its words: untouched.
    expect(File('${dir.path}/raw.m4a').existsSync(), isTrue);
    expect(cubit.state.clearing, isFalse);
    expect(cubit.state.usage!.totalBytes, 3);
    expect(cubit.state.usage!.reclaimableCount, 0);

    await cubit.close();
  });

  test('a clear started while one runs is a quiet no-op', () async {
    await seed();
    final cubit = CacheCubit(service: service);
    await pumpEventQueue();
    // The state sequence, not just the end state: without the cubit's own
    // clearing guard the second call would emit a second clearing=true (the
    // service's single-flight would still keep the outcome right, so the end
    // state alone cannot pin this).
    final clearingEmits = <bool>[];
    final sub = cubit.stream.listen((s) => clearingEmits.add(s.clearing));

    await Future.wait([cubit.clear(), cubit.clear()]);

    expect(clearingEmits.where((c) => c), hasLength(1));
    expect(cubit.state.clearing, isFalse);
    expect(cubit.state.usage!.reclaimableCount, 0);

    await sub.cancel();
    await cubit.close();
  });

  test('a close during the first measure never emits after close', () async {
    await seed();
    final cubit = CacheCubit(service: service);
    await cubit.close(); // before the constructor's load resolves
    await pumpEventQueue();

    expect(cubit.state.usage, isNull);
  });
}
