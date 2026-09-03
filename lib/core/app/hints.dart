import 'package:opentranscribe/core/app/local_service.dart';

/// The one-shot hints: each shown once, ever. One place owns the keys and the
/// fail-safe default, like `Onboarding`.
abstract final class Hints {
  /// The first opened entry's pointer at its menu.
  static const entryMenu = 'hint.entryMenu';

  /// An unreadable stored value answers false: a hint shown twice is harmless,
  /// one that can never show again is not.
  static bool isSeen(LocalService storage, String key) {
    try {
      return storage.readString(key) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen(LocalService storage, String key) => storage.write(key, 'true');
}
