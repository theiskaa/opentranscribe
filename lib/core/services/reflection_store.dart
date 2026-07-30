import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/reflection.dart';

/// Persists reflections as encrypted JSON in [LocalService], one key per week
/// under the `reflection:` prefix (keyed by the week's yyyy-MM-dd start). Listed
/// straight off the key prefix, like [EntryStore], so there is no separate index
/// to keep in sync.
///
/// Reads are defensive: a single corrupt or schema-incompatible record is
/// skipped, never allowed to hide the rest.
class ReflectionStore {
  ReflectionStore(this._storage);

  final LocalService _storage;

  static const _prefix = 'reflection:';

  String _keyFor(String weekKey) => '$_prefix$weekKey';

  Future<void> save(Reflection reflection) =>
      _storage.writeJson(_keyFor(reflection.weekKey), reflection.toJson());

  Reflection? read(DateTime weekStart) {
    final key = _keyFor(Reflection.keyFor(weekStart));
    try {
      return _storage.readJson(key, Reflection.fromJson);
    } catch (_) {
      return null;
    }
  }

  /// All reflections, newest week first. Corrupt records are skipped.
  List<Reflection> all() {
    final reflections = <Reflection>[];
    for (final key in _storage.findKeysWithPrefix(_prefix)) {
      try {
        final reflection = _storage.readJson(key, Reflection.fromJson);
        if (reflection != null) reflections.add(reflection);
      } catch (_) {
        continue;
      }
    }
    reflections.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return reflections;
  }

  Future<bool> delete(DateTime weekStart) =>
      _storage.delete(_keyFor(Reflection.keyFor(weekStart)));
}
