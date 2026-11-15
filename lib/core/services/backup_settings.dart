import 'package:opentranscribe/core/app/local_service.dart';

/// Persists the Backup surface's choices: whether archives are sealed with a
/// passphrase, and when the last archive was saved. Reads fail toward the
/// defaults rather than throw at a settings read, like the other settings
/// holders.
class BackupSettings {
  BackupSettings({required this._storage});

  final LocalService _storage;

  static const _sealKey = 'backup.seal';
  static const _lastArchiveKey = 'backup.lastArchive';

  /// Whether the archive action seals with a passphrase. On by default: a
  /// journal leaving the phone is sealed unless the user opts out.
  bool get seal {
    try {
      return _storage.readString(_sealKey) != 'false';
    } catch (_) {
      return true;
    }
  }

  Future<void> setSeal(bool seal) => _storage.write(_sealKey, seal ? 'true' : 'false');

  /// When the last archive was saved, for the Backup screen's detail line.
  /// Null until a first archive completes.
  DateTime? get lastArchiveAt {
    try {
      final raw = _storage.readString(_lastArchiveKey);
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastArchiveAt(DateTime at) =>
      _storage.write(_lastArchiveKey, at.toUtc().toIso8601String());
}
