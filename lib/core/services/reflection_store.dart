import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:reflections/reflections.dart';

/// Persists reflections as encrypted JSON in [LocalService], one key per record
/// as `reflection:<period>:<yyyy-MM-dd>`. Listed straight off the key prefix,
/// like [EntryStore], so there is no separate index to keep in sync. The period
/// segment keeps a day, its week, and its month distinct even when their start
/// dates coincide.
///
/// A [delete] leaves a tombstone under its own prefix: the user erased that
/// period's record, and the catch-up honors the erasure instead of quietly
/// re-reflecting a period whose entries still exist. [save] clears the marker,
/// so a tombstone and a row never coexist.
///
/// Reads are defensive: a single corrupt or schema-incompatible record is
/// skipped, never allowed to hide the rest.
class ReflectionStore {
  ReflectionStore(this._storage);

  final LocalService _storage;

  static const _prefix = 'reflection:';
  static const _deletedPrefix = 'reflection.deleted:';

  String _rowKey(ReflectionPeriod period, String dateKey) => '$_prefix${period.wire}:$dateKey';

  String _deletedKey(ReflectionPeriod period, String dateKey) =>
      '$_deletedPrefix${period.wire}:$dateKey';

  Future<void> save(Reflection reflection) async {
    final dateKey = reflection.periodKey;
    // Row before marker: a failure between the writes then leaves both behind
    // (the fresh row wins) instead of neither, which would read as an erased
    // period for the catch-up to quietly refill.
    await _storage.writeJson(_rowKey(reflection.period, dateKey), reflection.toJson());
    await _storage.delete(_deletedKey(reflection.period, dateKey));
  }

  Reflection? read(DateTime start, {ReflectionPeriod period = ReflectionPeriod.weekly}) {
    final key = _rowKey(period, Reflection.keyFor(start));
    try {
      return _storage.readJson(key, Reflection.fromJson);
    } catch (_) {
      return null;
    }
  }

  /// All reflections, newest start first, ties broken by period (day, week,
  /// month) so the order is deterministic when a day and its week share a start.
  /// Corrupt records are skipped.
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
    reflections.sort((a, b) {
      final byStart = b.periodStart.compareTo(a.periodStart);
      return byStart != 0 ? byStart : a.period.index.compareTo(b.period.index);
    });
    return reflections;
  }

  /// Removes a period's reflection and records the removal as a tombstone.
  Future<bool> delete(DateTime start, {ReflectionPeriod period = ReflectionPeriod.weekly}) async {
    final dateKey = Reflection.keyFor(start);
    await _storage.write(_deletedKey(period, dateKey), dateKey);
    return _storage.delete(_rowKey(period, dateKey));
  }

  /// The period starts the user deleted, unordered. Unparseable markers are
  /// skipped like corrupt rows.
  List<({ReflectionPeriod period, DateTime start})> deletedRefs() {
    final refs = <({ReflectionPeriod period, DateTime start})>[];
    for (final key in _storage.findKeysWithPrefix(_deletedPrefix)) {
      final ref = _parseRef(key.substring(_deletedPrefix.length));
      if (ref != null) refs.add(ref);
    }
    return refs;
  }

  /// The week starts the user deleted, unordered. The weekly slice of
  /// [deletedRefs], kept for callers that only know weeks.
  List<DateTime> deletedWeeks() => [
    for (final ref in deletedRefs())
      if (ref.period == ReflectionPeriod.weekly) ref.start,
  ];

  ({ReflectionPeriod period, DateTime start})? _parseRef(String remainder) {
    final colon = remainder.indexOf(':');
    if (colon < 0) return null;
    final period = ReflectionPeriod.fromWire(remainder.substring(0, colon));
    final start = DateTime.tryParse(remainder.substring(colon + 1));
    if (period == null || start == null) return null;
    return (period: period, start: start);
  }
}
