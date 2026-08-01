import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/reflection.dart';

/// Persists reflections as encrypted JSON in [LocalService], one key per week
/// under the `reflection:` prefix (keyed by the week's yyyy-MM-dd start). Listed
/// straight off the key prefix, like [EntryStore], so there is no separate index
/// to keep in sync.
///
/// A [delete] leaves a tombstone under its own prefix: the user erased that
/// week's record, and the catch-up honors the erasure instead of quietly
/// re-reflecting a week whose entries still exist. [save] clears the marker, so
/// a tombstone and a row never coexist.
///
/// Reads are defensive: a single corrupt or schema-incompatible record is
/// skipped, never allowed to hide the rest.
class ReflectionStore {
  ReflectionStore(this._storage);

  final LocalService _storage;

  static const _prefix = 'reflection:';
  static const _deletedPrefix = 'reflection.deleted:';

  String _keyFor(String weekKey) => '$_prefix$weekKey';

  String _deletedKeyFor(String weekKey) => '$_deletedPrefix$weekKey';

  Future<void> save(Reflection reflection) async {
    // Row before marker: a failure between the writes then leaves both behind
    // (the fresh row wins) instead of neither, which would read as an erased
    // week for the catch-up to quietly refill.
    await _storage.writeJson(_keyFor(reflection.weekKey), reflection.toJson());
    await _storage.delete(_deletedKeyFor(reflection.weekKey));
  }

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

  /// Removes a week's reflection and records the removal as a tombstone.
  Future<bool> delete(DateTime weekStart) async {
    final weekKey = Reflection.keyFor(weekStart);
    await _storage.write(_deletedKeyFor(weekKey), weekKey);
    return _storage.delete(_keyFor(weekKey));
  }

  /// The week starts the user deleted, unordered. Unparseable markers are
  /// skipped like corrupt rows.
  List<DateTime> deletedWeeks() {
    final weeks = <DateTime>[];
    for (final key in _storage.findKeysWithPrefix(_deletedPrefix)) {
      final week = DateTime.tryParse(key.substring(_deletedPrefix.length));
      if (week != null) weeks.add(week);
    }
    return weeks;
  }
}
