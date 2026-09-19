import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/entry/components/append_ink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const style = TextStyle(fontSize: 16, height: 1.5, fontFamily: 'Ahem');

  test('the painted ink covers the paragraph the words will occupy', () async {
    final painted = await paintAppendedInk(
      base: 'aaaa',
      addition: 'bbbb bbbb bbbb bbbb bbbb bbbb',
      width: 200,
      style: style,
      textScaler: TextScaler.noScaling,
      pixelRatio: 2,
      color: const Color(0xFF000000),
    );

    expect(painted.size.width, lessThanOrEqualTo(200));
    expect(painted.size.height, greaterThan(24));
    expect(painted.top, 0);
    expect(painted.image.width, (painted.size.width * 2).ceil());
    expect(painted.image.height, (painted.size.height * 2).ceil());
    painted.image.dispose();
  });

  test("only the region from the addition's first line down is painted", () async {
    final painted = await paintAppendedInk(
      base: 'aaaa aaaa aaaa aaaa aaaa',
      addition: 'bb',
      width: 200,
      style: style,
      textScaler: TextScaler.noScaling,
      pixelRatio: 1,
      color: const Color(0xFF000000),
    );

    expect(painted.top, 48);
    expect(painted.size.height, 24);
    painted.image.dispose();
  });

  test('only the addition leaves ink; the base is painted transparent', () async {
    final painted = await paintAppendedInk(
      base: 'aaaa',
      addition: 'bb',
      width: 200,
      style: style,
      textScaler: TextScaler.noScaling,
      pixelRatio: 1,
      color: const Color(0xFF000000),
    );
    final data = (await painted.image.toByteData())!;
    int alpha(int x, int y) => data.getUint8((y * painted.image.width + x) * 4 + 3);

    expect(alpha(8, 12), 0);
    expect(alpha(16 * 5 + 8, 12), greaterThan(0));
    painted.image.dispose();
  });

  group('appendFillerWithin', () {
    final words = List.filled(20, 'bbbb').join(' ');

    String within(String base, String filler, int maxLines) => appendFillerWithin(
      base: base,
      filler: filler,
      width: 200,
      style: style,
      textScaler: TextScaler.noScaling,
      maxLines: maxLines,
    );

    test('filler that fits is kept whole', () {
      expect(within('aaaa', 'bb bb', 3), 'bb bb');
    });

    test('the line it shares with the entry\'s last words counts as its first', () {
      expect(within('aaaa', words, 2), 'bbbb bbbb bbbb');
    });

    test('with no words before it, it starts on a line of its own', () {
      expect(within('', words, 1), 'bbbb bbbb');
    });

    test('nothing to lay out, or no lines to lay it on, is empty', () {
      expect(within('aaaa', '  ', 3), '');
      expect(within('aaaa', words, 0), '');
    });

    test('an entry whose words fill their last line leaves the filler a fresh one', () {
      expect(within('aaaa aaaa aa', words, 1), 'bbbb bbbb');
    });
  });

  group('appendPending', () {
    final words = List.filled(200, 'bbbb').join(' ');

    String pending({int? characters = 400}) => appendPending(
      characters: characters,
      sample: words,
      base: 'aaaa',
      width: 200,
      screenHeight: 24.0 * 3,
      style: style,
      textScaler: TextScaler.noScaling,
    );

    test('the forecast is laid out, a screen of lines at most', () {
      expect(pending(), 'bbbb bbbb bbbb bbbb bbbb');
    });

    test('a short forecast is laid out whole', () {
      expect(pending(characters: 9), 'bbbb bbbb');
    });

    test('without a forecast there is nothing to ink', () {
      expect(pending(characters: null), '');
    });
  });

  group('screenLines', () {
    test('counts the lines of the style a screen holds, at the reader\'s scale', () {
      expect(screenLines(screenHeight: 240, style: style, textScaler: TextScaler.noScaling), 10);
      expect(
        screenLines(screenHeight: 240, style: style, textScaler: const TextScaler.linear(2)),
        5,
      );
    });

    test('a screen too short for a line still holds one', () {
      expect(screenLines(screenHeight: 4, style: style, textScaler: TextScaler.noScaling), 1);
    });
  });

  group('appendLanding', () {
    AppendLanding landing({
      bool grew = true,
      bool liveShown = false,
      bool inkShown = true,
      bool laidOut = true,
      bool reduceMotion = false,
      bool matches = false,
    }) => appendLanding(
      grew: grew,
      liveShown: liveShown,
      inkShown: inkShown,
      laidOut: laidOut,
      reduceMotion: reduceMotion,
      matches: matches,
    );

    test('ink already shaped like the landed words only dissolves', () {
      expect(landing(matches: true), AppendLanding.dissolve);
    });

    test('ink shaped like other words, or none painted, is reshaped first', () {
      expect(landing(), AppendLanding.reshape);
    });

    test('words that did not grow by a tail swap in at once', () {
      expect(landing(grew: false, matches: true), AppendLanding.swap);
    });

    test('with the ink never shown or never laid out there is nothing to fade', () {
      expect(landing(inkShown: false), AppendLanding.swap);
      expect(landing(laidOut: false), AppendLanding.swap);
    });

    test('words landing where the live words already stood swap in, with no ink to fade', () {
      expect(landing(liveShown: true, matches: true), AppendLanding.swap);
    });

    test('under Reduce Motion the words swap in', () {
      expect(landing(reduceMotion: true, matches: true), AppendLanding.swap);
    });
  });
}
