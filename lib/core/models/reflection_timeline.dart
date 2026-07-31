import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/utils/week.dart';

/// How a week stands in the reflections pager.
enum ReflectionWeekStatus {
  /// A stored reflection with text.
  reflected,

  /// A stored silence: the model read the week and had nothing to say.
  silent,

  /// Closed and journaled, but not yet written; the next catch-up may fill it.
  unreflected,

  /// The user deleted this week's reflection (a tombstone); it stays erased
  /// until an explicit regenerate writes it again.
  erased,
}

/// One page of the reflections pager: a closed week and what it holds.
@immutable
final class ReflectionWeek {
  const ReflectionWeek({required this.weekStart, required this.status, this.reflection});

  /// Civil date of the week's first day; the page's identity.
  final DateTime weekStart;

  final ReflectionWeekStatus status;

  /// Non-null iff [status] is reflected or silent.
  final Reflection? reflection;
}

/// The pager's spine: every closed week worth a page, OLDEST first, so
/// PageView index 0 is the oldest week and the last page is the newest closed
/// week (the landing page). The open week is never a page.
///
/// Candidates are stored reflections (always, even below the no-backfill
/// floor: dev devices hold some), tombstones (erased), and journaled weeks. A
/// journaled week only earns a waiting page when nothing range-overlaps it AND
/// it clears the floor exactly like the catch-up does; a below-floor week will
/// never be written, so a waiting page there would wait forever. A null floor
/// means the catch-up has never run, so nothing can fill yet.
List<ReflectionWeek> reflectionTimeline({
  required List<Reflection> history,
  required Set<DateTime> journaledWeeks,
  required List<DateTime> deletedWeeks,
  required DateTime? floor,
  required DateTime currentWeekStart,
}) {
  final weeks = <DateTime, ReflectionWeek>{};
  for (final r in history) {
    if (!r.weekStart.isBefore(currentWeekStart)) continue;
    weeks[r.weekStart] = ReflectionWeek(
      weekStart: r.weekStart,
      status: r.isSilent ? ReflectionWeekStatus.silent : ReflectionWeekStatus.reflected,
      reflection: r,
    );
  }
  for (final d in deletedWeeks) {
    if (!d.isBefore(currentWeekStart)) continue;
    // A stored row outranks its tombstone (save clears markers, but a
    // locale-shifted key can leave an overlapping stale one).
    if (weeks.keys.any((w) => weeksOverlap(w, d))) continue;
    weeks[d] = ReflectionWeek(weekStart: d, status: ReflectionWeekStatus.erased);
  }
  for (final w in journaledWeeks) {
    if (!w.isBefore(currentWeekStart)) continue;
    if (floor == null || !weekClearsFloor(w, floor)) continue;
    // Range overlap, not exact key: a first-day-of-week shift must not put a
    // waiting page beside the same week's stored reflection.
    if (weeks.keys.any((k) => weeksOverlap(k, w))) continue;
    weeks[w] = ReflectionWeek(weekStart: w, status: ReflectionWeekStatus.unreflected);
  }
  return weeks.values.toList()..sort((a, b) => a.weekStart.compareTo(b.weekStart));
}

/// The page showing [viewed]: its index in [timeline], or the last page (the
/// newest closed week) when [viewed] is null or no longer present. -1 only for
/// an empty timeline.
int pageForWeek(List<ReflectionWeek> timeline, DateTime? viewed) {
  if (timeline.isEmpty) return -1;
  if (viewed == null) return timeline.length - 1;
  for (var i = 0; i < timeline.length; i++) {
    if (timeline[i].weekStart == viewed) return i;
  }
  return timeline.length - 1;
}
