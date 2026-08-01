import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/dither.dart';

void main() {
  test('ditherBayer8 spreads all 64 thresholds evenly across one tile', () {
    final seen = <double>{};
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final v = ditherBayer8(x, y);
        expect(v, inInclusiveRange(0, 63 / 64));
        seen.add(v);
      }
    }
    expect(seen.length, 64);
  });

  test('ditherBayer8 tiles every 8 cells in both directions', () {
    expect(ditherBayer8(3, 5), ditherBayer8(11, 5));
    expect(ditherBayer8(3, 5), ditherBayer8(3, 13));
  });

  test('ditherHash is deterministic and stays inside [0, 1) either side of zero', () {
    expect(ditherHash(4, 9), ditherHash(4, 9));
    for (var i = -25; i < 25; i++) {
      final v = ditherHash(i * 1.7, i * 3.1);
      expect(v, inInclusiveRange(0, 1));
      expect(v, lessThan(1));
    }
  });

  test('ditherThreshold is deterministic and stays inside [0, 1)', () {
    expect(ditherThreshold(5, 11), ditherThreshold(5, 11));
    for (var row = 0; row < 16; row++) {
      for (var col = 0; col < 16; col++) {
        final v = ditherThreshold(col, row);
        expect(v, inInclusiveRange(0, 1));
        expect(v, lessThan(1));
      }
    }
  });

  test('ditherCoverAlpha covers everything at 0 and nothing at 1, whatever the cell', () {
    for (final threshold in [0.0, 0.3, 63 / 64]) {
      for (final spatial in [0.0, 0.5, 1.0]) {
        expect(ditherCoverAlpha(threshold: threshold, spatial: spatial, progress: 0), 1);
        expect(ditherCoverAlpha(threshold: threshold, spatial: spatial, progress: 1), 0);
      }
    }
  });

  test('a cell only ever fades as the sweep advances, never flickers back', () {
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final threshold = ditherThreshold(col, row);
        var last = 1.0;
        for (var p = 0.0; p <= 1.0; p += 0.02) {
          final alpha = ditherCoverAlpha(
            threshold: threshold,
            spatial: (col + row) / 14,
            progress: p,
          );
          expect(alpha, lessThanOrEqualTo(last), reason: 'cell ($col,$row) flickered at $p');
          last = alpha;
        }
      }
    }
  });

  test('the frontier reaches leading cells before trailing ones', () {
    final leading = ditherCoverAlpha(threshold: 0.5, spatial: 0.1, progress: 0.5);
    final trailing = ditherCoverAlpha(threshold: 0.5, spatial: 0.9, progress: 0.5);
    expect(leading, lessThan(trailing));
  });

  test('ditherNoise equals the corner hash at integers and stays bounded', () {
    expect(ditherNoise(2, 7), ditherHash(2, 7));
    expect(ditherNoise(-3, -8), ditherHash(-3, -8));
    for (var i = -25; i < 25; i++) {
      expect(ditherNoise(i * 0.37, i * 0.61), inInclusiveRange(0, 1));
    }
  });

  test('ditherNoise crosses integer seams without a jump', () {
    expect((ditherNoise(1.999, 4.5) - ditherNoise(2.001, 4.5)).abs(), lessThan(0.05));
    expect((ditherNoise(4.5, -0.001) - ditherNoise(4.5, 0.001)).abs(), lessThan(0.05));
  });

  test('ditherFbm stays under 0.9, so tone can never blanket the field', () {
    for (var i = -25; i < 25; i++) {
      final v = ditherFbm(i * 0.43, i * 0.29);
      expect(v, inInclusiveRange(0, 1));
      expect(v, lessThan(0.9));
    }
  });
}
