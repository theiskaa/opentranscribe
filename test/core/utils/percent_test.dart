import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/utils/percent.dart';

void main() {
  test('a fraction reads as its rounded whole percent', () {
    expect(percentOf(0), 0);
    expect(percentOf(0.004), 0);
    expect(percentOf(0.425), 43);
    expect(percentOf(2 / 3), 67);
  });

  test('only a finished fraction reads 100, so nothing claims done early', () {
    expect(percentOf(0.995), 99);
    expect(percentOf(0.9999), 99);
    expect(percentOf(1), 100);
  });

  test('no fraction is read outside 0 to 100, and none at all as 0', () {
    expect(percentOf(null), 0);
    expect(percentOf(-0.2), 0);
    expect(percentOf(1.4), 100);
  });

  test('a bar fills to the whole percent its label reads, clamped and empty for no measure', () {
    expect(shownFraction(0.425), 0.43);
    expect(shownFraction(0.998), 0.99);
    expect(shownFraction(1.2), 1.0);
    expect(shownFraction(-0.3), 0.0);
    expect(shownFraction(null), 0.0);
  });
}
