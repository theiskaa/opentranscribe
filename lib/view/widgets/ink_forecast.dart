import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/utils/language_tags.dart';

// Filler that stands in for a take's words until they land. Never shown and
// never spoken: a surface only measures it, or paints and samples it into
// ink, and keeps it out of the semantics tree. So these samples are not
// user-facing and not localized; each is here only for its script's widths
// and line breaks.
const String _kanaSample = '今日は仕事の前に市場まで歩いた。雨上がりみたいに光がきれいだった。姉との電話のことをまだ考えている。';
const String _hanSample = '今天上班前走去了市场，光线像刚下过雨一样干净。我还在想和姐姐的那通电话，我们都说自己很好。';
const String _hangulSample = '오늘은 출근 전에 시장까지 걸어갔다. 비가 그친 뒤처럼 빛이 맑았다. 언니와의 통화가 계속 생각난다.';
const String _latinSample =
    'I walked to the market before work and the light was doing that thing where '
    'everything looks rinsed. I keep thinking about the call with my sister, how we both '
    'said we were fine and neither of us meant it.';

/// Under this many characters a sample would cycle a word or two over and
/// over, which wraps nothing like prose.
const int _shortestSample = 40;

/// The words a forecast of a take in [localeId] is laid out in: the first
/// entry of [journal] in that language with a line or more of words (a caller
/// continuing an entry puts it first, then the journal newest first), else a
/// fixed sample: Japanese, Chinese or Korean for those, Latin for the rest.
/// The user's own words make the filler wrap the way theirs will.
String fillerSample({required String localeId, required List<Entry> journal}) {
  final language = languageOf(localeId);
  for (final entry in journal) {
    final tag = entry.effectiveLocaleId;
    if (tag == null || languageOf(tag) != language) continue;
    final text = entry.readableText?.trim() ?? '';
    if (text.length >= _shortestSample) return text;
  }
  return switch (language) {
    'ja' => _kanaSample,
    'zh' || 'yue' => _hanSample,
    'ko' => _hangulSample,
    _ => _latinSample,
  };
}

/// About [characters] of [sample]'s words, cycled as often as it takes and
/// ending on a whole word (a word too long to be one is cut at the length); a
/// sample in a script written without spaces (Japanese, Chinese, Thai) is
/// cycled by character. Empty when the sample has no words. A caller clamps
/// [characters] to what it can show ([mostCharacters]), and keeps the filler
/// out of the semantics tree.
String fillerText(String sample, int characters) {
  final trimmed = sample.trim();
  if (trimmed.isEmpty || characters <= 0) return '';
  final spaced = !_unspaced(trimmed);
  final tokens = spaced
      ? trimmed.split(_space)
      : trimmed.replaceAll(_space, '').characters.toList();
  final out = StringBuffer();
  for (var i = 0; out.length < characters; i++) {
    if (spaced && out.isNotEmpty) out.write(' ');
    out.write(tokens[i % tokens.length]);
  }
  final text = out.toString();
  return text.length <= characters + _longestWord ? text : text.characters.take(characters).string;
}

/// Past this, a run of letters is a link or a laugh, not a word to wrap on.
const int _longestWord = 24;

/// The most characters [lines] of [fontSize] text can hold at [width]: the
/// narrowest glyphs are about a quarter of the size wide. A bound, so filler
/// past what a surface shows is never built or laid out.
int mostCharacters({required double width, required double fontSize, required int lines}) =>
    fontSize <= 0 ? 0 : (width / (fontSize * 0.25)).ceil() * lines;

final RegExp _space = RegExp(r'\s+');

final RegExp _unspacedScript = RegExp(
  r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Thai}\p{Script=Lao}'
  r'\p{Script=Khmer}\p{Script=Myanmar}\p{Script=Tibetan}]',
  unicode: true,
);

/// Whether most of [text]'s letters are in a script that runs words together.
/// Script properties, not code point ranges: they cover the ideograph
/// extensions and compatibility blocks too.
bool _unspaced(String text) {
  final letters = text.replaceAll(_space, '');
  return _unspacedScript.allMatches(letters).length * 2 > letters.runes.length;
}
