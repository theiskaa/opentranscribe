import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/audio/fake_audio_activity.dart';

void main() {
  final audio = File('/recordings/otr-a.m4a');
  const second = Duration(seconds: 1);

  test('answers the voice inside the bounds asked, clipped to them', () async {
    final activity = FakeAudioActivity(
      ranges: [(start: second, end: second * 3), (start: second * 5, end: second * 8)],
    );

    expect(await activity.voiced(audio, start: second * 2, end: second * 6), [
      (start: second * 2, end: second * 3),
      (start: second * 5, end: second * 6),
    ]);
  });

  test('no bounds answers every range, and a question outside them answers none', () async {
    final activity = FakeAudioActivity(ranges: [(start: second, end: second * 3)]);

    expect(await activity.voiced(audio), [(start: second, end: second * 3)]);
    expect(await activity.voiced(audio, start: second * 4), isEmpty);
  });

  test('a fake that cannot tell answers null, and every question is recorded', () async {
    final activity = FakeAudioActivity(ranges: null);

    expect(await activity.voiced(audio, start: second), isNull);
    expect(activity.calls.single, (path: audio.path, start: second, end: null));
  });
}
