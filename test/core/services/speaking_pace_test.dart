import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/speaking_pace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('startingPace', () {
    test('alphabetic languages share one pace, whatever the region', () {
      expect(startingPace('en-US'), 14);
      expect(startingPace('en-GB'), 14);
      expect(startingPace('ru-RU'), 14);
      expect(startingPace('el'), 14);
    });

    test('languages written in characters run to fewer of them a second', () {
      expect(startingPace('ja-JP'), 6);
      expect(startingPace('zh-Hans'), 4.5);
      expect(startingPace('yue'), 4.5);
      expect(startingPace('ko-KR'), 7);
    });

    test('a language without a known script starts in the middle', () {
      expect(startingPace('th-TH'), 12);
    });
  });

  group('forecastCharacters', () {
    int forecast(
      Duration speech, {
      List<LanguageSpan> spans = const [LanguageSpan(startMs: 0, localeId: 'en-US')],
      Duration audio = const Duration(seconds: 10),
    }) => forecastCharacters(speech: speech, audio: audio, spans: spans, pace: startingPace);

    test('speech time times the language pace', () {
      expect(forecast(const Duration(seconds: 10)), 140);
      expect(
        forecast(
          const Duration(seconds: 10),
          spans: const [LanguageSpan(startMs: 0, localeId: 'ja-JP')],
        ),
        60,
      );
    });

    test('a silent take still forecasts a short word', () {
      expect(forecast(Duration.zero), 4);
    });

    test('a two-language take shares its speech by each span of audio', () {
      final mixed = forecast(
        const Duration(seconds: 10),
        spans: const [
          LanguageSpan(startMs: 0, localeId: 'en-US'),
          LanguageSpan(startMs: 5000, localeId: 'ja-JP'),
        ],
      );
      expect(mixed, 100);
    });

    test('a take with no audio length runs at its opening span\'s pace', () {
      expect(forecast(const Duration(seconds: 10), audio: Duration.zero), 140);
    });

    test('a span starting past the end of the audio adds nothing', () {
      final late = forecast(
        const Duration(seconds: 10),
        spans: const [
          LanguageSpan(startMs: 0, localeId: 'en-US'),
          LanguageSpan(startMs: 20000, localeId: 'ja-JP'),
        ],
      );
      expect(late, 140);
    });
  });

  group('nextPace', () {
    test('a take moves the pace part of the way toward it', () {
      expect(nextPace(null, observed: 20, starting: 16), closeTo(17.2, 1e-9));
      expect(nextPace(17.2, observed: 20, starting: 16), closeTo(18.04, 1e-9));
    });

    test('takes at one pace draw the pace to it', () {
      double? pace;
      for (var i = 0; i < 20; i++) {
        pace = nextPace(pace, observed: 12, starting: 16);
      }
      expect(pace, closeTo(12, 0.01));
    });

    test('one mangled pass counts as no more than double the start and no less than half', () {
      expect(nextPace(null, observed: 400, starting: 16), closeTo(16 + 0.3 * 16, 1e-9));
      expect(nextPace(null, observed: 0.5, starting: 16), closeTo(16 - 0.3 * 8, 1e-9));
    });

    test('an observed pace that is not finite teaches nothing', () {
      expect(nextPace(15, observed: double.infinity, starting: 16), 15);
      expect(nextPace(15, observed: double.nan, starting: 16), 15);
    });
  });

  group('SpeakingPace', () {
    const key = 'test-encryption-key-0123456789ab';
    late LocalService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalService();
      await storage.init(legacyKey: key);
    });

    test('a language no take has taught runs at its starting pace', () {
      expect(SpeakingPace(storage: storage).of('ja-JP'), 6);
    });

    test('a landed take moves its language, and every region of it', () async {
      final pace = SpeakingPace(storage: storage);
      await pace.learn('en-US', characters: 200, speech: const Duration(seconds: 10));
      expect(pace.of('en-US'), closeTo(15.8, 1e-9));
      expect(pace.of('en-GB'), closeTo(15.8, 1e-9));
      expect(pace.of('de-DE'), 14);
    });

    test('a take under three seconds of speech, or with no words, teaches nothing', () async {
      final pace = SpeakingPace(storage: storage);
      await pace.learn('en-US', characters: 100, speech: const Duration(seconds: 2));
      await pace.learn('en-US', characters: 0, speech: const Duration(seconds: 10));
      expect(pace.of('en-US'), 14);
    });

    test('what was learned survives a relaunch', () async {
      await SpeakingPace(
        storage: storage,
      ).learn('ko-KR', characters: 100, speech: const Duration(seconds: 10));
      expect(SpeakingPace(storage: storage).of('ko-KR'), closeTo(7 + 0.3 * 3, 1e-9));
    });

    test('a stored value that cannot be read falls back to the start', () async {
      await storage.write('transcribe.speechPace', 'not json');
      expect(SpeakingPace(storage: storage).of('en-US'), 14);
    });

    test('a pace learned when speech counted no pauses is let go, not read', () async {
      await storage.writeJson('transcribe.speakingPace', {'en': 30.0});
      expect(SpeakingPace(storage: storage).of('en-US'), 14);
      await pumpEventQueue();
      expect(storage.containsKey('transcribe.speakingPace'), isFalse);
    });
  });
}
