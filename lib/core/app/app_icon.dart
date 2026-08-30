import 'package:flutter/services.dart';

/// The home screen icon over `opentranscribe/icon` (ios/Runner/AppIcon.swift).
/// The OS holds the icon, so there is nothing to persist here: [current]
/// reads what it shows, [set] asks it to change. Nothing leaves the device.
class AppIconStore {
  AppIconStore({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel('opentranscribe/icon');

  final MethodChannel _methods;

  /// The alternate icon's name, or null for the primary icon.
  Future<String?> current() async {
    try {
      return await _methods.invokeMethod<String>('current');
    } on PlatformException catch (e) {
      throw AppIconStoreException(e.message ?? e.code, e.code);
    }
  }

  /// Switches to [iconName], or back to the primary icon for null. iOS shows
  /// its own confirmation; a refusal surfaces as [AppIconStoreException].
  Future<void> set(String? iconName) async {
    try {
      await _methods.invokeMethod<void>('set', {'name': iconName});
    } on PlatformException catch (e) {
      throw AppIconStoreException(e.message ?? e.code, e.code);
    }
  }
}

class AppIconStoreException implements Exception {
  const AppIconStoreException(this.message, [this.code = failed]);

  /// Channel error codes. Cross-boundary contract with AppIcon.swift.
  static const unsupported = 'unsupported';
  static const failed = 'failed';

  final String message;
  final String code;

  @override
  String toString() => 'AppIconStoreException($code: $message)';
}
