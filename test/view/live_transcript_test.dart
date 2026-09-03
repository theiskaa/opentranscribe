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

    test('glued words pack without a space and still break across lines', () {
      final words = ['あ', 'い', 'う', 'え', 'お'];
      final glued = [false, true, true, true, true];
      expect(packLines(words, widthOf, spaceWidth: 5, maxWidth: 22, glued: glued), [
        [0, 1],
        [2, 3],
        [4],
      ]);
      expect(packLines(words, widthOf, spaceWidth: 5, maxWidth: 22), [
        [0],
        [1],
        [2],
        [3],
        [4],
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

    test('a glue change alone diverges at the word whose glue changed', () {
      expect(
        firstDivergence(
          ['a', 'b', 'c'],
          ['a', 'b', 'c'],
          aGlued: [false, true, true],
          bGlued: [false, false, true],
        ),
        1,
      );
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

    test('a grown unspaced take re-packs its glued tail the same as from scratch', () {
      final before = transcriptWords('リアとコーヒー');
      final after = transcriptWords('リアとコーヒーを飲んだ。');
      final packed = packLines(
        before.words,
        widthOf,
        spaceWidth: 5,
        maxWidth: 35,
        glued: before.glued,
      );

      final result = repackFrom(
        packed,
        firstDivergence(before.words, after.words),
        after.words,
        widthOf,
        spaceWidth: 5,
        maxWidth: 35,
        glued: after.glued,
      );

      expect(
        result,
        packLines(after.words, widthOf, spaceWidth: 5, maxWidth: 35, glued: after.glued),
      );
      expect(result, [
        [0, 1, 2],
        [3, 4, 5],
        [6, 7, 8],
        [9, 10],
      ]);
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

    test('a space put between two characters re-packs like packing from scratch', () {
      final before = transcriptWords('你好嗎我很');
      final after = transcriptWords('你 好嗎我很');
      final previous = packLines(
        before.words,
        widthOf,
        spaceWidth: 5,
        maxWidth: 30,
        glued: before.glued,
      );

      final result = packIncrementally(
        after.words,
        widthOf,
        spaceWidth: 5,
        maxWidth: 30,
        previousWords: before.words,
        previous: previous,
        previousMaxWidth: 30,
        glued: after.glued,
        previousGlued: before.glued,
      );

      expect(
        result,
        packLines(after.words, widthOf, spaceWidth: 5, maxWidth: 30, glued: after.glued),
      );
      expect(result, isNot(equals(previous)));
    });

    test('a grown unspaced take keeps its settled lines and glues the new ones', () {
      final before = transcriptWords('リアとコー');
      final after = transcriptWords('リアとコーヒー');
      final previous = packLines(
        before.words,
        widthOf,
        spaceWidth: 5,
        maxWidth: 35,
        glued: before.glued,
      );

      final result = packIncrementally(
        after.words,
        widthOf,
        spaceWidth: 5,
        maxWidth: 35,
        previousWords: before.words,
        previous: previous,
        previousMaxWidth: 35,
        glued: after.glued,
        previousGlued: before.glued,
      );

      expect(result, [
        [0, 1, 2],
        [3, 4, 5],
        [6],
      ]);
      expect(identical(result.first, previous.first), isTrue);
    });
  });

  group('transcriptWords', () {
    test('spaced text is one word per run, none glued to the last', () {
      final (:words, :glued) = transcriptWords('Met  Lia for coffee.');
      expect(words, ['Met', 'Lia', 'for', 'coffee.']);
      expect(glued, everyElement(isFalse));
    });

    test('a script without spaces is one word per character, each glued to the last', () {
      final (:words, :glued) = transcriptWords('リアとコーヒー');
      expect(words, ['リ', 'ア', 'と', 'コ', 'ー', 'ヒ', 'ー']);
      expect(glued, [false, true, true, true, true, true, true]);
    });

    test('closing punctuation rides with the character before it', () {
      final (:words, :glued) = transcriptWords('喝了。然后、回家！');
      expect(words, ['喝', '了。', '然', '后、', '回', '家！']);
      expect(glued.first, isFalse);
      expect(glued.skip(1), everyElement(isTrue));
    });

    test('a spaced run inside an unspaced sentence keeps the spaces around it', () {
      final (:words, :glued) = transcriptWords('和 Lia 喝。');
      expect(words, ['和', 'Lia', '喝。']);
      expect(glued, [false, false, false]);
    });

    test('nothing but whitespace is no words', () {
      expect(transcriptWords('').words, isEmpty);
      expect(transcriptWords('  \n ').words, isEmpty);
    });
  });
}
