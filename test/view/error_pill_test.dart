import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/widgets/error_pill.dart';

void main() {
  group('shakeOffset', () {
    test('rests at exactly zero on both ends', () {
      expect(shakeOffset(0, 5), 0);
      expect(shakeOffset(1, 5), 0);
    });

    test('never throws further than its travel', () {
      for (var t = 0.0; t <= 1.0; t += 0.01) {
        expect(shakeOffset(t, 5).abs(), lessThanOrEqualTo(5));
      }
    });

    test('oscillates: the throw changes sign along the way', () {
      final samples = [for (var t = 0.05; t < 1; t += 0.05) shakeOffset(t, 5)];
      expect(samples.any((v) => v > 0), isTrue);
      expect(samples.any((v) => v < 0), isTrue);
    });

    test('dies out: the last swing is smaller than the first', () {
      // Peaks of the damped sine sit near the quarter points of each cycle.
      expect(shakeOffset(11 / 12, 5).abs(), lessThan(shakeOffset(1 / 12, 5).abs()));
    });
  });
}
