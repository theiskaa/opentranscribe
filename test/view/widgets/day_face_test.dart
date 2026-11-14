import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/day_face.dart';

void main() {
  group('dayDotBottom (where a day strip draws its dot)', () {
    test('the dot sits midway between the number baseline and the cell bottom', () {
      final bottom = dayDotBottom(
        cell: 60,
        letterLine: 12 * 1.45,
        numberLine: 17 * 1.45,
        numberSize: 17,
        dot: 4,
      );
      expect(bottom, closeTo(5.128, 1e-3));
    });

    test(
      'a taller cell gives half its gain to the space under the words, and the dot rises by half of that',
      () {
        double at(double cell) =>
            dayDotBottom(cell: cell, letterLine: 17.4, numberLine: 24.65, numberSize: 17, dot: 4);
        expect(at(70) - at(60), closeTo(2.5, 1e-9));
      },
    );
  });
}
