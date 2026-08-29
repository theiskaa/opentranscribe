import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/player_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_player.dart';
import '../../support/fake_audio_recorder.dart';

void main() {
  group('activeSegmentIndex', () {
    const segments = [
      TranscriptSegment(text: 'a', start: Duration(seconds: 1), end: Duration(seconds: 2)),
      TranscriptSegment(text: 'b', start: Duration(seconds: 3), end: Duration(seconds: 4)),
    ];

    test('inside a segment lights it', () {
      expect(activeSegmentIndex(segments, const Duration(milliseconds: 1500)), 0);
      expect(activeSegmentIndex(segments, const Duration(milliseconds: 3500)), 1);
    });

    test('a gap keeps the previous segment lit', () {
      expect(activeSegmentIndex(segments, const Duration(milliseconds: 2500)), 0);
    });

    test('before the first is null; after the last stays on the last', () {
      expect(activeSegmentIndex(segments, Duration.zero), isNull);
      expect(activeSegmentIndex(segments, const Duration(seconds: 9)), 1);
    });

    test('no segments is null', () {
      expect(activeSegmentIndex(const [], const Duration(seconds: 1)), isNull);
    });
  });

  group('PlayerCubit', () {
    late TranscriptionService service;
    late Entry entry;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalService();
      await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
      service = TranscriptionService(
        composer: FakeAudioComposer(),
        recorder: FakeAudioRecorder(recordingsDir: '/tmp/recordings'),
        engine: FakeBatchEngine(),
        store: EntryStore(storage),
      );
      entry = Entry(
        id: 'e1',
        createdAt: DateTime.utc(2026, 7, 23),
        audioPath: 'e1.m4a',
        duration: const Duration(seconds: 30),
      );
    });

    tearDown(() => service.dispose());

    test('toggle walks play, pause, resume, and replay after completion', () async {
      final player = FakeAudioPlayer();
      final cubit = PlayerCubit(player: player, service: service);

      await cubit.toggle(entry);
      // The bare filename resolves against the recorder's directory.
      expect(player.lastPath, '/tmp/recordings/e1.m4a');

      player.push(
        const PlaybackState(
          status: PlaybackStatus.playing,
          position: Duration.zero,
          duration: Duration(seconds: 30),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await cubit.toggle(entry);

      player.push(
        const PlaybackState(
          status: PlaybackStatus.paused,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 30),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await cubit.toggle(entry);

      player.push(
        const PlaybackState(
          status: PlaybackStatus.completed,
          position: Duration(seconds: 30),
          duration: Duration(seconds: 30),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await cubit.toggle(entry);

      expect(player.calls, ['play', 'pause', 'resume', 'play']);

      await cubit.close();
      await player.dispose();
    });

    test('state maps from the player stream', () async {
      final player = FakeAudioPlayer();
      final cubit = PlayerCubit(player: player, service: service);

      player.push(
        const PlaybackState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 3),
          duration: Duration(seconds: 30),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isPlaying, isTrue);
      expect(cubit.state.position, const Duration(seconds: 3));
      expect(cubit.state.duration, const Duration(seconds: 30));

      await cubit.close();
      await player.dispose();
    });

    test('seek clamps into the known duration', () async {
      final player = FakeAudioPlayer();
      final cubit = PlayerCubit(player: player, service: service);
      player.push(
        const PlaybackState(
          status: PlaybackStatus.playing,
          position: Duration.zero,
          duration: Duration(seconds: 10),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.seek(const Duration(seconds: -5));
      expect(player.lastSeek, Duration.zero);

      await cubit.seek(const Duration(minutes: 5));
      expect(player.lastSeek, const Duration(seconds: 10));

      await cubit.close();
      await player.dispose();
    });

    test('a stale paused status falls back to a fresh play on resume', () async {
      final player = FakeAudioPlayer(throwOnResume: true);
      final cubit = PlayerCubit(player: player, service: service);
      player.push(
        const PlaybackState(
          status: PlaybackStatus.paused,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 30),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.toggle(entry);

      // The no_playback refusal is the contract's "fall back to play" signal,
      // and the fresh play lands back where the pause left off: a player the
      // native side lost is still, to the person holding the phone, paused.
      expect(player.calls, ['resume', 'play', 'seek']);
      expect(player.lastSeek, const Duration(seconds: 5));
      expect(cubit.state.failed, isFalse);

      await cubit.close();
      await player.dispose();
    });

    test('a stream event clears the failed notice', () async {
      final player = FakeAudioPlayer(throwOnPlay: true);
      final cubit = PlayerCubit(player: player, service: service);

      await cubit.toggle(entry);
      expect(cubit.state.failed, isTrue);

      player.push(
        const PlaybackState(
          status: PlaybackStatus.playing,
          position: Duration.zero,
          duration: Duration(seconds: 30),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.failed, isFalse);

      await cubit.close();
      await player.dispose();
    });

    test('a play failure sets failed without throwing', () async {
      final player = FakeAudioPlayer(throwOnPlay: true);
      final cubit = PlayerCubit(player: player, service: service);

      await cubit.toggle(entry);

      expect(cubit.state.failed, isTrue);

      await cubit.close();
      await player.dispose();
    });

    test('stopAndDetach stops the player and the cubit closes cleanly', () async {
      final player = FakeAudioPlayer();
      final cubit = PlayerCubit(player: player, service: service);

      await cubit.stopAndDetach();
      expect(player.calls, contains('stop'));

      await cubit.close();
      await player.dispose();
    });
    test('the wave gets the file its own shape, read once', () async {
      final player = FakeAudioPlayer(peakShape: const [0.1, 0.8, 0.3]);
      final cubit = PlayerCubit(player: player, service: service);

      await cubit.loadPeaks(entry);
      expect(cubit.state.peaks, const [0.1, 0.8, 0.3]);
      expect(player.lastPath, '/tmp/recordings/e1.m4a');

      // A second screen-driven ask is free: a kept recording cannot change.
      await cubit.loadPeaks(entry);
      expect(player.calls.where((call) => call == 'peaks'), hasLength(1));

      await cubit.close();
    });

    test('persisted peaks serve instantly, dequantized, with no native read', () async {
      final player = FakeAudioPlayer(peakShape: const [0.9]);
      final cubit = PlayerCubit(player: player, service: service);

      await cubit.loadPeaks(entry.withPeaks(const [0, 128, 255]));

      expect(cubit.state.peaks, const [0, 128 / 255, 1]);
      expect(player.calls.where((call) => call == 'peaks'), isEmpty);

      await cubit.close();
    });

    test('a decode on an unshaped entry writes the shape back to the store', () async {
      final storage = LocalService();
      await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
      final store = EntryStore(storage);
      final svc = TranscriptionService(
        composer: FakeAudioComposer(),
        recorder: FakeAudioRecorder(recordingsDir: '/tmp/recordings'),
        engine: FakeBatchEngine(),
        store: store,
      );
      await store.save(entry);
      final player = FakeAudioPlayer(peakShape: const [0.5, 1.0]);
      final cubit = PlayerCubit(player: player, service: svc);

      await cubit.loadPeaks(entry);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.peaks, const [0.5, 1.0]);
      // Quantized onto the stored record: the next open decodes nothing.
      expect(store.read('e1')?.peaks, [128, 255]);

      await cubit.close();
      await svc.dispose();
    });

    test('an unreadable file leaves the wave flat and playback working', () async {
      final player = FakeAudioPlayer(throwOnPeaks: true);
      final cubit = PlayerCubit(player: player, service: service);

      await cubit.loadPeaks(entry);
      expect(cubit.state.peaks, isEmpty);
      expect(cubit.state.failed, isFalse, reason: 'the wave failed, not the player');

      await cubit.toggle(entry);
      expect(player.calls, contains('play'));

      await cubit.close();
    });

    test('a live snapshot keeps the shape it already read', () async {
      final player = FakeAudioPlayer(peakShape: const [0.4, 0.6]);
      final cubit = PlayerCubit(player: player, service: service);
      await cubit.loadPeaks(entry);

      player.push(
        const PlaybackState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 2),
          duration: Duration(seconds: 30),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.peaks, const [0.4, 0.6]);
      expect(cubit.state.position, const Duration(seconds: 2));

      await cubit.close();
    });
    test('scrubbing with nothing playing holds, and play picks it up', () async {
      final player = FakeAudioPlayer();
      final cubit = PlayerCubit(player: player, service: service);

      // Nothing is loaded, so the native seek moves nothing; the wave still has
      // to stay where it was put, and the choice has to survive into playback.
      await cubit.seek(const Duration(seconds: 12), duration: const Duration(seconds: 30));
      expect(cubit.state.position, const Duration(seconds: 12));

      await cubit.toggle(entry);
      expect(player.calls, ['seek', 'play', 'seek']);
      expect(player.lastSeek, const Duration(seconds: 12));

      await cubit.close();
      await player.dispose();
    });

    test('a finished take replays from the start, not from its end', () async {
      final player = FakeAudioPlayer();
      final cubit = PlayerCubit(player: player, service: service);
      player.push(
        const PlaybackState(
          status: PlaybackStatus.completed,
          position: Duration(seconds: 30),
          duration: Duration(seconds: 30),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.toggle(entry);
      expect(player.calls, ['play'], reason: 'resuming the end would play nothing');

      await cubit.close();
      await player.dispose();
    });

    test('the speed cycles and outlives a fresh play', () async {
      final player = FakeAudioPlayer();
      final cubit = PlayerCubit(player: player, service: service);

      await cubit.cycleRate();
      expect(cubit.state.rate, playbackRates[1]);
      expect(player.lastRate, playbackRates[1]);

      // Every play builds a new native player, which comes back at 1x.
      await cubit.toggle(entry);
      expect(player.calls.where((call) => call == 'setRate'), hasLength(2));

      // All the way round, back to normal.
      for (var i = 1; i < playbackRates.length; i++) {
        await cubit.cycleRate();
      }
      expect(cubit.state.rate, 1);

      await cubit.close();
      await player.dispose();
    });

    test('toggle on a transcript-only entry is a silent no-op', () async {
      // A stale tap (the entry lost its audio under an open screen) must not
      // reach the player or surface a failure notice.
      final player = FakeAudioPlayer();
      final cubit = PlayerCubit(player: player, service: service);
      final bare = Entry(
        id: 'b1',
        createdAt: DateTime.utc(2026, 7, 23),
        audioPath: null,
        duration: const Duration(seconds: 30),
      );

      await cubit.toggle(bare);

      expect(player.lastPath, isNull);
      expect(player.calls, isEmpty);
      expect(cubit.state.failed, isFalse);

      await cubit.close();
      await player.dispose();
    });

    test('stored peaks still paint the wave for a transcript-only entry', () async {
      // The discard captures peaks before deleting the file, exactly so this
      // path works: the wave renders from the record, never from disk.
      final player = FakeAudioPlayer();
      final cubit = PlayerCubit(player: player, service: service);
      final bare = Entry(
        id: 'b2',
        createdAt: DateTime.utc(2026, 7, 23),
        audioPath: null,
        duration: const Duration(seconds: 30),
        peaks: const [0, 128, 255],
      );

      await cubit.loadPeaks(bare);

      expect(cubit.state.peaks, [0, 128 / 255, 1.0]);
      expect(player.calls, isEmpty);

      await cubit.close();
      await player.dispose();
    });
  });

  test('rebind forgets the shape before the stop lands so a remounted wave reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final service = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(recordingsDir: '/tmp/recordings'),
      engine: FakeBatchEngine(),
      store: EntryStore(storage),
    );
    final player = FakeAudioPlayer();
    final cubit = PlayerCubit(player: player, service: service);
    await cubit.loadPeaks(
      Entry(
        id: 'e1',
        createdAt: DateTime.utc(2026, 7, 23),
        audioPath: 'e1.m4a',
        duration: const Duration(seconds: 30),
        peaks: const [255],
      ),
    );
    expect(cubit.state.peaks, isNotEmpty);

    final rebinding = cubit.rebind();
    expect(cubit.state.peaks, isEmpty);
    await rebinding;

    expect(player.calls, contains('stop'));
    await cubit.close();
    await service.dispose();
  });

  test('a rebind after a discard leaves the player able to play the new file', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final service = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(recordingsDir: '/tmp/recordings'),
      engine: FakeBatchEngine(),
      store: EntryStore(storage),
    );
    final player = FakeAudioPlayer();
    final cubit = PlayerCubit(player: player, service: service);
    final entry = Entry(
      id: 'e1',
      createdAt: DateTime.utc(2026, 7, 23),
      audioPath: 'e1.m4a',
      duration: const Duration(seconds: 30),
    );

    await cubit.rebind();
    await cubit.rebind();
    await cubit.toggle(entry);

    expect(player.calls, contains('play'));
    await cubit.close();
    await service.dispose();
  });

  test('prefixed peaks keep the old shape over the kept fraction and lie flat after', () {
    final kept = prefixedPeaks([1, 0.5, 0.25, 0.125], 0.5);

    expect(kept, [1, 0.25, 0.0, 0.0]);
    expect(prefixedPeaks(const [], 0.5), isEmpty);
    expect(prefixedPeaks([0.4, 0.6], 1), [0.4, 0.6]);
    expect(prefixedPeaks([0.4, 0.6], 0), [0.0, 0.0]);
  });

  test('a provisional shape waits a grace for the backfill, then reads the file itself', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    final service = TranscriptionService(
      composer: FakeAudioComposer(),
      recorder: FakeAudioRecorder(recordingsDir: '/tmp/recordings'),
      engine: FakeBatchEngine(),
      store: EntryStore(storage),
    );
    final player = FakeAudioPlayer();
    final cubit = PlayerCubit(player: player, service: service, provisionalGrace: Duration.zero);
    final entry = Entry(
      id: 'e1',
      createdAt: DateTime.utc(2026, 7, 23),
      audioPath: 'e1.m4a',
      duration: const Duration(seconds: 30),
      peaks: const [255, 255],
    );
    await cubit.loadPeaks(entry);
    await cubit.rebind(keep: 0.5);
    expect(cubit.state.provisional, isTrue);
    expect(cubit.state.peaks, [1.0, 0.0]);

    final grown = entry.withRecording('e2.m4a', const Duration(seconds: 60));
    final waiting = cubit.loadPeaks(grown);
    expect(player.calls, isNot(contains('peaks')));
    await waiting;

    expect(player.calls, contains('peaks'));
    expect(cubit.state.provisional, isFalse);
    await cubit.close();
    await service.dispose();
  });
}
