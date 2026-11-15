import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/app_loader.dart';

void main() {
  group('passLift (the word passing through the loader)', () {
    test('every bar stands between its dot and its full height', () {
      for (var u = 0.0; u < 1; u += 0.01) {
        for (var i = 0; i < passBars.length; i++) {
          expect(passLift(u, i), inInclusiveRange(0, 1));
        }
      }
    });

    test('the word travels left to right: each bar peaks after the one before it', () {
      double peakOf(int i) {
        var best = 0.0;
        var at = 0.0;
        for (var u = 0.0; u < 1; u += 0.001) {
          final lift = passLift(u, i);
          if (lift > best) {
            best = lift;
            at = u;
          }
        }
        return at;
      }

      final peaks = [for (var i = 0; i < passBars.length; i++) peakOf(i)];
      for (var i = 1; i < peaks.length; i++) {
        expect(peaks[i], greaterThan(peaks[i - 1]));
      }
    });

    test('each bar peaks where the spec puts the crest: bar i at (i + 1.5) / 8 of the loop', () {
      for (var i = 0; i < passBars.length; i++) {
        expect(passLift((i + 1.5) / 8, i), closeTo(1, 1e-9));
      }
    });

    test('the crest is a gaussian 0.7 bar wide', () {
      expect(passLift(0, 0), closeTo(math.exp(-2.25 / 0.98), 1e-12));
    });

    test('the loop closes on itself, so its last frame flows into its first', () {
      for (var i = 0; i < passBars.length; i++) {
        expect(passLift(0.9999, i), closeTo(passLift(0, i), 1e-3));
      }
    });

    test('part of every loop is a pause, with every bar resting as a dot', () {
      final paused = [
        for (var u = 0.0; u < 1; u += 0.01)
          if (List.generate(passBars.length, (i) => passLift(u, i)).every((l) => l < 0.05)) u,
      ];
      expect(paused, isNotEmpty);
    });

    test('at rest under Reduce Motion the word stands on the centre bar', () {
      final lifts = List.generate(passBars.length, (i) => passLift(passRestingLoop, i));
      expect(lifts[2], closeTo(1, 1e-9));
      expect(lifts[0], lessThan(lifts[1]));
      expect(lifts[4], lessThan(lifts[3]));
    });
  });

  group('passBreath (the Reduce Motion loader)', () {
    test('it opens at full ink', () {
      expect(passBreath(Duration.zero), closeTo(1, 1e-9));
    });

    test('it dims to 0.4 halfway through a breath and never below', () {
      expect(passBreath(const Duration(milliseconds: 1200)), closeTo(0.4, 1e-9));
      for (var ms = 0; ms < 2400; ms += 50) {
        expect(passBreath(Duration(milliseconds: ms)), inInclusiveRange(0.4 - 1e-9, 1 + 1e-9));
      }
    });
  });
}
