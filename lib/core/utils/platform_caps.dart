import 'dart:io';

/// Platform capability gates. iOS 26 ships the native Liquid Glass chrome
/// (glass buttons, the button group); older systems get the hand-built
/// fallbacks.
abstract final class PlatformCaps {
  /// TEMP: forces the below-26 fallbacks on, even on iOS 26, so they can be
  /// previewed without a device that lacks native glass. FLIP BACK TO FALSE
  /// before committing - this ships the fallbacks to everyone if left on.
  static const bool _debugForceFallback = false;

  /// Also settable at launch without editing code:
  ///   flutter run --dart-define=FORCE_FALLBACK=true
  static const bool forceFallback = _debugForceFallback || bool.fromEnvironment('FORCE_FALLBACK');

  /// Whether the OS renders native Liquid Glass (iOS 26+), unless
  /// [forceFallback] is asking for the fallbacks anyway. A getter, not a cached
  /// field, so toggling [_debugForceFallback] takes effect on a hot reload.
  static bool get nativeGlass => !forceFallback && Platform.isIOS && _iosMajor >= 26;

  static final int _iosMajor = () {
    // "Version 26.0 (Build 23A5260h)" on iOS.
    final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }();
}
