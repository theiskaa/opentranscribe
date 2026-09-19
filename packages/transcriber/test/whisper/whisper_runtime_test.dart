import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/whisper/whisper_runtime.dart';

void main() {
  test('a segment built from centiseconds lands on the right milliseconds', () {
    final segment = WhisperSegment.centiseconds(text: 'hi', start: 150, end: 275, confidence: 0.5);

    expect(segment.start, const Duration(milliseconds: 1500));
    expect(segment.end, const Duration(milliseconds: 2750));
    expect(
      segment,
      const WhisperSegment(
        text: 'hi',
        start: Duration(milliseconds: 1500),
        end: Duration(milliseconds: 2750),
        confidence: 0.5,
      ),
    );
  });
}
