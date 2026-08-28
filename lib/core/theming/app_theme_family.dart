import 'package:flutter/widgets.dart' show Brightness, Color, immutable;

import 'package:opentranscribe/core/theming/app_theme.dart';

/// A named palette family with a light variant and an optional dark one. The
/// selected family plus the appearance mode resolves to the [AppTheme] the app
/// renders. Every variant is built from [AppTheme.fromBase] - only the base
/// colors differ, so every component token derives the same way across families.
@immutable
final class AppThemeFamily {
  const AppThemeFamily({required this.id, required this.light, this.dark, this.club = false});

  final String id;
  final AppTheme light;

  /// A club look: worn only while the supporter tier says member, the pick
  /// itself stays stored either way.
  final bool club;

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
  static const midnightId = 'midnight';
  static const emberId = 'ember';
  static const forestId = 'forest';
  static const roseId = 'rose';

  /// Every family the app ships, in picker order. Default is the free look;
  /// every other family is the club's.
  static final List<AppThemeFamily> all = List.unmodifiable([
    _default,
    _gruvbox,
    _solarized,
    _sepia,
    _midnight,
    _ember,
    _forest,
    _rose,
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
    club: true,
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
    club: true,
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
    club: true,
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

  static final _midnight = AppThemeFamily(
    id: midnightId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFF6F8FB),
      surface: const Color(0xFFEDF1F7),
      surfaceBorder: const Color(0xFFD9E0EA),
      text: const Color(0xFF14213D),
      textSecondary: const Color(0xFF5B6B85),
      hairline: const Color(0xFFD9E0EA),
      accent: const Color(0xFF2F5BD1),
      accentPressed: const Color(0xFF2447A8),
      onAccent: const Color(0xFFFFFFFF),
      record: const Color(0xFFD64550),
      danger: const Color(0xFFC8323E),
      positive: const Color(0xFF2E8B57),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF0B1220),
      surface: const Color(0xFF141D30),
      surfaceBorder: const Color(0xFF223052),
      text: const Color(0xFFE6ECF7),
      textSecondary: const Color(0xFF8FA0BF),
      hairline: const Color(0xFF223052),
      accent: const Color(0xFF7FA3FF),
      accentPressed: const Color(0xFF5E86E6),
      onAccent: const Color(0xFF0B1220),
      record: const Color(0xFFFF6B6B),
      danger: const Color(0xFFFF6B6B),
      positive: const Color(0xFF6CCB8A),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
  );

  static final _ember = AppThemeFamily(
    id: emberId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFFBF6F0),
      surface: const Color(0xFFF3EBE1),
      surfaceBorder: const Color(0xFFE4D6C6),
      text: const Color(0xFF2C211B),
      textSecondary: const Color(0xFF7A6A5E),
      hairline: const Color(0xFFE4D6C6),
      accent: const Color(0xFFB8432B),
      accentPressed: const Color(0xFF93341F),
      onAccent: const Color(0xFFFFF7F0),
      record: const Color(0xFFC5432E),
      danger: const Color(0xFFB0301F),
      positive: const Color(0xFF5E7F3E),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF1B1512),
      surface: const Color(0xFF261E19),
      surfaceBorder: const Color(0xFF3A2E27),
      text: const Color(0xFFF1E6DA),
      textSecondary: const Color(0xFFA8978A),
      hairline: const Color(0xFF3A2E27),
      accent: const Color(0xFFE2694C),
      accentPressed: const Color(0xFFC3533A),
      onAccent: const Color(0xFF1B1512),
      record: const Color(0xFFF06A50),
      danger: const Color(0xFFF06A50),
      positive: const Color(0xFF9DB56C),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
  );

  static final _forest = AppThemeFamily(
    id: forestId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFF6F9F4),
      surface: const Color(0xFFECF2EA),
      surfaceBorder: const Color(0xFFD3DECF),
      text: const Color(0xFF1C2A1F),
      textSecondary: const Color(0xFF5F7362),
      hairline: const Color(0xFFD3DECF),
      accent: const Color(0xFF2F7A4B),
      accentPressed: const Color(0xFF24603A),
      onAccent: const Color(0xFFFFFFFF),
      record: const Color(0xFFC94C3C),
      danger: const Color(0xFFB33A2C),
      positive: const Color(0xFF2F7A4B),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF0F1712),
      surface: const Color(0xFF18241B),
      surfaceBorder: const Color(0xFF27362B),
      text: const Color(0xFFE4EEE6),
      textSecondary: const Color(0xFF93A697),
      hairline: const Color(0xFF27362B),
      accent: const Color(0xFF6FC48A),
      accentPressed: const Color(0xFF55A56F),
      onAccent: const Color(0xFF0F1712),
      record: const Color(0xFFF0705C),
      danger: const Color(0xFFF0705C),
      positive: const Color(0xFF6FC48A),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
  );

  static final _rose = AppThemeFamily(
    id: roseId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFFBF5F6),
      surface: const Color(0xFFF4E9EC),
      surfaceBorder: const Color(0xFFE6D3D8),
      text: const Color(0xFF2B1C21),
      textSecondary: const Color(0xFF7A5F67),
      hairline: const Color(0xFFE6D3D8),
      accent: const Color(0xFFC2506E),
      accentPressed: const Color(0xFF9E3D58),
      onAccent: const Color(0xFFFFFFFF),
      record: const Color(0xFFCF4A5A),
      danger: const Color(0xFFB8384A),
      positive: const Color(0xFF4E8C5F),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF191114),
      surface: const Color(0xFF241A1E),
      surfaceBorder: const Color(0xFF37292E),
      text: const Color(0xFFF2E4E8),
      textSecondary: const Color(0xFFA88F97),
      hairline: const Color(0xFF37292E),
      accent: const Color(0xFFE8809A),
      accentPressed: const Color(0xFFC96580),
      onAccent: const Color(0xFF191114),
      record: const Color(0xFFF2707A),
      danger: const Color(0xFFF2707A),
      positive: const Color(0xFF8CC79A),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
  );
}
