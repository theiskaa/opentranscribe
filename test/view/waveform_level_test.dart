import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/layouts/recorder/components/waveform.dart';

void main() {
  group('waveformLevel', () {
    // The native level carries -60dB..0dB as 0..1, so a raw value IS a dB
    // reading: 0.20 is -48dB, 0.85 is -9dB.
    double raw(double db) => (db + 60) / 60;

    test('room tone rests at nothing', () {
      expect(waveformLevel(raw(-60)), 0);
      expect(waveformLevel(raw(-50)), 0);
      expect(waveformLevel(raw(-48)), 0);
    });

    test('anything past the ceiling fills the band without clipping past it', () {
      expect(waveformLevel(raw(-9)), 1);
      expect(waveformLevel(raw(0)), 1);
    });

    test('ordinary speech lands in the upper half of the band', () {
      // -30dB to -15dB is a phone held at a normal talking distance.
      expect(waveformLevel(raw(-30)), greaterThan(0.5));
      expect(waveformLevel(raw(-15)), greaterThan(0.8));
      expect(waveformLevel(raw(-15)), lessThan(1));
    });

    test('a quiet voice still moves the band', () {
      expect(waveformLevel(raw(-42)), greaterThan(0));
      expect(waveformLevel(raw(-42)), lessThan(0.5));
    });

    test('the curve never doubles back', () {
      var previous = -1.0;
      for (var db = -60.0; db <= 0; db += 1) {
        final level = waveformLevel(raw(db));
        expect(level, greaterThanOrEqualTo(previous));
        expect(level, inInclusiveRange(0, 1));
        previous = level;
      }
    });
  });
}
