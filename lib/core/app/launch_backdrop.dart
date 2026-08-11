import 'dart:ui' show Color;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:opentranscribe/core/theming/app_theme_family.dart';
import 'package:opentranscribe/core/theming/app_theme_mode.dart';

/// Packs the launch colours native reads before any Dart runs: the mode, then
/// the light and dark background and ink as ARGB hex, comma-separated. One
/// value rather than separate keys, so a family change and a mode change can
/// never interleave into a mismatched set. WaveSplash.swift parses it.
///
/// Both palettes plus the mode, not one resolved colour: the system appearance
/// can flip while the app is terminated, so native resolves against the live
/// trait collection instead of trusting a stale resolution.
String launchBackdropOf({required AppThemeFamily family, required AppThemeMode mode}) {
  final light = family.resolve(wantDark: false);
  final dark = family.resolve(wantDark: true);
  String hex(Color color) => color.toARGB32().toRadixString(16).padLeft(8, '0');
  return [
    mode.name,
    hex(light.background),
    hex(light.text),
    hex(dark.background),
    hex(dark.text),
  ].join(',');
}

/// Mirrors the theme's launch colours into plain `SharedPreferences`, where the
/// native splash can read them before the engine is up. Plain on purpose: a
/// palette colour is not journal data, and anything behind [LocalService] is
/// encrypted under a key derived in Dart, which does not exist yet when the
/// splash draws.
class LaunchBackdrop {
  LaunchBackdrop({Future<SharedPreferences>? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance();

  /// Stored as `flutter.launchBackdrop`: the plugin prefixes every key.
  static const key = 'launchBackdrop';

  final Future<SharedPreferences> _prefs;

  /// Never throws: the mirror is cosmetic, and a failed write must not surface
  /// through the theme change that triggered it. The splash falls back.
  Future<void> write({required AppThemeFamily family, required AppThemeMode mode}) async {
    try {
      await (await _prefs).setString(key, launchBackdropOf(family: family, mode: mode));
    } catch (_) {
      return;
    }
  }
}
