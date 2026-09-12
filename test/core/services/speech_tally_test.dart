import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/services/speech_tally.dart';

void main() {
  const window = Duration(milliseconds: 100);

  SpeechTally trace(List<double> levels, {Duration step = window, Duration from = Duration.zero}) {
    final tally = SpeechTally();
    var at = from;
    for (final level in levels) {
      tally.add(level, at);
      at += step;
    }
    return tally;
  }

  List<double> run(double level, int windows) => List.filled(windows, level);

  test('no windows at all is no speech', () {
    expect(SpeechTally().speech, Duration.zero);
  });

  test('a take of room tone is no speech', () {
    expect(trace(run(0.2, 50)).speech, Duration.zero);
  });

  test('steady speech after a quiet lead-in counts only the talking', () {
    final tally = trace([...run(0.1, 20), ...run(0.8, 30)]);
    expect(tally.speech, const Duration(seconds: 3));
  });

  test('the short gaps between words count as speech', () {
    final words = [
      ...run(0.1, 10),
      for (var i = 0; i < 5; i++) ...[...run(0.8, 4), ...run(0.1, 2)],
    ];
    expect(trace(words).speech, const Duration(milliseconds: 2800));
  });

  test('a pause of a second between sentences does not count', () {
    final tally = trace([...run(0.1, 10), ...run(0.8, 10), ...run(0.1, 10), ...run(0.8, 10)]);
    expect(tally.speech, const Duration(seconds: 2));
  });

  test('a gap in the windows, a pause or an interruption, adds no time of its own', () {
    final tally = SpeechTally();
    var at = Duration.zero;
    for (final level in [...run(0.1, 10), ...run(0.8, 10)]) {
      tally.add(level, at);
      at += window;
    }
    at += const Duration(minutes: 5);
    for (final level in run(0.8, 10)) {
      tally.add(level, at);
      at += window;
    }
    expect(tally.speech, const Duration(seconds: 2));
  });

  test('a noisy room raises the bar above its own floor', () {
    final cafe = trace([...run(0.5, 20), ...run(0.55, 20), ...run(0.8, 10)]);
    expect(cafe.speech, const Duration(seconds: 1));
  });

  test('quiet speech in a silent room still clears the heard threshold', () {
    final tally = trace([...run(0.0, 20), ...run(0.35, 10)]);
    expect(tally.speech, const Duration(seconds: 1));
  });

  test('a short quiet run after the last word is not counted', () {
    expect(
      trace([...run(0.1, 10), ...run(0.8, 10), ...run(0.1, 2)]).speech,
      const Duration(seconds: 1),
    );
  });

  test('a quiet run of exactly the bridge length is a pause, not a word gap', () {
    final tally = trace([...run(0.1, 10), ...run(0.8, 5), ...run(0.1, 3), ...run(0.8, 5)]);
    expect(tally.speech, const Duration(seconds: 1));
  });

  test('a window stamped before the last one breaks the bridge', () {
    final tally = SpeechTally()
      ..add(0.1, Duration.zero)
      ..add(0.1, window)
      ..add(0.8, window * 2)
      ..add(0.1, window * 3)
      ..add(0.8, window * 2);
    expect(tally.speech, window * 2);
  });

  test('windows delivered in the same instant each count their slice', () {
    final tally = SpeechTally()
      ..add(0.1, Duration.zero)
      ..add(0.1, window)
      ..add(0.8, window * 2)
      ..add(0.1, window * 3)
      ..add(0.1, window * 3)
      ..add(0.8, window * 4);
    expect(tally.speech, window * 4);
  });

  test('a headset mic\'s slower windows count their full length', () {
    final tally = trace([
      ...run(0.1, 10),
      ...run(0.8, 10),
    ], step: const Duration(milliseconds: 300));
    expect(tally.speech, const Duration(seconds: 3));
  });

  test('a stall that delivers windows in a burst loses none of them', () {
    final tally = SpeechTally();
    var at = Duration.zero;
    void add(double level, Duration after) {
      at += after;
      tally.add(level, at);
    }

    for (var i = 0; i < 10; i++) {
      add(0.1, window);
    }
    for (var i = 0; i < 5; i++) {
      add(0.8, window);
    }
    add(0.8, window * 5);
    for (var i = 0; i < 4; i++) {
      add(0.8, Duration.zero);
    }
    for (var i = 0; i < 5; i++) {
      add(0.8, window);
    }
    expect(tally.speech, window * 15);
  });

  test('a pause breaks the bridge even when the windows run on', () {
    final tally = SpeechTally();
    var at = Duration.zero;
    for (final level in [...run(0.1, 10), ...run(0.8, 5), ...run(0.1, 1)]) {
      tally.add(level, at);
      at += window;
    }
    tally.markBreak();
    for (final level in run(0.8, 5)) {
      tally.add(level, at);
      at += window;
    }
    expect(tally.speech, const Duration(seconds: 1));
  });
}
