// Writes the website recorder's take and its test vectors from the app's own
// onboarding scene, so the two play one take. Run from the repo root:
//   flutter test tool/web_take.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_record.dart';
import 'package:opentranscribe/view/layouts/recorder/components/live_transcript.dart';
import 'package:opentranscribe/view/layouts/recorder/components/waveform.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';

const _takeLength = Duration(seconds: 42);
const _firstBurst = Duration(milliseconds: 500);
const _lastBreath = Duration(milliseconds: 700);
const _recognizerLag = Duration(milliseconds: 180);
const _perWord = Duration(milliseconds: 230);
const _wordsPerBurst = 5;

double _ms(Duration d) => d.inMicroseconds / 1000;

String _hex(Color c) {
  int ch(double v) => (v * 255).round();
  String two(int v) => v.toRadixString(16).padLeft(2, '0');
  return '#${two(ch(c.r))}${two(ch(c.g))}${two(ch(c.b))}${two(ch(c.a))}';
}

void main() {
  test('the website take and its vectors are written from the onboarding scene', () {
    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final sentences = [for (var i = 1; i <= 6; i++) arb['onboardingRecordText$i'] as String];
    final speech = speechTokens(sentences);
    final bursts = fitSchedule(
      speechSchedule(
        speech.tokens,
        first: _firstBurst,
        perToken: _perWord,
        maxBurst: _wordsPerBurst,
      ),
      first: _firstBurst,
      end: _takeLength - _lastBreath,
    );
    final landings = tokenLandings(bursts, lag: _recognizerLag);
    final recorder = AppTheme.defaultDark.recorder;

    final take = {
      'lengthMs': _takeLength.inMilliseconds,
      'tokens': speech.tokens,
      'joiner': speech.joiner,
      'bursts': [
        for (final b in bursts)
          {
            'speakStart': _ms(b.speakStart),
            'speakEnd': _ms(b.speakEnd),
            'lands': _ms(b.lands),
            'shown': b.shown,
          },
      ],
      'landings': [for (final l in landings) _ms(l)],
      'colors': {
        'timer': _hex(recorder.timerColor),
        'waveformBar': _hex(recorder.waveformBar),
        'waveformBarIdle': _hex(recorder.waveformBarIdle),
        'waveformBaseline': _hex(recorder.waveformBaseline),
        'liveText': _hex(recorder.liveTextColor),
        'liveTextFaded': _hex(recorder.liveTextFadedColor),
      },
    };

    double widthOf(String word) => word.length * 9.0;
    final text = speech.tokens.join(speech.joiner);
    final (:words, :glued) = transcriptWords(text);
    final vectors = {
      'waveformLevel': [
        for (var i = 0; i <= 100; i++) [i / 100, waveformLevel(i / 100)],
      ],
      'voice': [
        for (var ms = 0; ms < _takeLength.inMilliseconds; ms += 50)
          [
            ms,
            speakingAt(Duration(milliseconds: ms), bursts),
            sceneVoiceLevel(
              Duration(milliseconds: ms),
              speaking: speakingAt(Duration(milliseconds: ms), bursts),
            ),
            tokensShownBy(Duration(milliseconds: ms), landings),
          ],
      ],
      'edges': [
        for (final at in <Duration>{
          for (final b in bursts) ...[b.speakStart, b.speakEnd],
          ...landings,
        })
          for (final d in [at - const Duration(microseconds: 1), at])
            [_ms(d), speakingAt(d, bursts), tokensShownBy(d, landings)],
      ],
      'words': {'text': text, 'words': words, 'glued': glued},
      'oddWords': [
        for (final sample in ['', '  \n', '  two  spaces\tand\na tab ', '雨🌧️です。ok😀、はい', '。「はい」'])
          () {
            final r = transcriptWords(sample);
            return {'text': sample, 'words': r.words, 'glued': r.glued};
          }(),
      ],
      'cjkWords': () {
        const sample = '今日は、静かな一日でした。OK だった。';
        final r = transcriptWords(sample);
        return {'text': sample, 'words': r.words, 'glued': r.glued};
      }(),
      'packLines': [
        for (final width in [40.0, 200.0, 322.0, 400.0])
          {
            'maxWidth': width,
            'lines': packLines(words, widthOf, spaceWidth: 4, maxWidth: width, glued: glued),
          },
      ],
      'packIncrementally': () {
        var prevWords = const <String>[];
        var prevGlued = const <bool>[];
        var prev = const <List<int>>[];
        double? prevWidth;
        final steps = <Map<String, dynamic>>[];
        for (var n = 1; n <= speech.tokens.length; n++) {
          final t = transcriptWords(speech.tokens.take(n).join(speech.joiner));
          final lines = packIncrementally(
            t.words,
            widthOf,
            spaceWidth: 4,
            maxWidth: 322,
            previousWords: prevWords,
            previous: prev,
            previousMaxWidth: prevWidth,
            glued: t.glued,
            previousGlued: prevGlued,
          );
          steps.add({'shown': n, 'lines': lines});
          prevWords = t.words;
          prevGlued = t.glued;
          prev = lines;
          prevWidth = 322;
        }
        return steps;
      }(),
      'packRevisions': () {
        var prevWords = const <String>[];
        var prevGlued = const <bool>[];
        var prev = const <List<int>>[];
        final steps = <Map<String, dynamic>>[];
        for (final revision in [
          'Walked home the long way and the city was quiet',
          'Walked home the long way and the city was quite loud for once',
          'Walked back the long way and the city was quite loud for once',
          'Walked back the long way',
          'Walked back the longway',
          '今日は、静かな一日でした',
          '今日は、 静かな一日でした。OK',
          '',
          'Again',
        ]) {
          final t = transcriptWords(revision);
          final lines = packIncrementally(
            t.words,
            widthOf,
            spaceWidth: 4,
            maxWidth: 120,
            previousWords: prevWords,
            previous: prev,
            previousMaxWidth: 120,
            glued: t.glued,
            previousGlued: prevGlued,
          );
          steps.add({'text': revision, 'lines': lines});
          prevWords = t.words;
          prevGlued = t.glued;
          prev = lines;
        }
        return steps;
      }(),
      'gluedDivergence': [
        for (final pair in [('今日 は', '今日は'), ('今日は', '今日は。'), ('a b', 'a b')])
          () {
            final a = transcriptWords(pair.$1);
            final b = transcriptWords(pair.$2);
            return {
              'a': a.words,
              'b': b.words,
              'aGlued': a.glued,
              'bGlued': b.glued,
              'at': firstDivergence(a.words, b.words, aGlued: a.glued, bGlued: b.glued),
            };
          }(),
      ],
      'firstDivergence': [
        for (final pair in [
          [
            ['a', 'b', 'c'],
            ['a', 'b', 'c', 'd'],
          ],
          [
            ['a', 'b', 'c'],
            ['a', 'x', 'c'],
          ],
          [<String>[], <String>[]],
          [
            ['recognise', 'it'],
            ['recognized'],
          ],
        ])
          {'a': pair[0], 'b': pair[1], 'at': firstDivergence(pair[0], pair[1])},
      ],
      'rollingSlots': [
        for (var s = 0; s < 42; s++)
          () {
            final from = formatElapsed(Duration(seconds: s));
            final to = formatElapsed(Duration(seconds: s + 1));
            return {
              'from': from,
              'to': to,
              'slots': [
                for (final slot in rollingSlots(from, to)) {'char': slot.char, 'rolls': slot.rolls},
              ],
            };
          }(),
      ],
      'rollingGrowth': [
        for (final pair in [
          ('59:59', '1:00:00'),
          ('1:00:00', '00:00'),
          ('', '00:00'),
          ('a👍🏽b', 'a👨‍👩‍👧b'),
          ('cafe\u0301', 'cafe'),
        ])
          {
            'from': pair.$1,
            'to': pair.$2,
            'slots': [
              for (final slot in rollingSlots(pair.$1, pair.$2))
                {'char': slot.char, 'rolls': slot.rolls},
            ],
          },
      ],
      'formatElapsed': [
        for (final s in [0, 9, 42, 60, 61, 599, 3599, 3600, 3909])
          [s, formatElapsed(Duration(seconds: s))],
      ],
    };

    const encoder = JsonEncoder.withIndent(' ');
    File('web/lib/recorder/take.json').writeAsStringSync('${encoder.convert(take)}\n');
    File('web/lib/recorder/vectors.json').writeAsStringSync('${jsonEncode(vectors)}\n');
  });
}
