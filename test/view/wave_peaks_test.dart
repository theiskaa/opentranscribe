import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/layouts/entry/components/wave_player.dart';

void main() {
  group('resamplePeaks', () {
    test('a wave with no bars to draw is no wave', () {
      expect(resamplePeaks(const [0.5], 0), isEmpty);
      expect(resamplePeaks(const [0.5], -3), isEmpty);
    });

    test('an unread file draws flat, not empty', () {
      // The bars still exist before the read lands; they just sit on the floor,
      // which is what silence looks like anyway.
      expect(resamplePeaks(const [], 4), [0, 0, 0, 0]);
    });

    test('fitting fewer bars keeps the LOUDEST of each slice', () {
      // Averaging would hand back 0.3 and 0.55, flattening the take. The pair
      // then stretches across the full height: 0.5 is this wave's floor and 0.9
      // its ceiling, whatever the absolute levels were.
      expect(resamplePeaks(const [0.1, 0.5, 0.2, 0.4, 0.9, 0.3], 2), [0, 1]);
    });

    test('the shape is stretched between its own quietest and loudest', () {
      // A take recorded quietly and one recorded loudly have to read the same:
      // the wave says where the sound is, not how close the microphone was.
      for (final source in [
        const [0.1, 0.2, 0.3],
        const [0.5, 0.6, 0.7],
      ]) {
        final stretched = resamplePeaks(source, 3);
        expect(stretched.first, 0);
        expect(stretched[1], closeTo(0.5, 1e-9));
        expect(stretched.last, 1);
      }
    });

    test('an unvarying recording is left flat rather than divided by nothing', () {
      expect(resamplePeaks(const [0.4, 0.4, 0.4], 3), [0.4, 0.4, 0.4]);
    });

    test('every value is accounted for, so no peak is skipped', () {
      final source = [for (var i = 0; i < 97; i++) i / 96];
      // The loudest sample anywhere has to survive into some bar.
      expect(resamplePeaks(source, 8).last, 1.0);
      expect(resamplePeaks(source, 8), hasLength(8));
      expect(resamplePeaks(source, 8).first, 0.0);
    });

    test('asking for more bars than were read repeats, never invents', () {
      // 2 values over 5 bars: the shape coarsens, it does not gain detail. The
      // handover lands where the second value's slice actually begins.
      expect(resamplePeaks(const [0.2, 0.8], 5), [0, 0, 0, 1, 1]);
    });

    test('one value fills every bar it is asked for', () {
      // Nothing to stretch against, so it keeps its own level.
      expect(resamplePeaks(const [0.6], 3), [0.6, 0.6, 0.6]);
    });

    test('the count asked for is the count returned', () {
      for (final bars in [1, 7, 40, 400]) {
        expect(resamplePeaks(const [0.1, 0.9, 0.4], bars), hasLength(bars));
      }
    });
  });
}
