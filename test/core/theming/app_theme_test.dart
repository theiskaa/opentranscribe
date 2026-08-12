import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/core/theming/screen_colors.dart';

void main() {
  // A theme built purely from base colors, for derivation checks.
  AppTheme derived({ScreenColors? screens, CalendarTheme? calendar}) => AppTheme.fromBase(
    brightness: Brightness.light,
    background: const Color(0xFF000001),
    surface: const Color(0xFF000002),
    surfaceBorder: const Color(0xFF000003),
    text: const Color(0xFF000004),
    textSecondary: const Color(0xFF000005),
    hairline: const Color(0xFF000006),
    accent: const Color(0xFF000007),
    accentPressed: const Color(0xFF000008),
    onAccent: const Color(0xFF000009),
    record: const Color(0xFF00000A),
    danger: const Color(0xFF00000B),
    positive: const Color(0xFF00000E),
    shadow: const Color(0xFF00000C),
    barrier: const Color(0xFF00000D),
    screens: screens,
    calendar: calendar,
  );

  group('fromBase derivation', () {
    test('every screen background falls back to the base background', () {
      final theme = derived();
      expect(theme.screens.onboarding, theme.background);
      expect(theme.screens.home, theme.background);
      expect(theme.screens.recorder, theme.background);
      expect(theme.screens.entryDetail, theme.background);
      expect(theme.screens.settings, theme.background);
    });

    test('component groups derive from the base palette', () {
      final theme = derived();
      expect(theme.button.pressed, theme.accentPressed);
      expect(theme.button.secondaryBackground, theme.surface);
      expect(theme.calendar.cursorBorder, theme.text.withValues(alpha: 0.25));
      expect(theme.calendar.todayDot, theme.text);
      expect(theme.entryList.railColor, theme.hairline);
      expect(theme.entryList.nodeColor, theme.textSecondary);
      expect(theme.player.progress, theme.accent);
      expect(theme.player.waveRemaining, theme.text.withValues(alpha: 0.16));
      expect(theme.settings.cardBackground, theme.surface);
      // A switch's on-state is green, the one hue in the ink app; light gives
      // the iOS system green.
      expect(theme.settings.toggleActive, const Color(0xFF34C759));
      expect(theme.recorder.waveformBar, theme.accent);
      expect(theme.topBar.background, theme.background);
      expect(theme.onboarding.bodyColor, theme.textSecondary);
    });

    test('an override replaces only its group', () {
      const custom = ScreenColors(
        onboarding: Color(0xFF111111),
        home: Color(0xFF222222),
        recorder: Color(0xFF333333),
        entryDetail: Color(0xFF444444),
        settings: Color(0xFF555555),
      );
      final theme = derived(screens: custom);
      expect(theme.screens.home, const Color(0xFF222222));
      // Untouched groups still derive.
      expect(theme.topBar.background, theme.background);
      expect(theme.calendar.tileFill, theme.text.withValues(alpha: 0.04));
    });
  });

  group('built-in themes', () {
    test('defaultLight is proper white with ink text', () {
      final t = AppTheme.defaultLight;
      expect(t.brightness, Brightness.light);
      expect(t.background, const Color(0xFFFFFFFF));
      expect(t.surface, const Color(0xFFF4F4F4));
      expect(t.text, const Color(0xFF111111));
      expect(t.accent, const Color(0xFF111111));
      expect(t.onAccent, const Color(0xFFFFFFFF));
    });

    test('defaultDark is proper neutral dark', () {
      final t = AppTheme.defaultDark;
      expect(t.brightness, Brightness.dark);
      expect(t.background, const Color(0xFF111111));
      expect(t.surface, const Color(0xFF1C1C1E));
      expect(t.text, const Color(0xFFF5F5F5));
      expect(t.onAccent, const Color(0xFF111111));
      // Dark runs the stronger calendar alphas: low-alpha white reads weaker.
      expect(t.calendar.cursorBorder, t.text.withValues(alpha: 0.38));
      expect(t.calendar.tileFill, t.text.withValues(alpha: 0.06));
    });
  });
}
