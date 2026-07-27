import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/layouts/home/components/entry_row.dart';
import 'package:opentranscribe/view/layouts/home/components/home_empty.dart';
import 'package:opentranscribe/view/layouts/home/components/home_menu.dart';
import 'package:opentranscribe/view/layouts/home/components/pull_to_record.dart';
import 'package:opentranscribe/view/layouts/home/components/record_fab.dart';
import 'package:opentranscribe/view/layouts/home/components/section_tracker.dart';
import 'package:opentranscribe/view/layouts/home/components/strip_fold.dart';
import 'package:opentranscribe/view/layouts/home/components/week_calendar.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';

/// Home: fixed chrome (the date bar with the week strip on one material) over
/// the journal scrolling under it. The scroll drives both the rolling date
/// and the strip's cursor, exactly in step; tapping a calendar day glides the
/// list to that day's section, tapping the title glides home, and pulling down
/// past the threshold opens the recorder. [HomeCubit] is provided at the root,
/// so the shell can refresh it after a recording.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// First day of the calendar's visible week, feeding the bar's month.
  final ValueNotifier<DateTime> _visibleWeek = ValueNotifier(DateTime.now());

  final ScrollController _scroll = ScrollController();

  final SectionTracker _sections = SectionTracker();
  late final PullToRecordGesture _pullGesture = PullToRecordGesture(
    onArm: Haptics.selection,
    onDisarm: Haptics.light,
    onFire: _openRecorder,
  );

  /// Set from the theme each build: the list's resting top, past the chrome
  /// (fully open) and its fade. FIXED, so the strip folding never relayouts
  /// the list - only the chrome's own height moves.
  double _contentTop = 0;

  /// The chrome's foldable block: the breath plus the week strip.
  double _stripDepth = 0;

  /// How far the strip is folded, 0 open to 1 gone. A pure function of the
  /// scroll, so the fold is exactly as interruptible as the finger driving it.
  final ValueNotifier<double> _fold = ValueNotifier(0);

  /// The id of the one row currently swiped open, or null. Shared across every
  /// row so opening one closes the rest; scrolling clears it. This is the
  /// scoping that keeps a swipe-to-delete from firing by accident.
  final ValueNotifier<String?> _openRow = ValueNotifier(null);

  /// Extra tail under the list so its OLDEST day can still be scrolled up to
  /// the reading line. Measured, because it depends on how tall that last day
  /// happens to be.
  double _tail = 0;

  /// Identifies the glide in flight. The cursor is set up front by whoever
  /// started the glide, so scroll tracking must not drag it through every day
  /// the list passes on the way. A token rather than a flag because an
  /// interrupted `animateTo` still COMPLETES its future: a superseded glide
  /// would otherwise clear the guard while its replacement is still running.
  int _glideId = 0;
  bool _gliding = false;

  /// Bumped on each title tap so the week strip returns to today's week even
  /// when the list is already at the top and the cursor never moves.
  int _homeTick = 0;

  /// The reading line for the CURRENT fold: the chrome's bottom edge, which
  /// rides up with the content while the strip folds and then holds. It is
  /// where a day's label takes the title, and where a calendar tap parks it.
  double get _line => _contentTop - _fold.value * _stripDepth;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      // Scrolling dismisses an open row's actions - the list moving under your
      // finger should not leave a Delete armed behind it.
      if (_openRow.value != null) _openRow.value = null;
      _pullGesture.update(
        pixels: notification.metrics.pixels,
        dragging: notification.dragDetails != null,
      );
      _fold.value = stripFold(notification.metrics.pixels, _stripDepth);
      if (!_gliding) _sections.track(_scroll, line: _line);
      return false;
    }
    if (notification is ScrollEndNotification) {
      _pullGesture.settle();
      _settleStrip();
    }
    return false;
  }

  /// Finishes a fold the scroll stopped half way through. Nothing to settle is
  /// the common case, and a target the list cannot actually reach is skipped
  /// rather than glided to: the glide's own end would ask again.
  void _settleStrip() {
    if (_gliding || !_scroll.hasClients) return;
    final target = stripSettle(_scroll.position.pixels, _stripDepth);
    if (target == null) return;
    final reachable = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if ((reachable - _scroll.position.pixels).abs() < 0.5) return;
    _glideTo(reachable);
  }

  void _openRecorder() {
    Haptics.medium();
    final home = context.read<HomeCubit>();
    // Refresh on return: the sheet saves a new entry.
    context.pushNamed(Routes.recordName).then((_) => home.load());
  }

  void _glideTo(double offset) {
    final motion = context.motionNow;
    final reduce = context.reduceMotion;
    _gliding = true;
    final id = ++_glideId;
    // Outside any notification dispatch; starting an activity from within it
    // can fight the one that is ending.
    Future.microtask(() async {
      if (!mounted || !_scroll.hasClients) {
        if (id == _glideId) _gliding = false;
        return;
      }
      final target = offset.clamp(0.0, _scroll.position.maxScrollExtent);
      // Reduce Motion: land on the day without the travel.
      if (reduce) {
        _scroll.jumpTo(target);
      } else {
        await _scroll.animateTo(target, duration: motion.dayGlide, curve: motion.dayGlideCurve);
      }
      // A later glide superseded this one: it owns the guard now.
      if (id != _glideId) return;
      // Arrived (or the user grabbed it mid-flight): geometry rules again.
      _gliding = false;
      if (mounted) _sections.track(_scroll, line: _line);
    });
  }

  /// Calendar navigation: glide the list until [day]'s label sits ON the
  /// reading line, clear of the chrome's fade, which is also the position that
  /// hands it the title and the cursor.
  void _scrollToDay(DateTime day) {
    final start = _sections.startOf(day);
    if (start == null) {
      // A day without records has no label to park; home IS today.
      _sections.reset();
      _glideTo(0);
      return;
    }
    // The cursor and the title move on touch; the list catches up.
    _sections.focus(day);
    _glideTo(dayGlideOffset(start, _contentTop, _stripDepth));
  }

  /// Grows (or gives back) the list's tail so the deepest label can reach the
  /// reading line. Runs after layout, when the starts and the scroll extent
  /// are both real. The tail sits BELOW every label, so it cannot move them:
  /// one pass settles it. It measures against the FOLDED line, the only one
  /// the oldest day can ever be parked on, which is also what guarantees the
  /// list is always long enough to fold the strip at all.
  void _fitTail() {
    if (!_scroll.hasClients) return;
    final deepest = _sections.lastStart;
    final delta = deepest == null
        ? -_tail
        : (deepest - (_contentTop - _stripDepth)) - _scroll.position.maxScrollExtent;
    final next = (_tail + delta).clamp(0.0, double.infinity);
    if ((next - _tail).abs() > 0.5) setState(() => _tail = next);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pullGesture.dispose();
    _sections.dispose();
    _visibleWeek.dispose();
    _fold.dispose();
    _openRow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // The strip gets a breath under the subtitle; resting content starts
    // fully past the fade tail so the first splitter is never washed.
    _stripDepth = AppSpacing.md + WeekCalendar.heightOf(context);
    _contentTop = AppTopBar.largeHeightOf(context) + _stripDepth + theme.topBar.fadeTail;

    return ColoredBox(
      color: theme.screens.home,
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          _sections.prune(state.entryDays);
          // After EVERY build: splitter positions move when entries are
          // added or renamed (card heights change), not only when the set
          // of days does.
          _sections.seedAfterLayout(() {
            if (!mounted) return;
            _sections.track(_scroll, line: _line);
            _fitTail();
          });

          final body = state.entries.isEmpty
              // A scrollable, not a Center: it overscrolls so the pull-to-record
              // gesture works with nothing recorded yet, the one way in from here.
              ? SingleChildScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(top: _contentTop),
                    child: const HomeEmpty(),
                  ),
                )
              : _RecordsList(
                  key: _sections.listKey,
                  state: state,
                  controller: _scroll,
                  splitterKeys: _sections.splitterKeys,
                  topPadding: _contentTop,
                  tail: _tail,
                  openRow: _openRow,
                  onDelete: (entry) => context.read<HomeCubit>().delete(entry),
                );

          return Stack(
            children: [
              Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: body,
                ),
              ),
              // Lives in the gap a record pull opens under the chrome, which
              // is fully open for the whole of that gesture.
              Positioned(
                top: _contentTop,
                left: 0,
                right: 0,
                child: Center(
                  child: PullToRecordHint(
                    pull: _pullGesture.pull,
                    threshold: PullToRecordGesture.threshold,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<DateTime?>(
                  valueListenable: _sections.viewedDay,
                  builder: (context, viewed, _) => ValueListenableBuilder<DateTime>(
                    valueListenable: _visibleWeek,
                    builder: (context, week, _) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      return _HomeChrome(
                        activeDay: viewed ?? today,
                        visibleWeek: week,
                        state: state,
                        fold: _fold,
                        homeTick: _homeTick,
                        onTitleTap: () {
                          _sections.reset();
                          _glideTo(0);
                          // Force the strip home too: a manually swiped week
                          // leaves the cursor on today, so the glide alone
                          // would not page it back.
                          setState(() => _homeTick++);
                        },
                        onDayTap: _scrollToDay,
                        onVisibleWeekChanged: (start) => _visibleWeek.value = start,
                      );
                    },
                  ),
                ),
              ),
              // A persistent record button floating clear of the home indicator.
              // Pull-to-record stays; this is the obvious, hard-to-miss way in.
              Positioned(
                right: AppSpacing.xl,
                bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
                child: RecordFab(onTap: _openRecorder),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The chrome: the rolling date over the week strip, on one shared material.
/// The strip's cursor and the title are the same day by construction. The date
/// row is fixed; the strip folds away under it as the journal scrolls.
class _HomeChrome extends StatefulWidget {
  const _HomeChrome({
    required this.activeDay,
    required this.visibleWeek,
    required this.state,
    required this.fold,
    required this.homeTick,
    required this.onTitleTap,
    required this.onDayTap,
    required this.onVisibleWeekChanged,
  });

  final DateTime activeDay;

  /// First day of the calendar's visible week; its month renders after the dot.
  final DateTime visibleWeek;
  final HomeState state;

  /// How far the strip is folded away, 0 open to 1 gone.
  final ValueListenable<double> fold;

  /// Bumped on a title tap, forwarded to the strip so it pages back to today's
  /// week even when the cursor never moved.
  final int homeTick;
  final VoidCallback onTitleTap;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onVisibleWeekChanged;

  @override
  State<_HomeChrome> createState() => _HomeChromeState();
}

class _HomeChromeState extends State<_HomeChrome> {
  /// Roll direction: +1 when the shown day moved later in time, -1 earlier.
  int _direction = 1;

  @override
  void didUpdateWidget(_HomeChrome old) {
    super.didUpdateWidget(old);
    if (old.activeDay != widget.activeDay) {
      _direction = widget.activeDay.isAfter(old.activeDay) ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AppTopBar(
      // Home is the base of the stack; never a back chevron, not even the
      // phantom one that flickers in while a pushed route pops off above it.
      automaticLeading: false,
      barHeight: theme.topBar.largeHeight,
      onTitleTap: widget.onTitleTap,
      // One trailing menu instead of a row of buttons: the home is the app, and
      // this dropdown is how you leave it (there is no settings screen). Every
      // setting is a row or submenu inside it; see [HomeMenu].
      actions: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: HomeMenu(color: theme.topBar.iconColor),
        ),
      ],
      // The top padding settles the block lower in the row, off the status
      // area.
      title: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: RollingText(
          text: DateFormat.MMMMd().format(widget.activeDay),
          style: AppType.digits(AppType.display2).copyWith(color: theme.topBar.titleColor),
          direction: _direction,
        ),
      ),
      // Quieter than the title: every changed character moves together, fast.
      subtitle: RollingText(
        text:
            '${DateFormat.EEEE().format(widget.activeDay)} · '
            '${DateFormat.yMMMM().format(widget.visibleWeek)}',
        style: AppType.footnote.copyWith(color: theme.textSecondary),
        direction: _direction,
        window: theme.motion.subtitleRoll,
        stagger: Duration.zero,
      ),
      bottom: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: WeekCalendar(
          entryDays: widget.state.entryDays,
          firstEntryDay: widget.state.firstEntryDay,
          cursorDay: widget.activeDay,
          onDayTap: widget.onDayTap,
          onVisibleWeekChanged: widget.onVisibleWeekChanged,
          homeTick: widget.homeTick,
        ),
      ),
      bottomHeight: AppSpacing.md + WeekCalendar.heightOf(context),
      bottomFold: widget.fold,
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({
    required this.state,
    required this.controller,
    required this.splitterKeys,
    required this.topPadding,
    required this.tail,
    required this.openRow,
    required this.onDelete,
    super.key,
  });

  final HomeState state;
  final ScrollController controller;

  /// Tracker-owned keys splitter label positions are read through.
  final Map<DateTime, GlobalKey> splitterKeys;
  final double topPadding;

  /// Measured room under the last day, so it too can be scrolled to the top.
  final double tail;

  /// The one row allowed swiped-open at a time, shared with every [EntryRow].
  final ValueNotifier<String?> openRow;
  final Future<void> Function(Entry) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final sections = state.sections;

    // Nothing floats over the list any more; the tail just clears the home
    // indicator.
    final clearance = MediaQuery.paddingOf(context).bottom;

    return ListView(
      controller: controller,
      // Materialize everything: with every splitter measured, calendar taps
      // have exact targets and the title tracker never runs blind. Journal
      // scale keeps this affordable.
      scrollCacheExtent: const ScrollCacheExtent.pixels(1e5),
      padding: EdgeInsets.only(top: topPadding, bottom: clearance + AppSpacing.lg + tail),
      children: [
        for (final (s, section) in sections.indexed) ...[
          Padding(
            // Top spacing only BETWEEN groups: the first splitter rests right
            // under the chrome. The left inset lands the label on the records'
            // TEXT column (content margin + rail gutter), not on the rail: the
            // rail belongs to the day's records, and the label names them.
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl + theme.entryList.railGutter,
              s == 0 ? 0 : AppSpacing.xxxl,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text(
              '${DateFormat.EEEE().format(section.day)}, '
              '${DateFormat.MMMd().format(section.day)}',
              // Keyed on the LABEL, not the padded block: the tracker's line
              // is about where the words are, so every day rests and lands in
              // the same place regardless of the gap above it.
              key: splitterKeys.putIfAbsent(section.day, GlobalKey.new),
              style: AppType.footnote.copyWith(color: theme.entryList.splitterColor),
            ),
          ),
          for (final (i, entry) in section.entries.indexed)
            EntryRow(
              key: ValueKey(entry.id),
              entry: entry,
              last: i == section.entries.length - 1,
              openId: openRow,
              onDelete: onDelete,
              onTap: () {
                final home = context.read<HomeCubit>();
                // The detail screen reads EntriesCubit; refresh it before the
                // push, and refresh home on return (delete or rename).
                context.read<EntriesCubit>().load();
                context
                    .pushNamed(Routes.entryName, pathParameters: {'id': entry.id})
                    .then((_) => home.load());
              },
            ),
        ],
        const SizedBox(height: 42),
      ],
    );
  }
}
