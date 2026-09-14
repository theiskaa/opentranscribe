import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/services/live_words.dart';

void main() {
  test('words heard after a switch follow the words before it, marked at the change', () {
    final live = LiveWords()..update('hello');
    live.commit('en-US');
    live.update('bonjour');

    expect(live.text('fr-FR'), 'hello [fr] bonjour');
  });

  test('a switch within one language adds no marker', () {
    final live = LiveWords()..update('colour');
    live.commit('en-GB');
    live.update('color');

    expect(live.text('en-US'), 'colour color');
  });

  test('a pass that heard nothing leaves the next words marked against the last ones', () {
    final live = LiveWords()..update('hello');
    live.commit('en-US');
    live.commit('fr-FR');
    live.update('again');

    expect(live.text('en-US'), 'hello again');
    expect(live.text('de-DE'), 'hello [de] again');
  });

  test('the first language is the one the kept words were first spoken in', () {
    final live = LiveWords();
    live.commit('en-US');
    live.update('bonjour');
    live.commit('fr-FR');
    live.update('hallo');
    live.commit('de-DE');

    expect(live.firstLocaleId, 'fr-FR');
  });

  test('a cleared take starts from nothing', () {
    final live = LiveWords()..update('hello');
    live.commit('en-US');
    live.clear();

    expect(live.text('fr-FR'), '');
    expect(live.firstLocaleId, isNull);
  });
}
