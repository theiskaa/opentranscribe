import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_theme_family.dart';
import 'package:opentranscribe/core/theming/contrast.dart';

void main() {
  const black = Color(0xFF000000);
  const white = Color(0xFFFFFFFF);
  const grey = Color(0xFF888888);

  double composedContrast(Color faded, Color background) =>
      contrastRatio(Color.alphaBlend(faded, background), background);

  group('contrastRatio', () {
    test('black on white is 21', () {
      expect(contrastRatio(black, white), closeTo(21, 0.01));
      expect(contrastRatio(white, black), closeTo(21, 0.01));
    });

    test('a colour against itself is 1', () {
      expect(contrastRatio(grey, grey), closeTo(1, 0.0001));
    });
  });

  group('fadedAtLeast', () {
    test('an alpha that already clears the floor is left alone', () {
      final faded = fadedAtLeast(black, 0.8, background: white);
      expect(faded.a, closeTo(0.8, 0.0001));
    });

    test('an alpha under the floor is raised just far enough', () {
      final faded = fadedAtLeast(black, 0.2, background: white);
      expect(faded.a, greaterThan(0.2));
      expect(composedContrast(faded, white), greaterThanOrEqualTo(3));
      expect(composedContrast(black.withValues(alpha: faded.a - 0.01), white), lessThan(3));
    });

    test('a raised alpha keeps the ink channels', () {
      final faded = fadedAtLeast(black, 0.2, background: white);
      expect(faded.withValues(alpha: 1), black);
    });

    test('an ink that cannot reach the floor comes back opaque', () {
      final faded = fadedAtLeast(grey, 0.3, background: const Color(0xFF777777));
      expect(faded.a, 1);
    });
  });

  group('every shipped theme', () {
    for (final family in AppThemeFamily.all) {
      for (final (name, theme) in [('light', family.light), ('dark', family.darkOrLight)]) {
        test('${family.id} $name reads its faded live text at 3:1 or better', () {
          expect(
            composedContrast(theme.recorder.liveTextFadedColor, theme.background),
            greaterThanOrEqualTo(3),
          );
        });

        test('${family.id} $name reads an inert day number at 3:1 or better', () {
          expect(
            composedContrast(theme.calendar.disabledDayColor, theme.background),
            greaterThanOrEqualTo(3),
          );
        });
      }
    }
  });
}
