import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/view/widgets/ink_forecast.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  final at = DateTime.utc(2026, 9, 12);
  const english = 'the words of an older entry, long enough to wrap like prose';
  const french = 'des mots français, assez longs pour passer à la ligne comme de la prose';

  Entry entry(String id, String text, String? localeId) => Entry(
    id: id,
    createdAt: at,
    audioPath: null,
    duration: const Duration(seconds: 30),
    recordedLocaleId: localeId,
    transcript: Transcript(
      fullText: text,
      segments: const [],
      localeId: localeId ?? '',
      engineId: 'fake',
      createdAt: at,
    ),
  );

  group('fillerSample', () {
    test('the first entry in the take\'s language lends its words, whatever the region', () {
      final sample = fillerSample(
        localeId: 'en-GB',
        journal: [entry('a', french, 'fr-FR'), entry('b', english, 'en-US')],
      );
      expect(sample, english);
    });

    test('an entry with too few words to wrap like prose is passed over', () {
      final sample = fillerSample(
        localeId: 'en-US',
        journal: [entry('a', 'ok', 'en-US'), entry('b', english, 'en-US')],
      );
      expect(sample, english);
    });

    test('a language the journal has never heard falls back to its script', () {
      final japanese = fillerSample(localeId: 'ja-JP', journal: const []);
      final cantonese = fillerSample(localeId: 'yue', journal: const []);
      final korean = fillerSample(localeId: 'ko-KR', journal: const []);
      final portuguese = fillerSample(localeId: 'pt-BR', journal: const []);
      expect(japanese.contains(RegExp('[ぁ-ん]')), isTrue);
      expect(cantonese.contains(RegExp('[ぁ-ん]')), isFalse);
      expect(cantonese.contains(' '), isFalse);
      expect(korean.contains(RegExp('[가-힣]')), isTrue);
      expect(portuguese.split(' ').length, greaterThan(10));
    });
  });

  group('fillerText', () {
    test('runs to about the asked length and ends on a whole word', () {
      const sample = 'alpha beta gamma delta epsilon';
      final text = fillerText(sample, 40);
      expect(text.length, greaterThanOrEqualTo(40));
      expect(text.length, lessThan(40 + 'epsilon'.length + 1));
      for (final word in text.split(' ')) {
        expect(sample.split(' '), contains(word));
      }
    });

    test('cycles a short sample as often as it takes', () {
      expect(fillerText('ab cd', 10), 'ab cd ab cd');
    });

    test('an unspaced script is cycled by character', () {
      expect(fillerText('今日は 市場まで歩いた', 6), '今日は市場ま');
    });

    test('a character is never split from its marks', () {
      expect(fillerText('ที่นี่', 2), 'ที่');
    });

    test('Hangul, written with spaces, is cycled by word', () {
      expect(fillerText('오늘은 시장까지 걸어갔다', 8), '오늘은 시장까지');
    });

    test('a run too long to be a word is cut at the asked length', () {
      expect(fillerText('a' * 500, 5), 'aaaaa');
      expect(fillerText('ཀཁགངཅཆཇཉཏཐདནཔཕབམ', 3), 'ཀཁག');
    });

    test('nothing to cycle, or nothing asked, is empty', () {
      expect(fillerText('   ', 20), '');
      expect(fillerText('words', 0), '');
    });
  });

  group('mostCharacters', () {
    test('holds more on a wider line, fewer at a larger size, and scales with the lines', () {
      final base = mostCharacters(width: 300, fontSize: 17, lines: 1);
      expect(mostCharacters(width: 600, fontSize: 17, lines: 1), greaterThan(base));
      expect(mostCharacters(width: 300, fontSize: 34, lines: 1), lessThan(base));
      expect(mostCharacters(width: 300, fontSize: 17, lines: 4), base * 4);
    });

    test('text too small to set holds nothing', () {
      expect(mostCharacters(width: 300, fontSize: 0, lines: 4), 0);
    });
  });
}
