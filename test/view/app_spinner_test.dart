import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';

void main() {
  test('dotLift rests every dot at the loop start', () {
    for (var i = 0; i < 3; i++) {
      expect(dotLift(0, i), 0, reason: 'dot $i');
    }
  });

  test('dotLift rests every dot through the loop tail after the wave', () {
    for (final t in const [2 / 3, 0.8, 0.999]) {
      for (var i = 0; i < 3; i++) {
        expect(dotLift(t, i), 0, reason: 't=$t dot=$i');
      }
    }
  });

  test('dotLift peaks each dot at its staggered midpoint', () {
    expect(dotLift(1 / 6, 0), closeTo(66, 0.001));
    expect(dotLift(2 / 6, 1), closeTo(66, 0.001));
    expect(dotLift(3 / 6, 2), closeTo(66, 0.001));
  });

  test('dotLift never leaves the band between baseline and peak', () {
    for (var k = 0; k <= 200; k++) {
      final t = k / 200;
      for (var i = 0; i < 3; i++) {
        expect(dotLift(t, i), inInclusiveRange(0, 66), reason: 't=$t dot=$i');
      }
    }
  });

  test('dotLift lifts a dot for only the third of the loop that is its window', () {
    expect(dotLift(0, 0), 0);
    expect(dotLift(0.16, 0), greaterThan(0));
    expect(dotLift(1 / 3, 0), 0);
    expect(dotLift(0.5, 0), 0);
  });
}
