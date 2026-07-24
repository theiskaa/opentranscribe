import 'package:flutter/services.dart';

import 'package:opentranscribe/core/audio/audio_player.dart';
import 'package:opentranscribe/core/audio/playback.dart';

// Channel identifiers. Must match AudioPlayer.swift.
const _controlChannel = 'opentranscribe/player';
const _stateChannel = 'opentranscribe/player/state';

/// The iOS-native [AudioPlayer]: an AVAudioPlayer reached over platform channels.
/// Control on a MethodChannel, playback state on an EventChannel. Channel failures
/// are mapped to [PlaybackException] so callers never see a raw PlatformException.
class PlatformAudioPlayer implements AudioPlayer {
  PlatformAudioPlayer({MethodChannel? methods, EventChannel? stateEvents})
    : _methods = methods ?? const MethodChannel(_controlChannel),
      _stateEvents = stateEvents ?? const EventChannel(_stateChannel) {
    // Build the shared pipeline once so listeners share a single native
    // subscription rather than clobbering each other's sink. Native replays its
    // cached state only on the 0->1 listener transition, so the Dart side caches
    // the last NON-terminal state and hands it to each additional listener; a
    // terminal state clears the cache (a fresh screen must not inherit a previous
    // playback's ending), mirroring the native lastPayload rule.
    final shared = _stateEvents
        .receiveBroadcastStream()
        .map((event) => _stateFrom(event as Map?))
        .where((state) => state != null)
        .cast<PlaybackState>()
        .map((state) {
          final terminal =
              state.status == PlaybackStatus.stopped || state.status == PlaybackStatus.completed;
          _lastState = terminal ? null : state;
          return state;
        });
    _state = Stream<PlaybackState>.multi((controller) {
      final last = _lastState;
      if (last != null) controller.add(last);
      final sub = shared.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  final MethodChannel _methods;
  final EventChannel _stateEvents;
  late final Stream<PlaybackState> _state;
  PlaybackState? _lastState;

  /// Reads in flight or already done, keyed by file and resolution.
  /// Insertion-ordered, which is what makes evicting the first entry evict the
  /// oldest.
  final Map<String, Future<List<double>>> _peaks = {};
  static const _peakCacheLimit = 16;

  @override
  Stream<PlaybackState> get state => _state;

  @override
  Future<void> play(String path) => _invoke('play', {'path': path});

  @override
  Future<void> pause() => _invoke('pause');

  @override
  Future<void> resume() => _invoke('resume');

  @override
  Future<void> seek(Duration position) => _invoke('seek', {'positionMs': position.inMilliseconds});

  @override
  Future<void> stop() => _invoke('stop');

  @override
  Future<void> setRate(double rate) => _invoke('setRate', {'rate': rate});

  /// A kept recording never changes once written, so its shape is worth holding.
  /// The FUTURE is cached, not the result: two screens asking for the same file
  /// before the first read lands would otherwise both decode it, and a decode is
  /// the most expensive thing this class does.
  @override
  Future<List<double>> peaks(String path, {int buckets = 240}) {
    final key = '$path#$buckets';
    final pending = _peaks[key];
    if (pending != null) return pending;
    final read = _read(path, buckets);
    if (_peaks.length >= _peakCacheLimit) _peaks.remove(_peaks.keys.first);
    _peaks[key] = read;
    // A failed read is not worth remembering: the file may be readable next
    // time (a transient decode failure, a file still settling on disk).
    read.onError<Object>((error, _) {
      _peaks.remove(key);
      throw error;
    });
    return read;
  }

  Future<List<double>> _read(String path, int buckets) async {
    try {
      final raw = await _methods.invokeMethod<List<Object?>>('peaks', {
        'path': path,
        'buckets': buckets,
      });
      return [for (final value in raw ?? const []) (value as num).toDouble()];
    } on PlatformException catch (e) {
      throw PlaybackException(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw PlaybackException(e.message);
    }
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _methods.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      throw PlaybackException(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw PlaybackException(e.message);
    }
  }

  PlaybackState? _stateFrom(Map? raw) {
    if (raw == null) return null;
    final map = raw.cast<String, dynamic>();
    final status = _statusFrom(map['status'] as String?);
    if (status == null) return null;
    return PlaybackState(
      status: status,
      position: Duration(milliseconds: (map['positionMs'] as num?)?.toInt() ?? 0),
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
    );
  }

  PlaybackStatus? _statusFrom(String? raw) => switch (raw) {
    'playing' => PlaybackStatus.playing,
    'paused' => PlaybackStatus.paused,
    'stopped' => PlaybackStatus.stopped,
    'completed' => PlaybackStatus.completed,
    _ => null,
  };
}
