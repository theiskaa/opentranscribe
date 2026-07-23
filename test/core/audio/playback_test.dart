import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/audio/playback.dart';

void main() {
  test('idle is a stopped state at zero', () {
    expect(PlaybackState.idle.status, PlaybackStatus.stopped);
    expect(PlaybackState.idle.position, Duration.zero);
    expect(PlaybackState.idle.duration, Duration.zero);
  });

  test('equality is by value', () {
    const a = PlaybackState(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 1),
      duration: Duration(seconds: 10),
    );
    const b = PlaybackState(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 1),
      duration: Duration(seconds: 10),
    );
    const differsByPosition = PlaybackState(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 2),
      duration: Duration(seconds: 10),
    );
    const differsByStatus = PlaybackState(
      status: PlaybackStatus.paused,
      position: Duration(seconds: 1),
      duration: Duration(seconds: 10),
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(differsByPosition));
    expect(a, isNot(differsByStatus));
  });

  test('exception message shows in toString', () {
    expect(const PlaybackException().toString(), 'PlaybackException');
    expect(const PlaybackException('boom').toString(), 'PlaybackException: boom');
  });

  test('exception carries the native error code for branching', () {
    const busy = PlaybackException('cannot play while recording', 'busy_recording');

    expect(busy.code, 'busy_recording');
    expect(const PlaybackException('x').code, isNull);
  });
}
