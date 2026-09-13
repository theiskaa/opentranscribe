import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/language_seams.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  Duration ms(int value) => Duration(milliseconds: value);
  VoicedRange voice(int start, int end) => (start: ms(start), end: ms(end));

  group('seamWindow', () {
    test('reaches back further than ahead of the pick', () {
      final window = seamWindow(pick: ms(20000), previous: ms(4000), next: null, length: ms(60000));
      expect(window, (start: ms(12000), end: ms(23000)));
    });

    test('never crosses halfway to a neighboring pick', () {
      final window = seamWindow(
        pick: ms(6000),
        previous: ms(2000),
        next: ms(7000),
        length: ms(60000),
      );
      expect(window, (start: ms(4000), end: ms(6500)));
    });

    test('the first switch reaches back to the take\'s start, and none past its end', () {
      final window = seamWindow(pick: ms(3000), previous: null, next: null, length: ms(4000));
      expect(window, (start: Duration.zero, end: ms(4000)));
    });
  });

  group('seamCut', () {
    const window = (start: Duration(seconds: 6), end: Duration(seconds: 17));
    final take = [voice(800, 9500), voice(12040, 17000)];

    Duration cut(
      int pick, {
      List<VoicedRange>? voiced,
      TakeWindow w = window,
      int length = 30000,
    }) => seamCut(pick: ms(pick), voiced: voiced, window: w, length: ms(length));

    test('a pick in a pause cuts at the pause\'s middle', () {
      expect(cut(10800, voiced: take), ms(10770));
    });

    test('a pick a second before the pause moves forward to it', () {
      expect(cut(8500, voiced: take), ms(10770));
    });

    test('a pick two seconds into the next language moves back to the pause', () {
      expect(cut(14000, voiced: take), ms(10770));
    });

    test('a breath at the pick loses to the switch pause a little way off', () {
      final breath = [voice(6000, 9500), voice(12040, 13800), voice(14200, 17000)];
      expect(cut(14000, voiced: breath), ms(10770));
    });

    test('a pause far back never takes the old language\'s words to the new one', () {
      const wide = (start: Duration(seconds: 2), end: Duration(seconds: 13));
      final far = [voice(2000, 3000), voice(3400, 13000)];
      expect(cut(10000, voiced: far, w: wide), ms(10000));
    });

    test('the silence after the last word loses to the pause between the languages', () {
      const late = (start: Duration(milliseconds: 11500), end: Duration(seconds: 22));
      final tail = [voice(11500, 19000), voice(19400, 21000)];
      expect(cut(19500, voiced: tail, w: late, length: 22000), ms(19200));
    });

    test('a pick in the silence after the last word cuts in it', () {
      const end = (start: Duration(seconds: 2), end: Duration(seconds: 12));
      final spoken = [voice(2000, 5000), voice(5400, 9500)];
      expect(cut(10000, voiced: spoken, w: end, length: 12000), ms(10750));
    });

    test('the longer of two pauses in reach takes the cut, discounted by its distance', () {
      final sentences = [voice(6000, 9000), voice(9400, 12000), voice(14500, 17000)];
      expect(cut(10000, voiced: sentences), ms(13250));
    });

    test('a tie between the pick\'s own quiet and a pause goes to the nearer', () {
      final tie = [voice(6000, 10000), voice(10400, 11200), voice(11800, 17000)];
      expect(cut(10400, voiced: tie), ms(10200));
    });

    test(
      'a long thinking pause further back than a pause may sit leaves the cut at the pick\'s pause',
      () {
        const wide = (start: Duration(milliseconds: 3100), end: Duration(milliseconds: 14100));
        final thinking = [voice(0, 3000), voice(7000, 11000), voice(11400, 20000)];
        expect(cut(11100, voiced: thinking, w: wide), ms(11200));
      },
    );

    test(
      'a long silent lead-in within a pause\'s distance never takes the cut from a pause at the pick',
      () {
        const wide = (start: Duration(milliseconds: 3100), end: Duration(milliseconds: 14100));
        final leadIn = [voice(9000, 11000), voice(11300, 20000)];
        expect(cut(11100, voiced: leadIn, w: wide), ms(11150));
      },
    );

    test('with no pause in reach a word break within a second takes the cut', () {
      final words = [voice(6000, 9800), voice(9950, 17000)];
      expect(cut(10500, voiced: words), ms(9875));
      expect(cut(11200, voiced: words), ms(11200));
    });

    test('with no quiet to cut in, or a probe that could not tell, the pick stands', () {
      expect(cut(10500, voiced: [voice(6000, 17000)]), ms(10500));
      expect(cut(10500), ms(10500));
    });
  });

  group('walkSeam', () {
    const window = (start: Duration(seconds: 6), end: Duration(seconds: 17));

    Future<Duration> walk(
      int cut,
      List<VoicedRange> voiced,
      double? Function(TakeWindow stretch) odds, {
      TakeWindow w = window,
    }) => walkSeam(
      cut: ms(cut),
      voiced: voiced,
      window: w,
      newOdds: (stretch) async => odds(stretch),
    );

    double frenchFrom(TakeWindow stretch, int fromMs) => stretch.start >= ms(fromMs) ? 0.99 : 0.01;

    test(
      'a sentence said in the new language before the pick takes the cut back past it',
      () async {
        final take = [voice(800, 9500), voice(12040, 14000), voice(14500, 20000)];
        expect(await walk(14250, take, (s) => frenchFrom(s, 12000)), ms(10770));
      },
    );

    test('a sentence finished in the old language after the pick takes the cut past it', () async {
      const early = (start: Duration.zero, end: Duration(seconds: 11));
      final take = [voice(0, 5000), voice(5400, 8000), voice(10000, 15000)];
      expect(await walk(5200, take, (s) => frenchFrom(s, 10000), w: early), ms(9000));
    });

    test('a cut walked back is never walked forward too', () async {
      final take = [voice(800, 9500), voice(12040, 14000), voice(14500, 16800)];
      final asked = <TakeWindow>[];
      final walked = await walk(14250, take, (s) {
        asked.add(s);
        return s.start >= ms(14500) ? 0.01 : 0.99;
      });
      expect(walked, ms(10770));
      expect(asked.every((s) => s.start < ms(14250)), isTrue);
    });

    test('a cut already between the languages stays', () async {
      final take = [voice(800, 9500), voice(12040, 17000)];
      expect(await walk(10770, take, (s) => frenchFrom(s, 12000)), ms(10770));
    });

    test('a stretch too short to tell apart stops the walk', () async {
      final short = [voice(800, 9500), voice(12040, 13000), voice(13500, 20000)];
      expect(await walk(13250, short, (s) => frenchFrom(s, 12000)), ms(13250));
    });

    test('odds short of sure stop the walk', () async {
      final take = [voice(800, 9500), voice(12040, 14000), voice(14500, 20000)];
      expect(await walk(14250, take, (s) => 0.6), ms(14250));
    });

    test('no answer stops the walk', () async {
      final take = [voice(800, 9500), voice(12040, 14000), voice(14500, 20000)];
      expect(await walk(14250, take, (s) => null), ms(14250));
    });

    test('the walk passes three stretches at most', () async {
      const wide = (start: Duration.zero, end: Duration(seconds: 30));
      final many = [for (var i = 0; i < 6; i++) voice(i * 4000, i * 4000 + 3000)];
      expect(await walk(23500, many, (s) => 0.99, w: wide), ms(11500));
    });

    test('the walk never reads a stretch that runs out of its window', () async {
      final take = [voice(800, 9500), voice(12040, 14000), voice(14500, 20000)];
      const tight = (start: Duration(milliseconds: 12500), end: Duration(seconds: 17));
      expect(await walk(14250, take, (s) => 0.99, w: tight), ms(14250));
    });

    test('a cut inside a stretch of speech stays', () async {
      final take = [voice(800, 20000)];
      expect(await walk(10000, take, (s) => 0.99), ms(10000));
    });
  });

  group('foldSilentSpans', () {
    test('a silent span in the middle folds into the span before it', () {
      const spans = [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 4000, localeId: 'fr-FR'),
        LanguageSpan(startMs: 8000, localeId: 'de-DE'),
      ];
      expect(foldSilentSpans(spans, {1}), const [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 8000, localeId: 'de-DE'),
      ]);
    });

    test('neighbors in one language merge once the silence between them goes', () {
      const spans = [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 4000, localeId: 'fr-FR'),
        LanguageSpan(startMs: 8000, localeId: 'en-US'),
      ];
      expect(foldSilentSpans(spans, {1}), const [LanguageSpan(startMs: 0, localeId: 'en-US')]);
    });

    test('a silent opening span leaves the take to the first span that spoke', () {
      const spans = [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 3000, localeId: 'fr-FR'),
      ];
      expect(foldSilentSpans(spans, {0}), const [LanguageSpan(startMs: 0, localeId: 'fr-FR')]);
    });

    test('a take with every span silent keeps its spans', () {
      const spans = [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 3000, localeId: 'fr-FR'),
      ];
      expect(foldSilentSpans(spans, {0, 1}), spans);
    });
  });
}
