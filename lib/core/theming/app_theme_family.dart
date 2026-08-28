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
  static const sepiaId = 'sepia';
  static const midnightId = 'midnight';
  static const draculaId = 'dracula';
  static const nordId = 'nord';
  static const catppuccinId = 'catppuccin';
  static const tokyoNightId = 'tokyoNight';

  /// Every family the app ships, in picker order. Default is the free look;
  /// every other family is the club's.
  static final List<AppThemeFamily> all = List.unmodifiable([
    _default,
    _gruvbox,
    _midnight,
    _dracula,
    _sepia,
    _nord,
    _catppuccin,
    _tokyoNight,
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
      textSecondary: const Color(0xFF665C54),
      hairline: const Color(0xFFEBDBB2),
      accent: const Color(0xFFAF3A03),
      accentPressed: const Color(0xFF8A2E02),
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
      textSecondary: const Color(0xFFBDAE93),
      hairline: const Color(0xFF3C3836),
      accent: const Color(0xFFFE8019),
      accentPressed: const Color(0xFFD65D0E),
      onAccent: const Color(0xFF282828),
      record: const Color(0xFFFB4934),
      danger: const Color(0xFFFB4934),
      positive: const Color(0xFFB8BB26),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
      onDanger: const Color(0xFF282828),
    ),
  );
  static final _sepia = AppThemeFamily(
    id: sepiaId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFF4ECD8),
      surface: const Color(0xFFECE0C4),
      surfaceBorder: const Color(0xFFD8C9A8),
      text: const Color(0xFF5B4636),
      textSecondary: const Color(0xFF745F44),
      hairline: const Color(0xFFE6DABD),
      accent: const Color(0xFF8A5A2B),
      accentPressed: const Color(0xFF6F4620),
      onAccent: const Color(0xFFF4ECD8),
      record: const Color(0xFFA13D2D),
      danger: const Color(0xFFB3402F),
      positive: const Color(0xFF5D6A30),
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
      danger: const Color(0xFFE0684F),
      positive: const Color(0xFF9FA05F),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
      onDanger: const Color(0xFF2A2320),
    ),
  );
  static final _midnight = AppThemeFamily(
    id: midnightId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFF6F8FB),
      surface: const Color(0xFFE9EEF5),
      surfaceBorder: const Color(0xFFCFD8E4),
      text: const Color(0xFF14213D),
      textSecondary: const Color(0xFF5B6B85),
      hairline: const Color(0xFFD9E0EA),
      accent: const Color(0xFF2F5BD1),
      accentPressed: const Color(0xFF2447A8),
      onAccent: const Color(0xFFF6F8FB),
      record: const Color(0xFFD64550),
      danger: const Color(0xFFC8323E),
      positive: const Color(0xFF237A4A),
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
      onDanger: const Color(0xFF0B1220),
    ),
  );

  static final _dracula = AppThemeFamily(
    id: draculaId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFFFFBEB),
      surface: const Color(0xFFF5F0DB),
      surfaceBorder: const Color(0xFFE3DDC3),
      text: const Color(0xFF1F1F1F),
      textSecondary: const Color(0xFF6C664B),
      hairline: const Color(0xFFE3DDC3),
      accent: const Color(0xFF644AC9),
      accentPressed: const Color(0xFF5038A8),
      onAccent: const Color(0xFFFFFBEB),
      record: const Color(0xFFCB3A2A),
      danger: const Color(0xFFCB3A2A),
      positive: const Color(0xFF14710A),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF282A36),
      surface: const Color(0xFF343746),
      surfaceBorder: const Color(0xFF44475A),
      text: const Color(0xFFF8F8F2),
      textSecondary: const Color(0xFF9AA5CC),
      hairline: const Color(0xFF44475A),
      accent: const Color(0xFFBD93F9),
      accentPressed: const Color(0xFFA57BF0),
      onAccent: const Color(0xFF282A36),
      record: const Color(0xFFFF5555),
      danger: const Color(0xFFFF5555),
      positive: const Color(0xFF50FA7B),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
      onDanger: const Color(0xFF282A36),
    ),
  );

  static final _nord = AppThemeFamily(
    id: nordId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFECEFF4),
      surface: const Color(0xFFE5E9F0),
      surfaceBorder: const Color(0xFFCBD1DD),
      text: const Color(0xFF2E3440),
      textSecondary: const Color(0xFF4C566A),
      hairline: const Color(0xFFD8DEE9),
      accent: const Color(0xFF4C6A94),
      accentPressed: const Color(0xFF3B5C86),
      onAccent: const Color(0xFFECEFF4),
      record: const Color(0xFFA54A54),
      danger: const Color(0xFFA54A54),
      positive: const Color(0xFF4F6B3F),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF2E3440),
      surface: const Color(0xFF3B4252),
      surfaceBorder: const Color(0xFF434C5E),
      text: const Color(0xFFECEFF4),
      textSecondary: const Color(0xFFB0B8C8),
      hairline: const Color(0xFF434C5E),
      accent: const Color(0xFF88C0D0),
      accentPressed: const Color(0xFF81A1C1),
      onAccent: const Color(0xFF2E3440),
      record: const Color(0xFFBF616A),
      danger: const Color(0xFFBF616A),
      positive: const Color(0xFFA3BE8C),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
  );

  static final _catppuccin = AppThemeFamily(
    id: catppuccinId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFEFF1F5),
      surface: const Color(0xFFE6E9EF),
      surfaceBorder: const Color(0xFFCCD0DA),
      text: const Color(0xFF4C4F69),
      textSecondary: const Color(0xFF5C5F77),
      hairline: const Color(0xFFCCD0DA),
      accent: const Color(0xFF8839EF),
      accentPressed: const Color(0xFF7226D6),
      onAccent: const Color(0xFFEFF1F5),
      record: const Color(0xFFD20F39),
      danger: const Color(0xFFD20F39),
      positive: const Color(0xFF40A02B),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF1E1E2E),
      surface: const Color(0xFF313244),
      surfaceBorder: const Color(0xFF45475A),
      text: const Color(0xFFCDD6F4),
      textSecondary: const Color(0xFFA6ADC8),
      hairline: const Color(0xFF45475A),
      accent: const Color(0xFFCBA6F7),
      accentPressed: const Color(0xFFB4BEFE),
      onAccent: const Color(0xFF1E1E2E),
      record: const Color(0xFFF38BA8),
      danger: const Color(0xFFF38BA8),
      positive: const Color(0xFFA6E3A1),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
      onDanger: const Color(0xFF1E1E2E),
    ),
  );

  static final _tokyoNight = AppThemeFamily(
    id: tokyoNightId,
    club: true,
    light: AppTheme.fromBase(
      brightness: Brightness.light,
      background: const Color(0xFFE1E2E7),
      surface: const Color(0xFFD0D5E3),
      surfaceBorder: const Color(0xFFB9BED0),
      text: const Color(0xFF343B58),
      textSecondary: const Color(0xFF52586F),
      hairline: const Color(0xFFC4C8DA),
      accent: const Color(0xFF3760BF),
      accentPressed: const Color(0xFF2E4FA3),
      onAccent: const Color(0xFFFFFFFF),
      record: const Color(0xFFF52A65),
      danger: const Color(0xFFF52A65),
      positive: const Color(0xFF587539),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
    ),
    dark: AppTheme.fromBase(
      brightness: Brightness.dark,
      background: const Color(0xFF1A1B26),
      surface: const Color(0xFF24283B),
      surfaceBorder: const Color(0xFF414868),
      text: const Color(0xFFC0CAF5),
      textSecondary: const Color(0xFF9AA5CE),
      hairline: const Color(0xFF414868),
      accent: const Color(0xFF7AA2F7),
      accentPressed: const Color(0xFF6A8FE0),
      onAccent: const Color(0xFF1A1B26),
      record: const Color(0xFFF7768E),
      danger: const Color(0xFFF7768E),
      positive: const Color(0xFF9ECE6A),
      shadow: const Color(0xFF000000),
      barrier: const Color(0x73000000),
      onDanger: const Color(0xFF1A1B26),
    ),
  );
}
