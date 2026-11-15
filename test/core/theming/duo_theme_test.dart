import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/app_theme_family.dart';
import 'package:opentranscribe/core/theming/contrast.dart';

void main() {
  test('the default selection and pane grounds stay monochrome in both appearances', () {
    for (final theme in [AppTheme.defaultLight, AppTheme.defaultDark]) {
      final duo = theme.duo;
      for (final color in [duo.selectionFill, duo.surfaceGrouped, duo.surfaceElevated]) {
        expect(color.r, color.g);
        expect(color.g, color.b);
      }
      expect(duo.selectionFill.withValues(alpha: 1), theme.text);
      expect(
        duo.selectionFill.a,
        closeTo(theme.brightness == Brightness.dark ? 0.12 : 0.08, 0.001),
      );
    }
  });

  for (final family in AppThemeFamily.all) {
    for (final theme in [family.light, family.darkOrLight]) {
      final dark = theme.brightness == Brightness.dark;
      test('${family.id} ${theme.brightness.name} keeps pane and selection roles readable', () {
        final duo = theme.duo;
        final selected = Color.alphaBlend(duo.selectionFill, duo.surfaceGrouped);
        expect(duo.surfaceGrouped, isNot(theme.background));
        expect(duo.surfaceElevated, isNot(theme.background));
        expect(contrastRatio(theme.text, selected), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(theme.textSecondary, duo.surfaceGrouped), greaterThanOrEqualTo(3));
        expect(duo.separator.a, closeTo(theme.hairline.a * 0.6, 0.001));
        expect(duo.player.progress, theme.accent);
        expect(duo.player.waveRemaining.withValues(alpha: 1), theme.textSecondary);
        if (family.id != AppThemeFamily.defaultId) {
          expect(duo.selectionFill.withValues(alpha: 1), theme.accent);
          expect(duo.selectionFill.a, closeTo(dark ? 0.22 : 0.14, 0.001));
        }
      });
    }
  }
}
