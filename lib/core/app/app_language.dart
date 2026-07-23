import 'package:opentranscribe/core/app/local_service.dart';

/// Single source of truth for the app's current language code.
///
/// Persisted in [LocalService] under [key]; falls back to [fallback] when
/// nothing is stored. Read and write the app locale through here so there is
/// one place that owns the key and the default.
abstract final class AppLanguage {
  static const key = 'language';
  static const fallback = 'en';

  /// The current language code from storage, or [fallback].
  static String of(LocalService storage) => storage.readString(key) ?? fallback;

  /// Persists the selected language code.
  static Future<void> set(LocalService storage, String code) => storage.write(key, code);
}
