import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/widgets/invisible_ink.dart';

ByteData frame(int width, int height, Iterable<(int, int)> lit, {int alpha = 255}) {
  final data = ByteData(width * height * 4);
  for (final (x, y) in lit) {
    data.setUint8((y * width + x) * 4 + 3, alpha);
  }
  return data;
}

void main() {
  group('sampleInkPoints', () {
    test('a blank frame yields no sparks', () {
      final points = sampleInkPoints(frame(8, 8, const []), width: 8, height: 8, pixelRatio: 1);
      expect(points, isEmpty);
    });

    test('only ink strictly above alpha 50 becomes a spark, '
        'keeping faint anti-aliasing tails out', () {
      final data = frame(3, 1, const [(0, 0)], alpha: 50);
      data.setUint8((0 * 3 + 1) * 4 + 3, 51);
      data.setUint8((0 * 3 + 2) * 4 + 3, 255);
      final points = sampleInkPoints(data, width: 3, height: 1, pixelRatio: 1);
      expect(points, orderedEquals(const [1.0, 0.0, 2.0, 0.0]));
    });

    test('points come back in logical coordinates', () {
      final points = sampleInkPoints(
        frame(8, 8, const [(4, 6)]),
        width: 8,
        height: 8,
        pixelRatio: 2,
      );
      expect(points, orderedEquals(const [2.0, 3.0]));
    });

    test('the grid steps about one logical pixel, skipping ink between steps', () {
      final points = sampleInkPoints(
        frame(9, 3, const [(1, 0), (3, 0)]),
        width: 9,
        height: 3,
        pixelRatio: 3,
      );
      expect(points, orderedEquals(const [1.0, 0.0]));
    });

    test('a dense block is thinned to the cap with even coverage', () {
      final all = [
        for (var y = 0; y < 100; y++)
          for (var x = 0; x < 100; x++) (x, y),
      ];
      final points = sampleInkPoints(
        frame(100, 100, all),
        width: 100,
        height: 100,
        pixelRatio: 1,
        maxPoints: 100,
      );
      expect(points.length ~/ 2, lessThanOrEqualTo(100));
      expect(points[1], 0.0);
      expect(points[points.length - 1], 99.0);
    });

    test('a count exactly divisible by the stride keeps every strided point', () {
      final row = [for (var x = 0; x < 10; x++) (x, 0)];
      final points = sampleInkPoints(
        frame(10, 1, row),
        width: 10,
        height: 1,
        pixelRatio: 1,
        maxPoints: 5,
      );
      expect(points, orderedEquals(const [0.0, 0.0, 2.0, 0.0, 4.0, 0.0, 6.0, 0.0, 8.0, 0.0]));
    });

    test('a count under the cap is kept whole', () {
      final row = [for (var x = 0; x < 5; x++) (x, 0)];
      final points = sampleInkPoints(
        frame(5, 1, row),
        width: 5,
        height: 1,
        pixelRatio: 1,
        maxPoints: 5,
      );
      expect(points.length ~/ 2, 5);
    });
  });

  group('estimateInkLines', () {
    const width = 350.0;
    const fontSize = 17.0;

    int estimate(Duration audio, {List<int>? peaks, double w = width}) =>
        estimateInkLines(audio: audio, width: w, fontSize: fontSize, peaks: peaks);

    test('a longer recording wants more lines', () {
      expect(
        estimate(const Duration(seconds: 30)),
        greaterThan(estimate(const Duration(seconds: 10))),
      );
    });

    test('a mostly silent envelope shrinks the estimate', () {
      final silent = List.filled(200, 0);
      final loud = List.filled(200, 200);
      expect(
        estimate(const Duration(seconds: 30), peaks: silent),
        lessThan(estimate(const Duration(seconds: 30), peaks: loud)),
      );
    });

    test('a wider measure needs fewer lines', () {
      expect(
        estimate(const Duration(seconds: 30), w: 700),
        lessThan(estimate(const Duration(seconds: 30))),
      );
    });

    test('even no audio shows one line, and an hour does not scroll forever', () {
      expect(estimate(Duration.zero), 1);
      expect(estimate(const Duration(hours: 1)), estimate(const Duration(hours: 2)));
      expect(estimate(const Duration(hours: 1)), lessThan(20));
    });
  });

  group('placeholderInkPoints', () {
    const fontSize = 17.0;
    const lineHeight = 24.65;

    test('every point stays inside the block', () {
      final points = placeholderInkPoints(
        width: 300,
        lines: 3,
        fontSize: fontSize,
        lineHeight: lineHeight,
      );
      expect(points, isNotEmpty);
      for (var i = 0; i < points.length; i += 2) {
        expect(points[i], inInclusiveRange(0, 300));
        expect(points[i + 1], inInclusiveRange(0, 3 * lineHeight));
      }
    });

    test('more lines reach deeper down the block', () {
      double deepest(int lines) {
        final points = placeholderInkPoints(
          width: 300,
          lines: lines,
          fontSize: fontSize,
          lineHeight: lineHeight,
        );
        var max = 0.0;
        for (var i = 1; i < points.length; i += 2) {
          if (points[i] > max) max = points[i];
        }
        return max;
      }

      expect(deepest(6), greaterThan(deepest(2)));
    });

    test('the field is deterministic for a given block', () {
      final a = placeholderInkPoints(
        width: 300,
        lines: 4,
        fontSize: fontSize,
        lineHeight: lineHeight,
      );
      final b = placeholderInkPoints(
        width: 300,
        lines: 4,
        fontSize: fontSize,
        lineHeight: lineHeight,
      );
      expect(a, orderedEquals(b));
    });

    test('the cap holds for a dense block', () {
      final points = placeholderInkPoints(
        width: 300,
        lines: 8,
        fontSize: fontSize,
        lineHeight: lineHeight,
        maxPoints: 500,
      );
      expect(points.length ~/ 2, lessThanOrEqualTo(500));
    });
  });
}
