import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/layouts/recorder/components/live_transcript.dart';

void main() {
  // Every character is 10 wide, a space is 5: line widths are arithmetic.
  double widthOf(String word) => word.length * 10;

  group('packLines', () {
    List<List<int>> pack(String text, double maxWidth) =>
        packLines(text.split(' '), widthOf, spaceWidth: 5, maxWidth: maxWidth);

    test('no words is no lines', () {
      expect(packLines(const [], widthOf, spaceWidth: 5, maxWidth: 100), isEmpty);
    });

    test('everything on one line while it fits', () {
      // 'aa bb' = 20 + 5 + 20.
      expect(pack('aa bb', 100), [
        [0, 1],
      ]);
    });

    test('packs forward, keeping every line', () {
      // Width 50: 'aa bb' fills a line (45), 'cc' starts the next.
      expect(pack('aa bb cc dd', 50), [
        [0, 1],
        [2, 3],
      ]);
      // A fifth word opens a third line; nothing is dropped, the window
      // scrolls instead.
      expect(pack('aa bb cc dd ee', 50), [
        [0, 1],
        [2, 3],
        [4],
      ]);
    });

    test('a line that fits exactly is not broken', () {
      // 'aa bb' is exactly 45 wide: the break belongs after it, not before.
      expect(pack('aa bb cc', 45), [
        [0, 1],
        [2],
      ]);
      // One pixel narrower and every word is its own line.
      expect(pack('aa bb cc', 44), [
        [0],
        [1],
        [2],
      ]);
    });

    test('the last word is always on the last line', () {
      // _LiveTranscript reads its watermark from this, so it has to hold.
      for (final width in [30.0, 45.0, 90.0, 300.0]) {
        final words = 'aa bb cc dd ee ff gg'.split(' ');
        final lines = packLines(words, widthOf, spaceWidth: 5, maxWidth: width);
        expect(lines.last.last, words.length - 1);
      }
    });

    test('every word lands on exactly one line, in order', () {
      // The scroll indexes rows off this, so a lost or duplicated word would
      // put a hole in the take.
      final words = 'aa bbbb c dddddd ee f ggg'.split(' ');
      final flat = packLines(words, widthOf, spaceWidth: 5, maxWidth: 70).expand((l) => l);
      expect(flat, List.generate(words.length, (i) => i));
    });

    test('a word wider than the line still gets a line of its own', () {
      expect(pack('aa toolongforthisline bb', 50), [
        [0],
        [1],
        [2],
      ]);
    });

    test('breaks already decided do not move as words arrive', () {
      // The first line is settled at 'aa bb'; adding words only extends the
      // last line or starts a new one.
      expect(pack('aa bb cc', 50).first, [0, 1]);
      expect(pack('aa bb cc dd', 50).first, [0, 1]);
    });

    test('packing from a later word yields that tail with absolute indices', () {
      final words = 'aa bb cc dd'.split(' ');

      expect(packLines(words, widthOf, spaceWidth: 5, maxWidth: 50, first: 2), [
        [2, 3],
      ]);
    });
  });

  group('firstDivergence', () {
    test('an appended tail diverges at the old length', () {
      expect(firstDivergence(['a', 'b'], ['a', 'b', 'c']), 2);
      expect(firstDivergence(<String>[], ['a']), 0);
    });

    test('a revised word diverges where it changed', () {
      expect(firstDivergence(['a', 'b', 'c'], ['a', 'x', 'c']), 1);
    });

    test('identical lists report their shared length', () {
      expect(firstDivergence(['a', 'b'], ['a', 'b']), 2);
    });
  });

  group('repackFrom', () {
    List<List<int>> scratch(List<String> words, double maxWidth) =>
        packLines(words, widthOf, spaceWidth: 5, maxWidth: maxWidth);

    List<List<int>> repacked(List<String> before, List<String> after, double maxWidth) =>
        repackFrom(
          scratch(before, maxWidth),
          firstDivergence(before, after),
          after,
          widthOf,
          spaceWidth: 5,
          maxWidth: maxWidth,
        );

    test('an appended word packs the same as packing from scratch', () {
      final before = 'aa bb cc'.split(' ');
      final after = 'aa bb cc dd'.split(' ');

      expect(repacked(before, after, 50), scratch(after, 50));
    });

    test('a revision mid-take packs the same as packing from scratch', () {
      final before = 'aa bb cc dd ee'.split(' ');
      final after = 'aa bb xxxx dd ee'.split(' ');

      expect(repacked(before, after, 50), scratch(after, 50));
    });

    test('a narrowing revision rejoins the line its old width had split', () {
      final before = 'aa bb cccc'.split(' ');
      final after = 'aa bb c'.split(' ');

      expect(repacked(before, after, 65), scratch(after, 65));
      expect(repacked(before, after, 65), [
        [0, 1, 2],
      ]);
    });

    test('a shortened take packs the same as packing from scratch', () {
      final before = 'aa bb cc dd ee'.split(' ');
      final after = 'aa bb cc'.split(' ');

      expect(repacked(before, after, 50), scratch(after, 50));
    });

    test('lines before the change keep their identity', () {
      final before = 'aa bb cc dd'.split(' ');
      final after = 'aa bb cc dd ee'.split(' ');
      final packed = scratch(before, 50);

      final result = repackFrom(packed, before.length, after, widthOf, spaceWidth: 5, maxWidth: 50);

      expect(identical(result.first, packed.first), isTrue);
    });
  });

  group('packIncrementally', () {
    List<List<int>> incremental(
      List<String> previousWords,
      List<String> words,
      double maxWidth, {
      List<List<int>>? previous,
      double? previousMaxWidth,
    }) => packIncrementally(
      words,
      widthOf,
      spaceWidth: 5,
      maxWidth: maxWidth,
      previousWords: previousWords,
      previous: previous ?? packLines(previousWords, widthOf, spaceWidth: 5, maxWidth: maxWidth),
      previousMaxWidth: previousMaxWidth ?? maxWidth,
    );

    test('unchanged words hand back the previous packing by identity', () {
      final words = 'aa bb cc'.split(' ');
      final previous = packLines(words, widthOf, spaceWidth: 5, maxWidth: 50);

      final result = incremental(words, words, 50, previous: previous);

      expect(identical(result, previous), isTrue);
    });

    test('a width change re-packs everything', () {
      final words = 'aa bb cc dd'.split(' ');
      final atOldWidth = packLines(words, widthOf, spaceWidth: 5, maxWidth: 50);

      final result = incremental(words, words, 100, previous: atOldWidth, previousMaxWidth: 50);

      expect(result, packLines(words, widthOf, spaceWidth: 5, maxWidth: 100));
    });

    test('a grown take packs the same as packing from scratch', () {
      final before = 'aa bb cc'.split(' ');
      final after = 'aa bb cc dd ee'.split(' ');

      expect(
        incremental(before, after, 50),
        packLines(after, widthOf, spaceWidth: 5, maxWidth: 50),
      );
    });
  });
}
