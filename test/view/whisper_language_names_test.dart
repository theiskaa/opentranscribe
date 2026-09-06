import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  test('every language the whisper engine lists has a native name, never a raw tag', () {
    for (final tag in whisperLanguageTags.values) {
      expect(localeDisplayName(tag), isNot(tag), reason: tag);
    }
  });

  test('every whisper language with a region flies a flag, and the bare ones a globe', () {
    for (final tag in whisperLanguageTags.values) {
      final flag = localeFlag(tag);
      if (tag.contains('-')) {
        expect(flag, isNot('\u{1F310}'), reason: tag);
      } else {
        expect(flag, '\u{1F310}', reason: tag);
      }
    }
  });
}
