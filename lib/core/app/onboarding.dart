import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/app/local_service.dart';

/// Whether the user has been through onboarding. One place owns the key and
/// the fail-safe default.
abstract final class Onboarding {
  static const key = 'onboarding.done';

  /// Debug rig: while true, [Deps.init] forgets the done mark on every launch,
  /// so onboarding can be walked through on each run while it is reworked.
  /// Finishing still marks it done for the session, so Get started leaves
  /// normally. Const on [kDebugMode]: a release build can never ship with it
  /// live. Set to false once the rework settles.
  static const debugAlwaysShow = kDebugMode;

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
