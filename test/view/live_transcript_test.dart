import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/layouts/recorder/components/live_transcript.dart';

void main() {
  group('tailLines', () {
    // Every character is 10 wide, a space is 5: line widths are arithmetic.
    double widthOf(String word) => word.length * 10;

    List<List<int>> pack(String text, double maxWidth, {int maxLines = 2}) =>
        tailLines(text.split(' '), widthOf, spaceWidth: 5, maxWidth: maxWidth, maxLines: maxLines);

    test('no words is no lines', () {
      expect(tailLines(const [], widthOf, spaceWidth: 5, maxWidth: 100, maxLines: 2), isEmpty);
    });

    test('everything on one line while it fits', () {
      // 'aa bb' = 20 + 5 + 20.
      expect(pack('aa bb', 100), [
        [0, 1],
      ]);
    });

    test('packs forward and keeps the last lines', () {
      // Width 50: 'aa bb' fills a line (45), 'cc' starts the next.
      expect(pack('aa bb cc dd', 50), [
        [0, 1],
        [2, 3],
      ]);
      // A fifth word rolls the first line off; what stays is the TAIL.
      expect(pack('aa bb cc dd ee', 50), [
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
      // One pixel narrower and every word is its own line, so the visible tail
      // is the last two.
      expect(pack('aa bb cc', 44), [
        [1],
        [2],
      ]);
    });

    test('the last word is always on the last line', () {
      // _LiveTranscript reads its watermark from this, so it has to hold.
      for (final width in [30.0, 45.0, 90.0, 300.0]) {
        final words = 'aa bb cc dd ee ff gg'.split(' ');
        final lines = tailLines(words, widthOf, spaceWidth: 5, maxWidth: width, maxLines: 2);
        expect(lines.last.last, words.length - 1);
      }
    });

    test('a word wider than the line still gets a line of its own', () {
      expect(pack('aa toolongforthisline bb', 50), [
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

    test('maxLines bounds the window', () {
      expect(pack('aa bb cc dd ee ff', 50, maxLines: 1), [
        [4, 5],
      ]);
    });
  });
}
