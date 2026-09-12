import 'dart:math' as math;

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
double startingPace(String localeId) => switch (languageOf(localeId)) {
  'ja' => 6.5,
  'zh' || 'yue' => 5,
  'ko' => 7.5,
  final language when _alphabetic.contains(language) => 16,
  _ => 13,
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
  final seconds = speech.inMilliseconds / 1000;
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
