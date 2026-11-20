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
    }
  });

  for (final family in AppThemeFamily.all) {
    for (final theme in [family.light, family.darkOrLight]) {
      final dark = theme.brightness == Brightness.dark;
      test('${family.id} ${theme.brightness.name} keeps pane and selection roles readable', () {
        final duo = theme.duo;
        final selected = Color.alphaBlend(duo.selectionFill, duo.surfaceGrouped);
        final tint = Color.alphaBlend(
          theme.text.withValues(alpha: dark ? 0.06 : 0.04),
          theme.background,
        );
        expect(duo.surfaceGrouped, tint);
        expect(duo.surfaceElevated, tint);
        expect(contrastRatio(selected, duo.surfaceGrouped), greaterThanOrEqualTo(1.2));
        expect(
          contrastRatio(Color.alphaBlend(duo.selectedMetadata, selected), selected),
          greaterThanOrEqualTo(4.5),
        );
        expect(duo.selectedMetadata.withValues(alpha: 1), theme.text);
        expect(duo.selectedMetadata.a, greaterThanOrEqualTo(0.70));
        expect(duo.speedSurface, theme.surface);
        expect(contrastRatio(theme.text, duo.speedSurface), greaterThanOrEqualTo(4.5));
        expect(
          contrastRatio(
            Color.alphaBlend(duo.speedBorder, duo.surfaceElevated),
            duo.surfaceElevated,
          ),
          greaterThanOrEqualTo(1.2),
        );
        expect(contrastRatio(theme.text, selected), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(theme.textSecondary, duo.surfaceGrouped), greaterThanOrEqualTo(3));
        expect(duo.separator.a, closeTo(theme.hairline.a * 0.6, 0.001));
        expect(duo.separator.withValues(alpha: 1), theme.hairline.withValues(alpha: 1));
        expect(duo.player.progress, theme.accent);
        expect(contrastRatio(theme.onAccent, theme.accent), greaterThanOrEqualTo(4.5));
        expect(duo.player.waveRemaining.withValues(alpha: 1), theme.textSecondary);
        if (family.id != AppThemeFamily.defaultId) {
          expect(duo.selectionFill.withValues(alpha: 1), theme.accent);
          expect(duo.selectionFill.a, greaterThanOrEqualTo(dark ? 0.30 : 0.20));
        }
      });
    }
  }
}
