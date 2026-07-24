import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/layouts/home/components/strip_fold.dart';

void main() {
  const depth = 72.0;
  const contentTop = 190.0;

  group('stripFold', () {
    test('the strip is open at home, and stays open through a pull', () {
      expect(stripFold(0, depth), 0);
      expect(stripFold(-90, depth), 0);
    });

    test('it folds 1:1 with the scroll, over exactly its own height', () {
      expect(stripFold(18, depth), 0.25);
      expect(stripFold(36, depth), 0.5);
      expect(stripFold(72, depth), 1);
    });

    test('deeper in the journal it is simply gone', () {
      expect(stripFold(4000, depth), 1);
    });

    test('a bar with no bottom slot has nothing to fold', () {
      expect(stripFold(0, 0), 1);
    });
  });

  group('stripSettle', () {
    test('open and folded are both resting states', () {
      expect(stripSettle(0, depth), isNull);
      expect(stripSettle(-40, depth), isNull);
      expect(stripSettle(depth, depth), isNull);
      expect(stripSettle(900, depth), isNull);
    });

    test('a half fold finishes the nearer way', () {
      expect(stripSettle(1, depth), 0);
      expect(stripSettle(35, depth), 0);
      expect(stripSettle(37, depth), depth);
      expect(stripSettle(71, depth), depth);
    });

    test('the midpoint commits rather than stalling', () {
      expect(stripSettle(36, depth), depth);
    });
  });

  group('dayGlideOffset', () {
    test('the first day goes home, where the strip is open', () {
      // Its label rests ON the line at every offset through the fold, so the
      // fold itself is what picks between them.
      expect(dayGlideOffset(contentTop, contentTop, depth), 0);
    });

    test('a day below it parks on the folded line', () {
      // Label at 600: it has to travel 410 to reach the open line, plus the 72
      // the line itself gives up on the way.
      expect(dayGlideOffset(600, contentTop, depth), 482);
    });

    test('what it lands on IS the line it lands on', () {
      // The offset and the line it produces have to agree, or a navigated day
      // arrives and immediately hands the title to its neighbour.
      const start = 1100.0;
      final offset = dayGlideOffset(start, contentTop, depth);
      final line = contentTop - stripFold(offset, depth) * depth;
      expect(start - offset, closeTo(line, 1e-9));
    });
  });
}
