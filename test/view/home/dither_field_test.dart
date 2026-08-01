import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/home/components/dither_field.dart';

void main() {
  test('ditherBayer8 spreads all 64 thresholds evenly across one tile', () {
    // Ordered dither works because every threshold in [0,1) appears exactly
    // once per tile; a duplicate would clump lit cells.
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
    // The painter's drift sends coordinates negative within seconds, so the
    // bound must hold there too.
    expect(ditherHash(4, 9), ditherHash(4, 9));
    for (var i = -25; i < 25; i++) {
      final v = ditherHash(i * 1.7, i * 3.1);
      expect(v, inInclusiveRange(0, 1));
      expect(v, lessThan(1));
    }
  });

  test('ditherNoise equals the corner hash at integers and stays bounded', () {
    expect(ditherNoise(2, 7), ditherHash(2, 7));
    expect(ditherNoise(-3, -8), ditherHash(-3, -8));
    for (var i = -25; i < 25; i++) {
      expect(ditherNoise(i * 0.37, i * 0.61), inInclusiveRange(0, 1));
    }
  });

  test('ditherNoise crosses integer seams without a jump', () {
    // The field drifts continuously; a seam at cell corners would read as a
    // scanline marching through the glow.
    expect((ditherNoise(1.999, 4.5) - ditherNoise(2.001, 4.5)).abs(), lessThan(0.05));
    expect((ditherNoise(4.5, -0.001) - ditherNoise(4.5, 0.001)).abs(), lessThan(0.05));
  });

  test('ditherFbm stays under 0.9, so tone can never blanket the field', () {
    // Three octaves at halving amplitude bound the sum at 0.875; the painter
    // relies on tone staying under the top thresholds.
    for (var i = -25; i < 25; i++) {
      final v = ditherFbm(i * 0.43, i * 0.29);
      expect(v, inInclusiveRange(0, 1));
      expect(v, lessThan(0.9));
    }
  });
}
