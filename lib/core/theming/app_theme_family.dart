import 'package:flutter/widgets.dart' show Brightness, Color, immutable;

import 'package:opentranscribe/core/theming/app_theme.dart';

/// A named palette family with a light variant and an optional dark one. The
/// selected family plus the appearance mode resolves to the [AppTheme] the app
/// renders. Every variant is built from [AppTheme.fromBase] - only the base
/// colors differ, so every component token derives the same way across families.
@immutable
final class AppThemeFamily {
  const AppThemeFamily({required this.id, required this.light, this.dark});

  final String id;
  final AppTheme light;

  /// Null for a light-only family, which then shows [light] even in dark mode.
  /// Every family currently ships a dark; the capability stays for future ones.
  final AppTheme? dark;

  bool get hasDark => dark != null;

  /// The dark variant, or the light one for a light-only family.
  AppTheme get darkOrLight => dark ?? light;

  AppTheme resolve({required bool wantDark}) => wantDark ? darkOrLight : light;

  static const defaultId = 'default';
  static const gruvboxId = 'gruvbox';
  static const solarizedId = 'solarized';
  static const sepiaId = 'sepia';

  /// Every family the app ships, in picker order.
  static final List<AppThemeFamily> all = List.unmodifiable([
    _default,
    _gruvbox,
    _solarized,
    _sepia,
  ]);

  static AppThemeFamily byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => _default);

  static final _default = AppThemeFamily(
    id: defaultId,
    light: AppTheme.defaultLight,
    dark: AppTheme.defaultDark,
  );

  static final _gruvbox = AppThemeFamily(
    id: gruvboxId,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFFBF1C7),
      surface: const Color(0xFFF2E5BC),
      surfaceBorder: const Color(0xFFD5C4A1),
      text: const Color(0xFF3C3836),
      textSecondary: const Color(0xFF7C6F64),
      hairline: const Color(0xFFD5C4A1),
      accent: const Color(0xFFD65D0E),
      accentPressed: const Color(0xFFAF3A03),
      onAccent: const Color(0xFFFBF1C7),
      record: const Color(0xFFCC241D),
      danger: const Color(0xFF9D0006),
      positive: const Color(0xFF79740E),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF282828),
      surface: const Color(0xFF3C3836),
      surfaceBorder: const Color(0xFF504945),
      text: const Color(0xFFEBDBB2),
      textSecondary: const Color(0xFFA89984),
      hairline: const Color(0xFF504945),
      accent: const Color(0xFFFE8019),
      accentPressed: const Color(0xFFD65D0E),
      onAccent: const Color(0xFF282828),
      record: const Color(0xFFFB4934),
      danger: const Color(0xFFFB4934),
      positive: const Color(0xFFB8BB26),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
  );

  static final _solarized = AppThemeFamily(
    id: solarizedId,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFFDF6E3),
      surface: const Color(0xFFEEE8D5),
      surfaceBorder: const Color(0xFFDCD4BE),
      text: const Color(0xFF586E75),
      // base00, not base1: base1 is too faint on the cream ground for secondary
      // text and the disabled/waveform tokens derived from it.
      textSecondary: const Color(0xFF657B83),
      hairline: const Color(0xFFDDD6C1),
      accent: const Color(0xFF268BD2),
      accentPressed: const Color(0xFF1A6EA8),
      onAccent: const Color(0xFFFDF6E3),
      record: const Color(0xFFDC322F),
      danger: const Color(0xFFDC322F),
      positive: const Color(0xFF859900),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF002B36),
      surface: const Color(0xFF073642),
      surfaceBorder: const Color(0xFF0A3F4A),
      text: const Color(0xFF93A1A1),
      textSecondary: const Color(0xFF657B83),
      hairline: const Color(0xFF0A3F4A),
      accent: const Color(0xFF268BD2),
      accentPressed: const Color(0xFF1A6EA8),
      onAccent: const Color(0xFF002B36),
      record: const Color(0xFFDC322F),
      danger: const Color(0xFFDC322F),
      positive: const Color(0xFF859900),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
  );

  /// A warm reading mode: brown ink on paper by day, warm espresso by night.
  static final _sepia = AppThemeFamily(
    id: sepiaId,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFF4ECD8),
      surface: const Color(0xFFECE0C4),
      surfaceBorder: const Color(0xFFD8C9A8),
      text: const Color(0xFF5B4636),
      textSecondary: const Color(0xFF8A7658),
      hairline: const Color(0xFFDDCFB0),
      accent: const Color(0xFF8A5A2B),
      accentPressed: const Color(0xFF6F4620),
      onAccent: const Color(0xFFF4ECD8),
      record: const Color(0xFFA13D2D),
      danger: const Color(0xFFB3402F),
      positive: const Color(0xFF6D7A3C),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF2A2320),
      surface: const Color(0xFF352C27),
      surfaceBorder: const Color(0xFF45392F),
      text: const Color(0xFFE8DCC4),
      textSecondary: const Color(0xFFA89377),
      hairline: const Color(0xFF45392F),
      accent: const Color(0xFFC8814A),
      accentPressed: const Color(0xFFA0673A),
      onAccent: const Color(0xFF2A2320),
      record: const Color(0xFFCF6A4C),
      danger: const Color(0xFFD1553F),
      positive: const Color(0xFF9FA05F),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
  );
}
