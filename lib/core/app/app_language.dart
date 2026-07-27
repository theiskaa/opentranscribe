import 'package:opentranscribe/core/app/local_service.dart';

/// Single source of truth for the app's current language code.
///
/// Persisted in [LocalService] under [key]; falls back to [fallback] when
/// nothing is stored. Read and write the app locale through here so there is
/// one place that owns the key and the default.
abstract final class AppLanguage {
  static const key = 'language';
  static const fallback = 'en';

  /// The current language code from storage, or [fallback]. Never throws: this is
  /// read during cubit construction at launch, so an undecryptable or corrupt
  /// record must fail safe to the default rather than crash the app, matching the
  /// other settings readers.
  static String of(LocalService storage) {
    try {
      return storage.readString(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Persists the selected language code.
  static Future<void> set(LocalService storage, String code) => storage.write(key, code);
}
