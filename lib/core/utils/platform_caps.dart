import 'dart:io';

/// Platform capability gates. iOS 26 ships the native Liquid Glass chrome
/// (glass buttons, the button group); older systems get the hand-built
/// fallbacks.
abstract final class PlatformCaps {
  /// Whether the OS renders native Liquid Glass (iOS 26+).
  static bool get nativeGlass => Platform.isIOS && _iosMajor >= 26;

  static final int _iosMajor = () {
    // "Version 26.0 (Build 23A5260h)" on iOS.
    final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }();
}
