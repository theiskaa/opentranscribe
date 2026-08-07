import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';

/// Persists entry metadata as encrypted JSON in [LocalService], one key per
/// entry under the `entry:` prefix. Audio lives on disk and is managed by the
/// caller; this stores only metadata, listed straight off the key prefix so
/// there is no separate index to keep in sync.
///
/// Reads are defensive: a single corrupt or schema-incompatible record is
/// skipped, never allowed to hide the rest of the journal.
///
/// Load-bearing invariant for the service's read-then-save races (rename,
/// retranscribe): visible state mutates synchronously. SharedPreferences
/// updates its in-memory cache inside the call, so a read issued after a save
/// or delete returns sees that mutation even though the disk flush is async. A
/// replacement backend whose reads lag its writes would silently reopen the
/// ghost-entry hole those call sites guard against. A read issued WHILE a save
/// or delete is in flight may still serve the pre-write snapshot; only a read
/// issued after the write's future completes is guaranteed the mutation.
class EntryStore {
  EntryStore(this._storage);

  final LocalService _storage;

  static const _prefix = 'entry:';

  List<Entry>? _cache;

  String _keyFor(String id) => '$_prefix$id';

  Future<void> save(Entry entry) async {
    _cache = null;
    await _storage.writeJson(_keyFor(entry.id), entry.toJson());
    _cache = null;
  }

  Entry? read(String id) {
    try {
      return _storage.readJson(_keyFor(id), Entry.fromJson);
    } catch (_) {
      return null;
    }
  }

  /// All entries, newest first. Corrupt records are skipped. Ties on [Entry.createdAt]
  /// break by id so ordering is deterministic. Memoized until the next [save] or
  /// [delete]; callers get a shallow copy so mutating the returned list cannot
  /// corrupt the memo.
  List<Entry> all() {
    final cached = _cache;
    if (cached != null) return List.of(cached);
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
    _cache = entries;
    return List.of(entries);
  }

  Future<void> delete(String id) async {
    _cache = null;
    await _storage.delete(_keyFor(id));
    _cache = null;
  }
}
