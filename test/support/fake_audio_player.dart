import 'dart:async';

import 'package:opentranscribe/core/audio/audio_player.dart';
import 'package:opentranscribe/core/audio/playback.dart';

/// In-memory [AudioPlayer] for tests: records calls, lets a test push states,
/// and throws on demand.
class FakeAudioPlayer implements AudioPlayer {
  FakeAudioPlayer({
    this.throwOnPlay = false,
    this.throwOnResume = false,
    this.throwOnPeaks = false,
    this.peakShape = const [0.2, 0.9, 0.4, 0.7],
  });

  final bool throwOnPlay;
  final bool throwOnResume;
  final bool throwOnPeaks;

  /// What [peaks] answers with, whatever bucket count is asked for.
  final List<double> peakShape;

  final List<String> calls = [];
  String? lastPath;
  Duration? lastSeek;
  double? lastRate;

  final StreamController<PlaybackState> _state = StreamController<PlaybackState>.broadcast();

  /// Push a state as if the native side emitted it.
  void push(PlaybackState state) => _state.add(state);

  @override
  Stream<PlaybackState> get state => _state.stream;

  @override
  Future<void> play(String path) async {
    calls.add('play');
    if (throwOnPlay) throw const PlaybackException('busy', PlaybackException.busyRecording);
    lastPath = path;
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async {
    calls.add('resume');
    if (throwOnResume) throw const PlaybackException('nothing', PlaybackException.noPlayback);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek');
    lastSeek = position;
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> setRate(double rate) async {
    calls.add('setRate');
    lastRate = rate;
  }

  @override
  Future<List<double>> peaks(String path, {int buckets = 240}) async {
    calls.add('peaks');
    if (throwOnPeaks) throw const PlaybackException('unreadable');
    lastPath = path;
    return peakShape;
  }

  Future<void> dispose() => _state.close();
}
