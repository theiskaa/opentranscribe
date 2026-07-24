import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';

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

  /// Derived once, at construction. As getters these ran on every read, and
  /// home reads them several times per rebuild while scrolling; [entryDays]
  /// also handed out a fresh Set each time, so nothing downstream could ever
  /// short-circuit on it.
  final List<DaySection> sections;
  final Set<DateTime> entryDays;
  final DateTime? firstEntryDay;
}

/// Feeds the home screen: the entry list and the day filter. Auto-finalized
/// entries (interruption saves) refresh the data here; the visible notice for
/// them is separate glue.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required TranscriptionService service})
    : _service = service,
      super(HomeState(entries: service.entries())) {
    _autoSub = _service.autoFinalized.listen((_) => load(), onError: (Object _) {});
  }

  final TranscriptionService _service;
  late final StreamSubscription<Entry> _autoSub;

  void load() => emit(HomeState(entries: _service.entries()));

  @override
  Future<void> close() async {
    await _autoSub.cancel();
    return super.close();
  }
}
