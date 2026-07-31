import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_labels.dart';

/// The reading meta line is the reflections surfaces' real label logic; no
/// widget is pumped (no widget tests).
void main() {
  test('the meta line joins its halves with a middle dot, outside translations', () {
    expect(
      reflectionMetaLine(voiceLabel: 'Literary', writtenLabel: 'Written Jun 29'),
      'Literary · Written Jun 29',
    );
  });

  test('a voice-less legacy record drops its half, not the whole line', () {
    // voice is null on reflections stored before it was persisted.
    expect(reflectionMetaLine(writtenLabel: 'Written Jun 29'), 'Written Jun 29');
    expect(reflectionMetaLine(voiceLabel: 'Sparse'), 'Sparse');
  });
}
