import 'package:opentranscribe/core/app/local_service.dart';

/// Persists the Backup surface's choices: the last-used export format (shared
/// by the entry sheet and the Backup screen, so one choice follows the user),
/// whether archives are sealed with a passphrase, and when the last archive
/// was saved. Reads fail toward the defaults rather than throw at a settings
/// read, like the other settings holders.
class BackupSettings {
  BackupSettings({required this._storage, required this.fallbackFormatId});

  final LocalService _storage;

  /// The id answered when nothing is stored, injected by the composition
  /// root: a settings holder never names a format itself.
  final String fallbackFormatId;

  static const _formatKey = 'backup.format';
  static const _sealKey = 'backup.seal';
  static const _lastArchiveKey = 'backup.lastArchive';

  /// The last-used exporter id. The caller resolves an id that no longer
  /// exists (a removed format) against its registry; this is just the memory.
  String get formatId {
    try {
      return _storage.readString(_formatKey) ?? fallbackFormatId;
    } catch (_) {
      return fallbackFormatId;
    }
  }

  Future<void> setFormatId(String id) => _storage.write(_formatKey, id);

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
