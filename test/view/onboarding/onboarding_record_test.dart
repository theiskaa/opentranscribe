import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_record.dart';

void main() {
  const first = Duration(milliseconds: 1100);
  const perWord = Duration(milliseconds: 230);
  final words = 'Met Lia for coffee. Then I sat on the steps and did nothing.'.split(' ');

  test('spaced text speaks by word and joins with a space, unspaced by character', () {
    final spaced = speechTokens(['Met Lia.', 'Then home.']);
    expect(spaced.tokens, ['Met', 'Lia.', 'Then', 'home.']);
    expect(spaced.joiner, ' ');
    final unspaced = speechTokens(['和 Lia 喝。', 'は']);
    expect(unspaced.tokens, ['和 ', 'Lia ', '喝', '。', 'は']);
    expect(unspaced.joiner, '');
  });

  test('bursts cover every token exactly once, in order, and never cross a sentence end', () {
    final bursts = speechSchedule(words, first: first, perToken: perWord, maxBurst: 5);
    expect(bursts.first.speakStart, first);
    expect(bursts.last.shown, words.length);
    var previous = 0;
    for (final burst in bursts) {
      expect(burst.shown, greaterThan(previous));
      final closes = words.sublist(previous, burst.shown - 1).any((w) => w.endsWith('.'));
      expect(closes, isFalse);
      previous = burst.shown;
    }
  });

  test('a burst is spoken first and lands after, and the next waits for it', () {
    final bursts = speechSchedule(words, first: first, perToken: perWord, maxBurst: 5);
    for (final (i, burst) in bursts.indexed) {
      expect(burst.speakEnd, greaterThan(burst.speakStart));
      expect(burst.lands, greaterThan(burst.speakEnd));
      if (i > 0) expect(burst.speakStart, greaterThan(bursts[i - 1].speakEnd));
    }
  });

  test('the same seed plays the same take', () {
    final a = speechSchedule(words, first: first, perToken: perWord, maxBurst: 5);
    final b = speechSchedule(words, first: first, perToken: perWord, maxBurst: 5);
    expect([for (final x in a) x.lands], [for (final x in b) x.lands]);
  });

  test('every token lands once, in order, a lag behind the voice that spoke it', () {
    final bursts = speechSchedule(words, first: first, perToken: perWord, maxBurst: 5);
    const lag = Duration(milliseconds: 180);
    final landings = tokenLandings(bursts, lag: lag);
    expect(landings.length, words.length);
    for (var i = 1; i < landings.length; i++) {
      expect(landings[i], greaterThan(landings[i - 1]));
    }
    expect(landings.first, greaterThan(bursts.first.speakStart + lag));
    expect(landings[bursts.first.shown - 1], bursts.first.speakEnd + lag);
  });

  test('tokens shown follow the landings, and speaking follows the voice', () {
    final bursts = speechSchedule(words, first: first, perToken: perWord, maxBurst: 5);
    final landings = tokenLandings(bursts, lag: const Duration(milliseconds: 180));
    expect(tokensShownBy(Duration.zero, landings), 0);
    expect(tokensShownBy(landings.first, landings), 1);
    expect(tokensShownBy(const Duration(minutes: 1), landings), words.length);
    expect(speakingAt(bursts.first.speakStart, bursts), isTrue);
    expect(speakingAt(bursts.first.speakEnd, bursts), isFalse);
    expect(speakingAt(Duration.zero, bursts), isFalse);
  });

  test('a fitted schedule keeps its first beat and lands its last where asked', () {
    final bursts = speechSchedule(words, first: first, perToken: perWord, maxBurst: 5);
    const end = Duration(seconds: 41);
    final fitted = fitSchedule(bursts, first: first, end: end);
    expect(fitted.first.speakStart, first);
    expect(fitted.last.lands, end);
    expect(fitted.length, bursts.length);
    for (var i = 1; i < fitted.length; i++) {
      expect(fitted[i].speakStart, greaterThan(fitted[i - 1].speakEnd));
    }
  });
}
