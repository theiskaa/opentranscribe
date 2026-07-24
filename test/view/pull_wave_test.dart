import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/layouts/home/components/pull_to_record.dart';

void main() {
  group('pullBarAlive', () {
    test('a bar still rising is left entirely to the drag', () {
      expect(pullBarAlive(0), 0);
      expect(pullBarAlive(0.5), 0);
      expect(pullBarAlive(0.6), 0);
    });

    test('the wave takes over as the bar rises, not once it has topped out', () {
      expect(pullBarAlive(0.8), greaterThan(0));
      expect(pullBarAlive(0.8), lessThan(1));
      expect(pullBarAlive(1), 1);
    });

    test('it only ever grows with the bar', () {
      var previous = -1.0;
      for (var step = 0; step <= 100; step++) {
        final alive = pullBarAlive(step / 100);
        expect(alive, greaterThanOrEqualTo(previous));
        previous = alive;
      }
    });
  });

  group('pullBarSwell', () {
    test('an unarmed hint is left exactly as the pull scrubbed it', () {
      for (var i = 0; i < 7; i++) {
        expect(pullBarSwell(i, 0, 0), 1);
        expect(pullBarSwell(i, math.pi, 0), 1);
      }
    });

    test('the swell only ever eats into a bar, never grows it', () {
      for (var i = 0; i < 7; i++) {
        for (var step = 0; step < 60; step++) {
          final swell = pullBarSwell(i, step / 60 * 2 * math.pi, 1);
          expect(swell, inInclusiveRange(0.55 - 1e-9, 1 + 1e-9));
        }
      }
    });

    test('neighbours are genuinely out of phase, so the wave travels', () {
      // If every bar moved together this would be a pulse, not a wave.
      final first = pullBarSwell(0, 0, 1);
      final second = pullBarSwell(1, 0, 1);
      expect((first - second).abs(), greaterThan(0.05));
    });

    test('a full period returns to where it started', () {
      for (var i = 0; i < 7; i++) {
        expect(pullBarSwell(i, 2 * math.pi, 1), closeTo(pullBarSwell(i, 0, 1), 1e-9));
      }
    });

    test('arming blends the wave in rather than switching it on', () {
      // Half armed is half way between untouched and the full swell.
      final full = pullBarSwell(2, 1.2, 1);
      final half = pullBarSwell(2, 1.2, 0.5);
      expect(half, closeTo((1 + full) / 2, 1e-9));
    });
  });
}
