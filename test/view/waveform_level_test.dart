import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/layouts/recorder/components/waveform.dart';

void main() {
  group('waveform history by width', () {
    int history(double width, {int samples = 256}) =>
        waveformHistoryCount(width: width, barWidth: 3, gap: 3, samples: samples);

    test('the cover and the inner poses show history at the same bar spacing', () {
      expect(history(302), 50);
      expect(history(353.5), 58);
      expect(history(364), 60);
      expect(history(589), 98);
    });

    test('resizing reveals older samples and narrowing returns to the same recent tail', () {
      final samples = List.generate(256, (index) => index);
      List<int> visible(double width) => samples.sublist(samples.length - history(width));
      final narrow = visible(302);
      final wide = visible(589);
      expect(wide.last, narrow.last);
      expect(wide.sublist(wide.length - narrow.length), narrow);
      expect(visible(302), narrow);
    });

    test('a fractional bar never adds another sample', () {
      expect(history(5.9), 0);
      expect(history(6), 1);
      expect(history(11.9), 1);
      expect(history(12), 2);
    });

    test('a zero width or empty history paints no bars', () {
      expect(history(0), 0);
      expect(history(589, samples: 0), 0);
    });

    test('the history never reads beyond the retained samples', () {
      expect(history(589, samples: 4), 4);
      expect(history(2000), 256);
    });
  });

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
