import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/morph_control.dart';

void main() {
  group('morphFaceKey', () {
    test('a measured bar is one face at every fill, so its sweep runs in place', () {
      expect(
        morphFaceKey(const MorphBar(fill: 0.1, label: '10%')),
        morphFaceKey(const MorphBar(fill: 0.9, label: 'Preparing')),
      );
    });

    test('a bar gaining or losing its measure crossfades rather than draining to empty', () {
      expect(
        morphFaceKey(const MorphBar(fill: null, label: 'Packing')),
        isNot(morphFaceKey(const MorphBar(fill: 0.98, label: 'Packing'))),
      );
    });

    test('a button with other words, glyph or variant is a new face whose words crossfade in', () {
      final key = morphFaceKey(const MorphButton(label: 'Back up', icon: AppIcons.icloud));

      expect(key, isNot(morphFaceKey(const MorphButton(label: 'Retry', icon: AppIcons.icloud))));
      expect(key, isNot(morphFaceKey(const MorphButton(label: 'Back up'))));
      expect(
        key,
        isNot(
          morphFaceKey(
            const MorphButton(
              label: 'Back up',
              icon: AppIcons.icloud,
              variant: MorphVariant.secondary,
            ),
          ),
        ),
      );
    });

    test('a bar never shares a key with a button', () {
      expect(
        morphFaceKey(const MorphBar(fill: null, label: '')),
        isNot(morphFaceKey(const MorphButton(label: ''))),
      );
      expect(
        morphFaceKey(const MorphBar(fill: 0.5, label: '50%')),
        isNot(morphFaceKey(const MorphButton(label: '50%'))),
      );
    });
  });

  group('morphDisabled', () {
    test('a button with nothing to do draws disabled', () {
      expect(morphDisabled(const MorphButton(label: 'Back up'), null), isTrue);
      expect(morphDisabled(const MorphButton(label: 'Back up'), () {}), isFalse);
    });

    test('a bar with no tap only reports, so it never draws disabled', () {
      expect(morphDisabled(const MorphBar(fill: 0.4, label: '40%'), null), isFalse);
      expect(morphDisabled(const MorphBar(fill: null, label: ''), null), isFalse);
    });
  });
}
