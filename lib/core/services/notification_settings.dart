import 'package:opentranscribe/core/app/local_service.dart';

// The storage is private and named parameters cannot be, so an initializing
// formal does not apply.
// ignore_for_file: prefer_initializing_formals

/// Persists local-notification preferences, keyed by an opaque notification id
/// supplied by the caller. Generic: it names no feature, so each notification
/// type owns its own key (the reflection nudge's lives in [ReflectionNotifier]).
/// One enabled flag and one fire time per key. LocalService-backed like the
/// other settings holders; reads are defensive and never throw.
class NotificationSettings {
  NotificationSettings({required LocalService storage}) : _storage = storage;

  final LocalService _storage;

  /// The fire time defaults: a civil morning hour, when a just-closed period is
  /// worth reading. Both user-configurable per key.
  static const defaultHour = 9;
  static const defaultMinute = 0;

  /// Off by default: a nudge needs notification permission, requested only when
  /// the user opts in, so a stored-on default would promise a notification that
  /// no permission backs.
  bool enabled(String key) => _read(_enabledKey(key)) == 'true';

  int hour(String key) => _readInt(_hourKey(key), defaultHour, 23);
  int minute(String key) => _readInt(_minuteKey(key), defaultMinute, 59);

  Future<void> setEnabled(String key, bool value) =>
      _storage.write(_enabledKey(key), value ? 'true' : 'false');

  Future<void> setTime(String key, {required int hour, required int minute}) async {
    await _storage.write(_hourKey(key), '${hour.clamp(0, 23)}');
    await _storage.write(_minuteKey(key), '${minute.clamp(0, 59)}');
  }

  String _enabledKey(String key) => 'notify.$key.enabled';
  String _hourKey(String key) => 'notify.$key.hour';
  String _minuteKey(String key) => 'notify.$key.minute';

  /// A stored value out of [0, max] reads as the default, not as its clamp: an
  /// hour of 47 is corruption, and answering 23 would fire at a time the user
  /// never chose.
  int _readInt(String key, int fallback, int max) {
    final parsed = int.tryParse(_read(key) ?? '');
    if (parsed == null || parsed < 0 || parsed > max) return fallback;
    return parsed;
  }

  /// Defensive like the other settings holders: corrupt ciphertext decrypts to
  /// a throw, which must read as absent (the default), never crash a getter.
  String? _read(String key) {
    try {
      return _storage.readString(key);
    } catch (_) {
      return null;
    }
  }
}
