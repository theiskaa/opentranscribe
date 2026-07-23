import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';

/// Persists entry metadata as encrypted JSON in [LocalService], one key per
/// entry under the `entry:` prefix. Audio lives on disk and is managed by the
/// caller; this stores only metadata, listed straight off the key prefix so
/// there is no separate index to keep in sync.
///
/// Reads are defensive: a single corrupt or schema-incompatible record is
/// skipped, never allowed to hide the rest of the journal.
class EntryStore {
  EntryStore(this._storage);

  final LocalService _storage;

  static const _prefix = 'entry:';

  String _keyFor(String id) => '$_prefix$id';

  Future<void> save(Entry entry) => _storage.writeJson(_keyFor(entry.id), entry.toJson());

  Entry? read(String id) {
    try {
      return _storage.readJson(_keyFor(id), Entry.fromJson);
    } catch (_) {
      return null;
    }
  }

  /// All entries, newest first. Corrupt records are skipped. Ties on [Entry.createdAt]
  /// break by id so ordering is deterministic.
  List<Entry> all() {
    final entries = <Entry>[];
    for (final key in _storage.findKeysWithPrefix(_prefix)) {
      try {
        final entry = _storage.readJson(key, Entry.fromJson);
        if (entry != null) entries.add(entry);
      } catch (_) {
        continue;
      }
    }
    entries.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return entries;
  }

  Future<void> delete(String id) => _storage.delete(_keyFor(id));
}
