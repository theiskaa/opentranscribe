import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/services/speaking_pace.dart';

void main() {
  group('startingPace', () {
    test('alphabetic languages share one pace, whatever the region', () {
      expect(startingPace('en-US'), 16);
      expect(startingPace('en-GB'), 16);
      expect(startingPace('ru-RU'), 16);
      expect(startingPace('el'), 16);
    });

    test('languages written in characters run to fewer of them a second', () {
      expect(startingPace('ja-JP'), 6.5);
      expect(startingPace('zh-Hans'), 5);
      expect(startingPace('yue'), 5);
      expect(startingPace('ko-KR'), 7.5);
    });

    test('a language without a known script starts in the middle', () {
      expect(startingPace('th-TH'), 13);
    });
  });

  group('forecastCharacters', () {
    int forecast(
      Duration speech, {
      List<({int startMs, String tag})> spans = const [(startMs: 0, tag: 'en-US')],
      Duration audio = const Duration(seconds: 10),
    }) => forecastCharacters(speech: speech, audio: audio, spans: spans, pace: startingPace);

    test('speech time times the language pace', () {
      expect(forecast(const Duration(seconds: 10)), 160);
      expect(forecast(const Duration(seconds: 10), spans: [(startMs: 0, tag: 'ja-JP')]), 65);
    });

    test('a silent take still forecasts a short word', () {
      expect(forecast(Duration.zero), 4);
    });

    test('a two-language take shares its speech by each span of audio', () {
      final mixed = forecast(
        const Duration(seconds: 10),
        spans: [(startMs: 0, tag: 'en-US'), (startMs: 5000, tag: 'ja-JP')],
      );
      expect(mixed, 113);
    });

    test('a take with no audio length runs at its opening span\'s pace', () {
      expect(forecast(const Duration(seconds: 10), audio: Duration.zero), 160);
    });

    test('a span starting past the end of the audio adds nothing', () {
      final late = forecast(
        const Duration(seconds: 10),
        spans: [(startMs: 0, tag: 'en-US'), (startMs: 20000, tag: 'ja-JP')],
      );
      expect(late, 160);
    });
  });
}
