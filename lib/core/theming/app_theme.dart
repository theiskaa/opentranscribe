import 'package:flutter/cupertino.dart';

/// Design tokens for a calm, typography-forward, Apple-style look. No Material.
/// Colors resolve to light or dark from the platform brightness.
@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.hairline,
    required this.accent,
    required this.onAccent,
    required this.record,
    required this.danger,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color hairline;
  final Color accent;
  final Color onAccent;
  final Color record;
  final Color danger;

  static const light = AppColors(
    background: Color(0xFFFBFAF7),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF1B1A17),
    muted: Color(0xFF8C8A83),
    hairline: Color(0xFFE9E6DF),
    accent: Color(0xFF2B2A27),
    onAccent: Color(0xFFFBFAF7),
    record: Color(0xFFCE5A4E),
    danger: Color(0xFFC0392B),
  );

  static const dark = AppColors(
    background: Color(0xFF121211),
    surface: Color(0xFF1D1D1B),
    text: Color(0xFFF1EFE9),
    muted: Color(0xFF908E86),
    hairline: Color(0xFF2C2B28),
    accent: Color(0xFFEDEBE4),
    onAccent: Color(0xFF121211),
    record: Color(0xFFDD6A5D),
    danger: Color(0xFFE1685A),
  );

  static AppColors of(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark ? dark : light;
}

/// Spacing scale, in logical pixels.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 40.0;
}

/// Corner radii.
abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const pill = 999.0;
}

/// Text styles, colored from the resolved [AppColors].
abstract final class AppText {
  static TextStyle largeTitle(BuildContext context) => TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.of(context).text,
  );

  static TextStyle heading(BuildContext context) => TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.of(context).text,
  );

  static TextStyle body(BuildContext context) =>
      TextStyle(fontSize: 16, height: 1.45, color: AppColors.of(context).text);

  static TextStyle caption(BuildContext context) =>
      TextStyle(fontSize: 13, color: AppColors.of(context).muted);

  static TextStyle button(BuildContext context) =>
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
}

/// Builds the CupertinoApp theme from the tokens.
CupertinoThemeData appCupertinoTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: colors.accent,
    scaffoldBackgroundColor: colors.background,
    barBackgroundColor: colors.background,
    textTheme: CupertinoTextThemeData(
      primaryColor: colors.accent,
      textStyle: TextStyle(fontSize: 16, color: colors.text),
    ),
  );
}
