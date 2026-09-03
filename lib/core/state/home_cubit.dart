import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/utils/identical_elements.dart';

/// One calendar day's entries, newest first.
typedef DaySection = ({DateTime day, List<Entry> entries});

/// Groups entries by their LOCAL calendar day, sections newest first. A day
/// without entries has no section, which is the splitter-skipping rule: the
/// list renders sections, so empty days can never appear.
List<DaySection> groupByLocalDay(List<Entry> entries) {
  final byDay = <DateTime, List<Entry>>{};
  for (final entry in entries) {
    final local = entry.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(day, () => []).add(entry);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final day in days) (day: day, entries: byDay[day]!)];
}

/// The earliest local day carrying an entry, bounding how far the calendar
/// scrolls into the past. Null when the journal is empty.
DateTime? earliestEntryDay(List<Entry> entries) {
  DateTime? earliest;
  for (final entry in entries) {
    final local = entry.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (earliest == null || day.isBefore(earliest)) earliest = day;
  }
  return earliest;
}

/// The local days that have at least one entry, for the calendar's enabled
/// days.
Set<DateTime> daysWithEntries(List<Entry> entries) {
  return {
    for (final entry in entries)
      () {
        final local = entry.createdAt.toLocal();
        return DateTime(local.year, local.month, local.day);
      }(),
  };
}

/// The home screen's state: the journal's entries. The list always shows all
/// of them; the calendar navigates rather than filters.
@immutable
final class HomeState {
  HomeState({required this.entries})
    : sections = groupByLocalDay(entries),
      entryDays = daysWithEntries(entries),
      firstEntryDay = earliestEntryDay(entries);

  final List<Entry> entries;

  /// Derived once, at construction: home reads these several times per rebuild
  /// while scrolling, and a per-read getter would hand out a fresh [entryDays]
  /// Set each time, so nothing downstream could short-circuit on identity.
  final List<DaySection> sections;
  final Set<DateTime> entryDays;
  final DateTime? firstEntryDay;

  // Entries compare by identity (the derived fields follow from them): the
  // store keeps unchanged entries' identity, so a no-op refresh compares equal.
  @override
  bool operator ==(Object other) => other is HomeState && identicalElements(other.entries, entries);

  // Length only: == holds across distinct lists with the same elements, so
  // the list's own identity hash would break equal-implies-same-hash.
  @override
  int get hashCode => entries.length.hashCode;
}

/// Feeds the home screen: the entry list and the day filter. Auto-finalized
/// entries (interruption saves) refresh the data here; the visible notice for
/// them is separate glue.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required TranscriptionService service})
    : _service = service,
      super(HomeState(entries: service.entries())) {
    _autoSub = _service.autoFinalized.listen((_) => load(), onError: (Object _) {});
    // Detached discards mutate the store without a navigation to refresh on.
    _changesSub = _service.entriesChanged.listen((_) => load(), onError: (Object _) {});
  }

  final TranscriptionService _service;
  late final StreamSubscription<Entry> _autoSub;
  late final StreamSubscription<void> _changesSub;

  /// Ids removed optimistically whose on-device delete is still in flight. Every
  /// emit filters these out, so a concurrent delete's reconcile (or an
  /// auto-finalize refresh) can never resurrect a row that is on its way out.
  final Set<String> _pendingDeletes = {};

  void load() {
    // Also reached from detached continuations (a recorder sheet's exit); the
    // guard keeps those safe even though this cubit is app-scoped today.
    if (isClosed) return;
    final visible = _visible();
    // Constructing a HomeState re-derives the day grouping; an unchanged
    // journal should not pay for it. HomeState's own == covers comparers;
    // this return covers the derive cost.
    if (identicalElements(visible, state.entries)) return;
    emit(HomeState(entries: visible));
  }

  List<Entry> _visible() =>
      _service.entries().where((e) => !_pendingDeletes.contains(e.id)).toList();

  /// Deletes an entry (audio and metadata). Reached from a row's swipe-to-delete
  /// action. Optimistic: the entry leaves the list at once, then the on-device
  /// delete runs and the list reconciles with the stored truth. Idempotent - a
  /// second fire for the same entry (a fast double-tap) is ignored.
  Future<void> delete(Entry entry) async {
    if (!_pendingDeletes.add(entry.id)) return;
    load();
    try {
      await _service.deleteEntry(entry);
    } catch (e) {
      // A delete that failed with the file still on disk kept the record (so the
      // reconcile sweep cannot resurrect it); the finally restores the row.
      // Home has no error surface, so the returning row is the only signal.
      if (kDebugMode) debugPrint('home: delete failed: $e');
    } finally {
      _pendingDeletes.remove(entry.id);
      load();
    }
  }

  @override
  Future<void> close() async {
    await _autoSub.cancel();
    await _changesSub.cancel();
    return super.close();
  }
}
