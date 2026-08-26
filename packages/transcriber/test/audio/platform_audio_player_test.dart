import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/audio/platform_audio_player.dart';
import 'package:transcriber/src/audio/playback.dart';

/// Pins the channel contract with AudioPlayer.swift: payload shapes, status
/// strings, error-code mapping, and the terminal-aware replay cache.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('transcriber/player');
  const stateEvents = EventChannel('transcriber/player/state');

  late PlatformAudioPlayer player;

  setUp(() {
    player = PlatformAudioPlayer();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(stateEvents, null);
  });

  test('play sends the path and maps a busy_recording refusal', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'play');
      expect((call.arguments as Map)['path'], '/audio/a.m4a');
      throw PlatformException(code: 'busy_recording', message: 'cannot play while recording');
    });

    await expectLater(
      player.play('/audio/a.m4a'),
      throwsA(
        isA<PlaybackException>().having((e) => e.code, 'code', PlaybackException.busyRecording),
      ),
    );
  });

  test('state decodes payloads, drops unknown statuses and junk', () async {
    messenger.setMockStreamHandler(
      stateEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.success({'status': 'playing', 'positionMs': 400, 'durationMs': 9000});
          sink.success({'status': 'warp', 'positionMs': 1, 'durationMs': 2});
          sink.success({'status': 'completed', 'positionMs': 9000, 'durationMs': 9000});
        },
      ),
    );

    final states = await player.state.take(2).toList();

    expect(states, const [
      PlaybackState(
        status: PlaybackStatus.playing,
        position: Duration(milliseconds: 400),
        duration: Duration(seconds: 9),
      ),
      PlaybackState(
        status: PlaybackStatus.completed,
        position: Duration(seconds: 9),
        duration: Duration(seconds: 9),
      ),
    ]);
  });

  test('a second listener gets the cached non-terminal state, never a terminal one', () async {
    var emitTerminal = false;
    messenger.setMockStreamHandler(
      stateEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          if (emitTerminal) {
            sink.success({'status': 'stopped', 'positionMs': 5, 'durationMs': 9});
          } else {
            sink.success({'status': 'paused', 'positionMs': 400, 'durationMs': 9000});
          }
        },
      ),
    );

    // Cache a mid-playback state via a held listener; a second listener replays it.
    final first = player.state.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    final replayed = await player.state.first.timeout(const Duration(seconds: 1));
    expect(replayed.status, PlaybackStatus.paused);
    await first.cancel();

    // A terminal state clears the cache: a fresh screen must not inherit an ending.
    // The second listener is held while the third attaches, so the third can only
    // receive a replay, and there must be none.
    emitTerminal = true;
    final second = player.state.listen((_) {});
    await Future<void>.delayed(Duration.zero); // live 'stopped' delivered, cache cleared
    var sawReplay = false;
    final third = player.state.listen((_) => sawReplay = true);
    await Future<void>.delayed(Duration.zero);
    expect(sawReplay, isFalse);
    await second.cancel();
    await third.cancel();
  });
}
