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
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
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
    // The purge's own change signal may carry the final numbers; let it land.
    await pumpEventQueue();

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
    final clearingEmits = <bool>[];
    final sub = cubit.stream.listen((s) => clearingEmits.add(s.clearing));

    await Future.wait([cubit.clear(), cubit.clear()]);
    await pumpEventQueue();

    var rises = 0;
    var previous = false;
    for (final clearing in clearingEmits) {
      if (clearing && !previous) rises++;
      previous = clearing;
    }
    expect(rises, 1);
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

  test('a store change while the screen is open re-measures the numbers', () async {
    await seed();
    final cubit = CacheCubit(service: service);
    await pumpEventQueue();
    expect(cubit.state.usage!.reclaimableCount, 1);

    // An external actor reclaims audio behind the open screen; the change
    // signal re-measures without a navigation.
    await service.purgeTranscribedAudio();
    await cubit.stream
        .firstWhere((s) => s.usage != null && s.usage!.reclaimableCount == 0)
        .timeout(const Duration(seconds: 5));

    expect(cubit.state.usage!.reclaimableCount, 0);
    expect(cubit.state.usage!.totalBytes, 3);

    await cubit.close();
  });

  test('a failed re-measure after a clear leaves the screen usable', () async {
    final failing = _ToggleFailStore(storage);
    File('${dir.path}/done.m4a').writeAsStringSync('audio');
    final svc = TranscriptionService(
      recorder: FakeAudioRecorder(recordingsDir: dir.path),
      engine: FakeBatchEngine(),
      store: failing,
      // The purge itself succeeds; the store starts refusing reads right
      // after the delete, so only the re-measure fails.
      fileDeleter: (f) async {
        await f.delete();
        failing.failAll = true;
      },
    );
    await failing.save(
      Entry(
        id: 'f1',
        createdAt: fixedClock,
        audioPath: 'done.m4a',
        duration: const Duration(seconds: 1),
        transcript: canned('f'),
      ),
    );
    final cubit = CacheCubit(service: svc);
    await pumpEventQueue();

    await cubit.clear();

    // The flag resets and the stale numbers stand; nothing rejects the zone.
    expect(cubit.state.clearing, isFalse);
    expect(cubit.state.usage!.reclaimableCount, 1);

    failing.failAll = false;
    await cubit.load();
    expect(cubit.state.usage!.reclaimableCount, 0);

    await cubit.close();
    await svc.dispose();
  });
}

/// A store whose [all] can be switched to throw, modeling corrupt reads that
/// land between a purge and its re-measure.
class _ToggleFailStore extends EntryStore {
  _ToggleFailStore(super.storage);

  bool failAll = false;

  @override
  List<Entry> all() {
    if (failAll) throw StateError('store unreadable');
    return super.all();
  }
}
