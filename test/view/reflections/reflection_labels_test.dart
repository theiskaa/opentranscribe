import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_labels.dart';

void main() {
  test('the meta line joins its halves with a middle dot, outside translations', () {
    expect(
      reflectionMetaLine(voiceLabel: 'Literary', writtenLabel: 'Written Jun 29'),
      'Literary · Written Jun 29',
    );
  });

  test('a record stored before voice was persisted drops its half, not the whole line', () {
    expect(reflectionMetaLine(writtenLabel: 'Written Jun 29'), 'Written Jun 29');
    expect(reflectionMetaLine(voiceLabel: 'Sparse'), 'Sparse');
  });
}
