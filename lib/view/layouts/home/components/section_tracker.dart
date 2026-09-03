import 'package:flutter/widgets.dart';

/// How far a day may fall back below the reading line before it gives the
/// title up, so settle jitter of a few pixels can never flap the answer.
const double titleDeadband = 12;

/// The day owning the title at [offset], decided against the accumulated
/// [starts] (scroll-space start per day splitter label), which MUST be sorted
/// ascending by start. Null means today.
///
/// ONE rule, and it is the same line a calendar tap parks a day on: a day
/// takes the title the moment its label ARRIVES at the reading [line], and
/// keeps it until the label has fallen [deadband] back below it. The hold is
/// one-sided on purpose - the resting position of a navigated day is the line
/// itself, so a window centred on it would leave the answer depending on which
/// way the list arrived.
DateTime? viewedDayAt(
  double offset,
  double line,
  List<(double, DateTime)> starts,
  DateTime? current, {
  double deadband = titleDeadband,
}) {
  assert(() {
    for (var i = 1; i < starts.length; i++) {
      if (starts[i].$1 < starts[i - 1].$1) return false;
    }
    return true;
  }(), 'starts must be sorted ascending');
  // Runs on every scroll event, so [starts] is searched, not scanned.
  DateTime? pick(double at) {
    var lo = 0;
    var hi = starts.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (starts[mid].$1 <= at) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo == 0 ? null : starts[lo - 1].$2;
  }

  // Home is today, and the boundary is held from BOTH sides: the first label
  // rests exactly on the line, so without a hold a nudge of a few pixels would
  // hand the bar over and back. Today keeps it until a label has cleared the
  // line by the deadband, and only gives it back at rest.
  if (offset <= (current == null ? deadband : 0.5)) return null;

  final arrived = pick(offset + line);
  final held = pick(offset + line + deadband);
  if (current != null && current == held && held != arrived) return current;
  return arrived;
}

/// Owns the geometry bookkeeping behind the bar's section title: one key per
/// day splitter LABEL, their accumulated scroll-space starts, and the
/// [viewedDay] the bar renders. It depends on the list materializing EVERY
/// splitter (home sets a huge `scrollCacheExtent` for exactly this): the table
/// of starts must be complete, or a tapped day has no target and the tail that
/// makes the oldest day reachable cannot be measured.
class SectionTracker {
  final ValueNotifier<DateTime?> viewedDay = ValueNotifier(null);

  /// Keys the list attaches to its splitters; owned here so they survive
  /// list rebuilds.
  final Map<DateTime, GlobalKey> splitterKeys = {};

  /// The list's own key, the coordinate space starts are measured in.
  final GlobalKey listKey = GlobalKey();

  final Map<DateTime, double> _starts = {};

  /// [_starts] as a list sorted ascending by start, rebuilt whenever [_starts]
  /// changes, so the per-scroll lookup allocates nothing.
  List<(double, DateTime)> _sorted = const [];
  bool _afterLayoutPending = false;

  void _resort() =>
      _sorted = [for (final e in _starts.entries) (e.value, e.key)]
        ..sort((a, b) => a.$1.compareTo(b.$1));

  /// Drops bookkeeping for days that no longer exist.
  void prune(Set<DateTime> days) {
    splitterKeys.removeWhere((day, _) => !days.contains(day));
    final before = _starts.length;
    _starts.removeWhere((day, _) => !days.contains(day));
    if (_starts.length != before) _resort();
  }

  /// Re-anchors the title to today.
  void reset() => viewedDay.value = null;

  /// Moves the cursor NOW, ahead of the scroll that follows it (a tapped day
  /// must light up on touch, not on arrival).
  void focus(DateTime day) => viewedDay.value = day;

  /// The known scroll-space start of [day]'s splitter label, for tap
  /// navigation.
  double? startOf(DateTime day) => _starts[day];

  /// The deepest known label start, which the list must be able to bring up to
  /// the reading line for the oldest day to be reachable at all.
  double? get lastStart => _sorted.isEmpty ? null : _sorted.last.$1;

  /// Recomputes [viewedDay] for the scroll's current offset, against the
  /// starts as of the last measure: the per-event scroll path walks no
  /// geometry.
  void track(ScrollController scroll, {required double line}) {
    if (!scroll.hasClients) return;
    viewedDay.value = viewedDayAt(scroll.offset, line, _sorted, viewedDay.value);
  }

  /// Re-measures the materialized splitters' starts; with [line], also
  /// recomputes the cursor. Callers whose cursor is spoken for (a glide in
  /// flight) pass no line.
  void remeasure(ScrollController scroll, {double? line}) {
    if (!scroll.hasClients) return;
    _upsertStarts(scroll.offset);
    if (line != null) track(scroll, line: line);
  }

  /// Runs [body] once after this frame's layout, deduped per frame.
  void afterLayout(VoidCallback body) {
    if (_afterLayoutPending) return;
    _afterLayoutPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _afterLayoutPending = false;
      body();
    });
  }

  /// Refreshes the start of every splitter that currently HAS geometry (the
  /// materialized ones near the viewport); the rest keep their last known
  /// value until they come near again.
  void _upsertStarts(double offset) {
    final area = listKey.currentContext?.findRenderObject();
    if (area is! RenderBox) return;
    for (final MapEntry(key: day, value: key) in splitterKeys.entries) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      _starts[day] = box.localToGlobal(Offset.zero, ancestor: area).dy + offset;
    }
    _resort();
  }

  void dispose() => viewedDay.dispose();
}
