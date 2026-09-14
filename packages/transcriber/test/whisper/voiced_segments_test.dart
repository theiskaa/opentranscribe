import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/audio/audio_activity.dart';
import 'package:transcriber/src/whisper/voiced_segments.dart';
import 'package:transcriber/src/whisper/whisper_runtime.dart';

void main() {
  WhisperSegment segment(String text, int startMs, int endMs) => WhisperSegment(
    text: text,
    start: Duration(milliseconds: startMs),
    end: Duration(milliseconds: endMs),
    confidence: 0.9,
  );

  VoicedRange range(int startMs, int endMs) =>
      (start: Duration(milliseconds: startMs), end: Duration(milliseconds: endMs));

  List<String> kept(
    List<WhisperSegment> heard,
    List<VoicedRange>? voiced, {
    int lengthMs = 10000,
  }) => keepVoiced(
    heard,
    voiced: voiced,
    length: Duration(milliseconds: lengthMs),
  ).map((s) => s.text).toList();

  test('a segment over a voice stays and one over silence goes', () {
    final heard = [segment('said', 1000, 3000), segment('Thank you.', 6000, 8000)];
    expect(kept(heard, [range(900, 3100)]), ['said']);
  });

  test('a segment a little off its voice is still its words', () {
    expect(kept([segment('late', 3800, 4500)], [range(1000, 3000)]), ['late']);
    expect(kept([segment('early', 200, 400)], [range(1000, 3000)]), ['early']);
    expect(kept([segment('far', 4100, 5000)], [range(1000, 3000)]), isEmpty);
  });

  test('a segment with no letter or digit is not words', () {
    expect(kept([segment('...', 1000, 2000), segment('42', 1000, 2000)], null), ['42']);
  });

  test('a segment starting past the slice goes, and one running past it ends with it', () {
    final heard = keepVoiced(
      [segment('inside', 0, 30000), segment('padding', 12000, 14000)],
      voiced: null,
      length: const Duration(milliseconds: 140),
    );
    expect(heard.map((s) => s.text), ['inside']);
    expect(heard.single.end, const Duration(milliseconds: 140));
  });

  test('a probe that could not tell keeps every segment with words', () {
    expect(kept([segment('one', 0, 1000), segment('two', 5000, 6000)], null), ['one', 'two']);
  });
}
