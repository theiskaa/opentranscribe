import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/layouts/home/components/day_glide.dart';

void main() {
  const contentTop = 190.0;

  group('dayGlideOffset', () {
    test('the first day goes home', () {
      // Its label rests ON the line at rest, so there is nothing to travel.
      expect(dayGlideOffset(contentTop, contentTop), 0);
    });

    test('a hair below the line still counts as home', () {
      expect(dayGlideOffset(contentTop + 0.4, contentTop), 0);
    });

    test('a day below it travels its own distance to the line', () {
      expect(dayGlideOffset(600, contentTop), 410);
    });
  });
}
