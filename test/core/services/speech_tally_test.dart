import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/services/speech_tally.dart';

void main() {
  const window = Duration(milliseconds: 100);

  SpeechTally trace(List<double> levels) {
    final tally = SpeechTally();
    levels.forEach(tally.add);
    return tally;
  }

  Duration speech(List<double> levels) => trace(levels).speechOf(window * levels.length);

  List<double> run(double level, int windows) => List.filled(windows, level);

  test('no windows at all is no speech', () {
    expect(SpeechTally().speechOf(const Duration(seconds: 5)), Duration.zero);
  });

  test('a take of room tone is no speech', () {
    expect(speech(run(0.2, 50)), Duration.zero);
  });

  test('steady speech after a quiet lead-in counts only the talking', () {
    expect(speech([...run(0.1, 20), ...run(0.8, 30)]), const Duration(seconds: 3));
  });

  test('the gaps between words and a breath between sentences count as talking', () {
    final words = [
      ...run(0.1, 10),
      for (var i = 0; i < 5; i++) ...[...run(0.8, 4), ...run(0.1, 6)],
      ...run(0.8, 4),
    ];
    expect(speech(words), const Duration(milliseconds: 5400));
  });

  test('soft syllables under the bar between louder ones still count', () {
    final murmur = [
      ...run(0.1, 20),
      for (var i = 0; i < 10; i++) ...[0.8, 0.2, 0.2],
    ];
    expect(speech(murmur), const Duration(milliseconds: 2800));
  });

  test('a silence of two seconds or more between stretches does not count', () {
    final levels = [...run(0.1, 10), ...run(0.8, 10), ...run(0.1, 20), ...run(0.8, 10)];
    expect(speech(levels), const Duration(seconds: 2));
  });

  test('a silence just under two seconds is still talking', () {
    final levels = [...run(0.1, 10), ...run(0.8, 10), ...run(0.1, 19), ...run(0.8, 10)];
    expect(speech(levels), const Duration(milliseconds: 3900));
  });

  test('a short quiet run after the last word is not counted', () {
    expect(speech([...run(0.1, 10), ...run(0.8, 10), ...run(0.1, 5)]), const Duration(seconds: 1));
  });

  test('each window is the take\'s length over its window count, however they arrived', () {
    final tally = trace([...run(0.1, 10), ...run(0.8, 10)]);
    expect(tally.speechOf(const Duration(seconds: 6)), const Duration(seconds: 3));
  });

  test('a noisy room raises the bar above its own floor', () {
    expect(
      speech([...run(0.5, 20), ...run(0.55, 20), ...run(0.8, 10)]),
      const Duration(seconds: 1),
    );
  });

  test('quiet speech in a silent room still clears the heard threshold', () {
    expect(speech([...run(0.0, 20), ...run(0.35, 10)]), const Duration(seconds: 1));
  });

  test('a pause ends the stretch even when the windows run on', () {
    final tally = trace([...run(0.1, 10), ...run(0.8, 5), ...run(0.1, 1)])..markBreak();
    run(0.8, 5).forEach(tally.add);
    expect(tally.speechOf(window * 21), const Duration(seconds: 1));
  });
}
