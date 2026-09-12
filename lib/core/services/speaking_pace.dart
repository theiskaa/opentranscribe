import 'dart:math' as math;

import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/utils/language_tags.dart';

/// Languages written in an alphabet with spaces between words (Latin,
/// Cyrillic, Greek), where a second of speech runs to about the same length.
// dart format off
const Set<String> _alphabetic = {
  'af', 'az', 'ba', 'be', 'bg', 'br', 'bs', 'ca', 'cs', 'cy', 'da', 'de', 'el',
  'en', 'es', 'et', 'eu', 'fi', 'fo', 'fr', 'ga', 'gl', 'ha', 'haw', 'hr',
  'ht', 'hu', 'id', 'is', 'it', 'jv', 'kk', 'lb', 'ln', 'lt', 'lv', 'mg', 'mi',
  'mk', 'mn', 'ms', 'mt', 'nb', 'nl', 'nn', 'no', 'oc', 'pl', 'pt', 'ro', 'ru',
  'sk', 'sl', 'sn', 'so', 'sq', 'sr', 'su', 'sv', 'sw', 'tg', 'tk', 'tl', 'tr',
  'tt', 'uk', 'uz', 'vi', 'yo',
};
// dart format on

/// Characters a second of speech runs to in [localeId], spaces and
/// punctuation included, before any take has taught it. Rough by script; the
/// learned pace replaces it.
double startingPace(String localeId) => switch (cjkScriptOf(localeId)) {
  CjkScript.japanese => 6.5,
  CjkScript.chinese => 5,
  CjkScript.korean => 7.5,
  null => _alphabetic.contains(languageOf(localeId)) ? 16 : 13,
};

/// A forecast never promises less than a short word.
const int _shortestWord = 4;

/// About how many characters [speech] runs to over a take of [audio] whose
/// language [spans] (ascending starts in audio ms, at least one) each speak at
/// their own [pace]. Speech is shared out by each span's slice of the audio.
int forecastCharacters({
  required Duration speech,
  required Duration audio,
  required List<({int startMs, String tag})> spans,
  required double Function(String localeId) pace,
}) {
  assert(spans.isNotEmpty, 'a take has at least its opening span');
  final seconds = speech.inMicroseconds / Duration.microsecondsPerSecond;
  final total = audio.inMilliseconds;
  if (total <= 0) return math.max(_shortestWord, (seconds * pace(spans.first.tag)).round());
  var characters = 0.0;
  for (var i = 0; i < spans.length; i++) {
    final end = i + 1 < spans.length ? spans[i + 1].startMs : total;
    final share = (math.min(end, total) - math.min(spans[i].startMs, total)) / total;
    characters += seconds * share * pace(spans[i].tag);
  }
  return math.max(_shortestWord, characters.round());
}

/// How far one landed take moves its language's pace.
const double _learnWeight = 0.3;

/// The pace after a take that ran at [observed]: [current] (else [starting])
/// moved part of the way there, one take read as no less than half and no
/// more than double [starting], so a mangled pass cannot swing it.
double nextPace(double? current, {required double observed, required double starting}) {
  final from = current ?? starting;
  final seen = observed.isFinite ? observed.clamp(starting / 2, starting * 2) : from;
  return from + _learnWeight * (seen - from);
}

/// The pace each language is spoken at on this phone, learned from the takes
/// that land: one number per language, stored on the device, nothing else.
class SpeakingPace {
  SpeakingPace({required this._storage});

  final LocalService _storage;

  static const _key = 'transcribe.speakingPace';

  /// Under this much speech a word more or less swings the ratio.
  static const Duration _shortestLesson = Duration(seconds: 3);

  Map<String, double>? _paces;

  Map<String, double> get _learned => _paces ??= _read();

  Map<String, double> _read() {
    try {
      return _storage.readJson(
            _key,
            (json) => {
              for (final MapEntry(:key, :value) in json.entries)
                if (value is num && value.isFinite && value > 0) key: value.toDouble(),
            },
          ) ??
          {};
    } catch (_) {
      return {};
    }
  }

  /// Characters a second of speech in [localeId]: learned, else the start.
  double of(String localeId) => _learned[languageOf(localeId)] ?? startingPace(localeId);

  /// Moves [localeId]'s pace toward a take whose words ran to [characters]
  /// over [speech]; a take under three seconds of speech, or with no words,
  /// changes nothing. Throws when persisting fails, the pace having moved for
  /// this session regardless.
  Future<void> learn(String localeId, {required int characters, required Duration speech}) async {
    if (speech < _shortestLesson || characters <= 0) return;
    final language = languageOf(localeId);
    final observed = characters / (speech.inMicroseconds / Duration.microsecondsPerSecond);
    _learned[language] = nextPace(
      _learned[language],
      observed: observed,
      starting: startingPace(localeId),
    );
    await _storage.writeJson(_key, _learned);
  }
}
