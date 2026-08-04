import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';

/// How a period stands in the reflections pager.
enum ReflectionPageStatus {
  /// A stored reflection with text.
  reflected,

  /// A stored silence: the model read the period and had nothing to say.
  silent,

  /// Closed and journaled, but not yet written; the next catch-up may fill it.
  unreflected,

  /// The user deleted this period's reflection (a tombstone); it stays erased
  /// until an explicit regenerate writes it again.
  erased,
}

/// One page of the reflections pager: a closed period and what it holds.
@immutable
final class ReflectionPage {
  const ReflectionPage({required this.periodStart, required this.status, this.reflection});

  /// Civil date of the period's first day; the page's identity.
  final DateTime periodStart;

  final ReflectionPageStatus status;

  /// Non-null iff [status] is reflected or silent.
  final Reflection? reflection;
}

/// The pager's spine for one [period]: every closed period worth a page, OLDEST
/// first, so PageView index 0 is the oldest and the last page is the newest
/// closed period (the landing page). The open period is never a page. All of
/// [history], [journaledStarts], and [deletedStarts] must already belong to
/// [period]; overlap and floor are judged with that period's ranges.
///
/// Candidates are stored reflections (always, even below the no-backfill
/// floor: dev devices hold some), tombstones (erased), and journaled periods. A
/// journaled period only earns a waiting page when nothing range-overlaps it
/// AND it clears the floor exactly like the catch-up does; a below-floor period
/// will never be written, so a waiting page there would wait forever. A null
/// floor means the catch-up has never run, so nothing can fill yet.
List<ReflectionPage> reflectionTimeline({
  required ReflectionPeriod period,
  required List<Reflection> history,
  required Set<DateTime> journaledStarts,
  required List<DateTime> deletedStarts,
  required DateTime? floor,
  required DateTime currentStart,
}) {
  final slots = <DateTime, ReflectionPage>{};
  for (final r in history) {
    if (!r.periodStart.isBefore(currentStart)) continue;
    slots[r.periodStart] = ReflectionPage(
      periodStart: r.periodStart,
      status: r.isSilent ? ReflectionPageStatus.silent : ReflectionPageStatus.reflected,
      reflection: r,
    );
  }
  for (final d in deletedStarts) {
    if (!d.isBefore(currentStart)) continue;
    // A stored row outranks its tombstone (save clears markers, but a
    // locale-shifted key can leave an overlapping stale one).
    if (slots.keys.any((s) => periodsOverlap(s, d, period))) continue;
    slots[d] = ReflectionPage(periodStart: d, status: ReflectionPageStatus.erased);
  }
  for (final w in journaledStarts) {
    if (!w.isBefore(currentStart)) continue;
    if (floor == null || !clearsFloor(w, period, floor)) continue;
    // Range overlap, not exact key: a first-day shift must not put a waiting
    // page beside the same period's stored reflection.
    if (slots.keys.any((s) => periodsOverlap(s, w, period))) continue;
    slots[w] = ReflectionPage(periodStart: w, status: ReflectionPageStatus.unreflected);
  }
  return slots.values.toList()..sort((a, b) => a.periodStart.compareTo(b.periodStart));
}

/// The page showing [viewed]: its index in [timeline], or the last page (the
/// newest closed period) when [viewed] is null or no longer present. -1 only
/// for an empty timeline.
int pageForStart(List<ReflectionPage> timeline, DateTime? viewed) {
  if (timeline.isEmpty) return -1;
  if (viewed == null) return timeline.length - 1;
  for (var i = 0; i < timeline.length; i++) {
    if (timeline[i].periodStart == viewed) return i;
  }
  return timeline.length - 1;
}
