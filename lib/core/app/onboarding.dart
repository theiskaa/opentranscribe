import 'package:opentranscribe/core/app/local_service.dart';

/// Whether the user has been through onboarding. One place owns the key and
/// the fail-safe default.
abstract final class Onboarding {
  static const key = 'onboarding.done';

  /// True once onboarding completed. An unreadable stored value (key change,
  /// corruption) answers false: showing onboarding again is the harmless
  /// direction.
  static bool isDone(LocalService storage) {
    try {
      return storage.readString(key) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> markDone(LocalService storage) => storage.write(key, 'true');
}
