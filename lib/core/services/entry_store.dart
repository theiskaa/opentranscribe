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
/// retranscribe): visible state mutates synchronously. A save or delete
/// updates the cache before awaiting the backing write, and a read that falls
/// through to SharedPreferences sees the write in its in-memory copy, which
/// the call updates before the disk flush. A replacement backend whose reads
/// lag its writes would silently reopen the ghost-entry hole those call sites
/// guard against.
class EntryStore {
  EntryStore(this._storage);

  final LocalService _storage;

  static const _prefix = 'entry:';

  List<Entry>? _cache;

  /// Bumped by every write, so [warm] can tell its snapshot went stale.
  int _generation = 0;

  String _keyFor(String id) => '$_prefix$id';

  /// Newest first; ties on [Entry.createdAt] break by id so ordering is
  /// deterministic.
  static int _byRecency(Entry a, Entry b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }

  /// Applied before the write is awaited, in lockstep with the backing
  /// store's own in-memory copy, so overlapping writes stay correct in
  /// whatever order the disk acknowledges them.
  void _put(Entry entry) {
    final cached = _cache;
    if (cached == null) return;
    cached.removeWhere((e) => e.id == entry.id);
    final at = cached.indexWhere((e) => _byRecency(e, entry) >= 0);
    cached.insert(at < 0 ? cached.length : at, entry);
  }

  void _drop(String id) => _cache?.removeWhere((e) => e.id == id);

  Future<void> save(Entry entry) async {
    _generation++;
    _put(entry);
    try {
      await _storage.writeJson(_keyFor(entry.id), entry.toJson());
    } catch (_) {
      // Storage truth unknown; the next read rebuilds from the backing store.
      _cache = null;
      rethrow;
    }
  }

  Entry? read(String id) {
    try {
      return _storage.readJson(_keyFor(id), Entry.fromJson);
    } catch (_) {
      return null;
    }
  }

  /// Builds the cache on a worker isolate, so the first [all] pays no
  /// whole-journal decrypt on the frames the user is watching. Anything
  /// landing meanwhile wins: a write, or a cache a synchronous [all] already
  /// built, discards the warmed list.
  Future<void> warm() async {
    if (_cache != null) return;
    final generation = _generation;
    final entries = await _storage.readAllOnIsolate(_prefix, Entry.fromJson);
    if (entries == null || _cache != null || _generation != generation) return;
    _cache = entries..sort(_byRecency);
  }

  /// All entries, newest first. Corrupt records are skipped. Cached, and a
  /// [save] or [delete] updates the cache in place rather than dropping it, so
  /// a single write never costs a whole-journal decrypt. Callers get a shallow
  /// copy so mutating the returned list cannot corrupt the cache, and
  /// unchanged entries keep their object identity while the cache stands.
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
    entries.sort(_byRecency);
    _cache = entries;
    return List.of(entries);
  }

  Future<void> delete(String id) async {
    _generation++;
    _drop(id);
    try {
      await _storage.delete(_keyFor(id));
    } catch (_) {
      // Storage truth unknown; the next read rebuilds from the backing store.
      _cache = null;
      rethrow;
    }
  }
}
