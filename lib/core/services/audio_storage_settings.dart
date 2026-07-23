import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/audio/audio_recorder.dart';

/// Persists and applies the audio-backup preference. Kept audio is excluded from
/// the device's iCloud/local backup by default, so nothing leaves the phone; the
/// user can opt in. This is the mechanism only; the on/off switch is a later UI.
class AudioStorageSettings {
  AudioStorageSettings({required this._storage, required this._recorder});

  final LocalService _storage;
  final AudioRecorder _recorder;

  // Stored as an encrypted 'true'/'false' string, not a bool: LocalService's bool
  // path is plaintext and has no readBool, so the string keeps the preference
  // encrypted and gives the "excluded unless explicitly 'false'" default.
  static const _key = 'audio.backupExcluded';

  /// Whether kept audio is excluded from backup. Defaults to true (excluded), also
  /// when the stored value cannot be decrypted (key change, corruption): fail safe
  /// toward the one rule rather than throw at a settings read.
  bool get backupExcluded {
    try {
      return _storage.readString(_key) != 'false';
    } catch (_) {
      return true;
    }
  }

  /// Pushes the persisted preference to the native layer. Failures are swallowed:
  /// the native default is already excluded, so a startup hiccup never blocks the
  /// app or weakens the one rule. Logged in debug, since a persistent failure
  /// silently drops a user's backup opt-in.
  Future<void> apply() async {
    try {
      await _recorder.setBackupExcluded(backupExcluded);
    } catch (error) {
      // Native already defaults to excluded; applying the stored value is best-effort.
      if (kDebugMode) debugPrint('AudioStorageSettings.apply failed: $error');
    }
  }

  /// Sets and applies the preference. Persisted so it survives relaunches.
  Future<void> setExcluded(bool excluded) async {
    await _storage.write(_key, excluded ? 'true' : 'false');
    await _recorder.setBackupExcluded(excluded);
  }
}
