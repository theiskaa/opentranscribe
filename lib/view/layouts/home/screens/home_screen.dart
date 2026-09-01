import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/layouts/home/components/day_glide.dart';
import 'package:opentranscribe/view/layouts/home/components/entry_row.dart';
import 'package:opentranscribe/view/layouts/home/components/home_empty.dart';
import 'package:opentranscribe/view/layouts/home/components/home_menu.dart';
import 'package:opentranscribe/view/layouts/home/components/pull_to_record.dart';
import 'package:opentranscribe/view/layouts/home/components/record_fab.dart';
import 'package:opentranscribe/view/widgets/seam_padding.dart';
import 'package:opentranscribe/view/layouts/home/components/section_tracker.dart';
import 'package:opentranscribe/view/layouts/home/components/week_calendar.dart';
import 'package:opentranscribe/view/layouts/home/components/reflection_home_card.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/entrance_rise.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';

/// Home: fixed chrome (the date bar with the week strip on one material) over
/// the journal scrolling under it. The calendar never hides; the scroll drives
/// the rolling date and the strip's cursor, exactly in step. Tapping a
/// calendar day glides the list to that day's section, tapping the title
/// glides home, and pulling down past the threshold opens the recorder.
/// [HomeCubit] is provided at the root, so the shell can refresh it after a
/// recording.
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

  /// The reflection history as of the last build (null before the first), and
  /// the cards that arrived while home was up: only those get the entrance, and
  /// they keep their wrapper so a later rebuild cannot re-play it.
  List<Reflection>? _seenReflections;
  final Set<ReflectionCardKey> _enteredCards = {};

  /// The entry ids as of the last build (null before the first), and the ids
  /// that arrived while home was up: only those rows get the entrance, and
  /// they keep their wrapper so a later rebuild cannot re-play it.
  Set<String>? _seenEntryIds;
  final Set<String> _enteredEntries = {};

  /// The same ledger for calendar days: a day that arrived while home was up
  /// unfolds its splitter along with its first row, so the section's whole
  /// lead-in glides open instead of jumping in at full height.
  Set<DateTime>? _seenDays;
  final Set<DateTime> _enteredDays = {};

  /// Days whose last record just left: their splitters keep rendering as
  /// GHOSTS folding away in the seam their section vacated, then drop from
  /// here when the fold ends. A day recorded again mid-fold leaves this set
  /// at once - the live splitter takes over.
  final Set<DateTime> _departingDays = {};

  /// The reflection stacks those days carried, folding as ghosts beside the
  /// ghost splitters; dropped with the day.
  final Map<DateTime, List<Reflection>> _departingCards = {};

  /// Seats as of the last build, so a departing day's stack can be told from
  /// a re-seat.
  Map<ReflectionCardKey, CardSeat>? _seenSeats;

  /// Rows whose delete has committed and whose exit is playing, id to the
  /// row's section day. While a row dies, the list treats it as already gone
  /// for LAYOUT decisions - the neighbor's last-gap and an emptying day's
  /// title close in step with the exit - and the emptied day skips its ghost
  /// (the live title pre-folded). Cleared a frame AFTER the delete's future
  /// resolves, never sooner: the departure diff runs in the emit's build and
  /// must still see the id here, so a refused delete unfolds everything back
  /// and a fast delete cannot ghost a title that already folded live.
  final Map<String, DateTime> _dying = {};
  late final PullToRecordGesture _pullGesture = PullToRecordGesture(
    onArm: Haptics.selection,
    onDisarm: Haptics.light,
    onFire: _openRecorder,
  );

  /// Set from the theme each build: the list's resting top, past the chrome
  /// and its fade. The chrome never folds - the calendar is home's fixed
  /// ground, always in sight - so this is also the reading line.
  double _contentTop = 0;

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

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    // Layout can shift without a home build (a row unfolding, a type-size
    // change), so each gesture begins on a fresh measure; the per-event path
    // below then walks no geometry.
    if (notification is ScrollStartNotification) _sections.remeasure(_scroll);
    if (notification is ScrollUpdateNotification) {
      // Scrolling dismisses an open row's actions - the list moving under your
      // finger should not leave a Delete armed behind it.
      if (_openRow.value != null) _openRow.value = null;
      _pullGesture.update(
        pixels: notification.metrics.pixels,
        dragging: notification.dragDetails != null,
      );
      if (!_gliding) _sections.track(_scroll, line: _contentTop);
      return false;
    }
    if (notification is ScrollEndNotification) _pullGesture.settle();
    return false;
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
      // Arrived (or the user grabbed it mid-flight): the cursor is ours again.
      _gliding = false;
      if (mounted) _sections.track(_scroll, line: _contentTop);
    });
  }

  /// Calendar navigation: glide the list until [day]'s label sits ON the
  /// reading line, clear of the chrome's fade, which is also the position that
  /// hands it the title and the cursor.
  void _scrollToDay(DateTime day) {
    // A fresh measure first: the target must not inherit drift from a layout
    // change that never rebuilt home (a row still unfolding, a type change).
    _sections.remeasure(_scroll);
    final start = _sections.startOf(day);
    if (start == null) {
      // A day without records has no label to park; home IS today.
      _sections.reset();
      _glideTo(0);
      return;
    }
    // The cursor and the title move on touch; the list catches up.
    _sections.focus(day);
    _glideTo(dayGlideOffset(start, _contentTop));
  }

  /// Grows (or gives back) the list's tail so the deepest label can reach the
  /// reading line. Runs after layout, when the starts and the scroll extent
  /// are both real. The tail sits BELOW every label, so it cannot move them:
  /// one pass settles it.
  void _fitTail() {
    if (!_scroll.hasClients) return;
    final deepest = _sections.lastStart;
    final delta = deepest == null
        ? -_tail
        : (deepest - _contentTop) - _scroll.position.maxScrollExtent;
    final next = (_tail + delta).clamp(0.0, double.infinity);
    if ((next - _tail).abs() > 0.5) setState(() => _tail = next);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pullGesture.dispose();
    _sections.dispose();
    _visibleWeek.dispose();
    _openRow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // The strip gets a breath under the subtitle; resting content starts
    // fully past the fade tail so the first splitter is never washed.
    _contentTop =
        AppTopBar.largeHeightOf(context) +
        AppSpacing.md +
        WeekCalendar.heightOf(context) +
        theme.topBar.fadeTail;

    return ColoredBox(
      color: theme.screens.home,
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          _sections.prune(state.entryDays);
          _enteredEntries.addAll(newEntryIds(_seenEntryIds, state.entries));
          _seenEntryIds = {for (final e in state.entries) e.id};
          _enteredDays.addAll(newEntryDays(_seenDays, state.entryDays));
          // Departures before the reseed, against the same previous set; under
          // Reduce Motion emptied days simply leave, no ghost, and a flip
          // drops any ghost still mid-fold. A day whose title pre-folded with
          // its dying rows needs no ghost either - the seam is already closed
          // when the emit lands.
          if (context.reduceMotion) {
            _departingDays.clear();
          } else {
            _departingDays.addAll(
              departedEntryDays(_seenDays, state.entryDays).where((d) => !_dying.containsValue(d)),
            );
          }
          _departingDays.removeAll(state.entryDays);
          // An emptied journal renders HomeEmpty, where no ghost can mount or
          // finish: a day stranded here would fold as a phantom label beside
          // whatever day is recorded next.
          if (state.entries.isEmpty) _departingDays.clear();
          _seenDays = state.entryDays;

          // A separate, value-gated subscription: cards are driven by the
          // reflection history, so this must still rebuild when a period is
          // reflected, deleted, or regenerated (all three change
          // homeReflections), but not on unrelated reflections emits (style,
          // probe, viewed-period). ReflectionsState.homeReflections is a fresh
          // list on every derive, so identity-based rebuild gating (the
          // default BlocBuilder/BlocSelector behavior) would still fire on
          // every emit; buildWhen compares the lists' contents instead. Home
          // reads every enabled period's reflections, independent of the
          // screen's viewed period, so paging that screen never disturbs
          // home's cards.
          return BlocBuilder<ReflectionsCubit, ReflectionsState>(
            buildWhen: (previous, current) =>
                previous.loaded != current.loaded ||
                !listEquals(previous.homeReflections, current.homeReflections),
            builder: (context, reflectionsState) {
              // After EVERY build of the list, whichever builder fired:
              // splitter positions move when entries are added or renamed and
              // when reflection cards arrive, not only when the set of days
              // does.
              _sections.seedAfterLayout(() {
                if (!mounted) return;
                // A glide owns the cursor; only the geometry refreshes
                // mid-flight.
                _sections.remeasure(_scroll, line: _gliding ? null : _contentTop);
                _fitTail();
              });

              final reflections = reflectionsState.homeReflections;
              // Only a card that ARRIVES while home is up gets an entrance; the
              // first LOADED build seeds the ledger settled. Diffing before the
              // cubit's first real read would run against its empty placeholder
              // and mark the whole history newly arrived.
              if (reflectionsState.loaded) {
                final previous = _seenReflections;
                if (previous != null) _enteredCards.addAll(newlyReflected(previous, reflections));
                _seenReflections = reflections;
              }

              final sectionDays = [for (final section in state.sections) section.day];
              final cards = reflectionCardsForSections(
                sectionDays: sectionDays,
                reflections: reflections,
                today: DateTime.now(),
              );
              final seats = cardSeats(cards, sectionDays);
              // Only stacks a departing day carried; any other leaving card is
              // a change of contents, not a fold.
              if (!context.reduceMotion && _seenSeats != null) {
                final departed = departedCards(_seenSeats!, seats);
                for (final MapEntry(key: day, value: gone) in departed.entries) {
                  if (_departingDays.contains(day)) _departingCards.putIfAbsent(day, () => gone);
                }
              }
              _departingCards.removeWhere((day, _) => !_departingDays.contains(day));
              _seenSeats = seats;

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
                      cards: cards,
                      departingCards: _departingCards,
                      enteredCards: _enteredCards,
                      enteredEntries: _enteredEntries,
                      enteredDays: _enteredDays,
                      departingDays: _departingDays,
                      onDepartureEnd: (day) {
                        if (!mounted) return;
                        setState(() => _departingDays.remove(day));
                      },
                      dying: _dying,
                      onRowDeleteStart: (id, day) {
                        if (!mounted) return;
                        setState(() => _dying[id] = day);
                      },
                      controller: _scroll,
                      splitterKeys: _sections.splitterKeys,
                      topPadding: _contentTop,
                      tail: _tail,
                      openRow: _openRow,
                      onDelete: (entry) async {
                        try {
                          await context.read<HomeCubit>().delete(entry);
                        } finally {
                          // Resolved either way: a removed row's flag is spent, a
                          // refused delete's row unfolds its surroundings back.
                          // Past the frame, never inside it: the emit's build
                          // diffs departures against this ledger, and a delete
                          // resolving first would clear the id before that build
                          // ever sees it - ghosting a title that folded live.
                          await WidgetsBinding.instance.endOfFrame;
                          if (mounted) setState(() => _dying.remove(entry.id));
                        }
                      },
                    );

              return Stack(
                children: [
                  Positioned.fill(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: body,
                    ),
                  ),
                  // Lives in the gap a record pull opens under the chrome.
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
          );
        },
      ),
    );
  }
}

/// The chrome: the rolling date over the week strip, on one shared material.
/// The strip's cursor and the title are the same day by construction. Fixed:
/// the calendar is home's ground and stays in sight while the journal scrolls
/// under it.
class _HomeChrome extends StatefulWidget {
  const _HomeChrome({
    required this.activeDay,
    required this.visibleWeek,
    required this.state,
    required this.homeTick,
    required this.onTitleTap,
    required this.onDayTap,
    required this.onVisibleWeekChanged,
  });

  final DateTime activeDay;

  /// First day of the calendar's visible week; its month renders after the dot.
  final DateTime visibleWeek;
  final HomeState state;

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
    final locale = localeTag(context);
    return AppTopBar(
      // Home is the base of the stack; never a back chevron, not even the
      // phantom one that flickers in while a pushed route pops off above it.
      automaticLeading: false,
      // Nothing native scrolls under the home bar, so the drawn fade stands in
      // for the native material and skips its re-stage flicker on return.
      nativeMaterial: false,
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
          text: DateFormat.MMMMd(locale).format(widget.activeDay),
          style: AppType.digits(AppType.display2).copyWith(color: theme.topBar.titleColor),
          direction: _direction,
        ),
      ),
      // Quieter than the title: every changed character moves together, fast.
      subtitle: RollingText(
        text:
            '${DateFormat.EEEE(locale).format(widget.activeDay)} · '
            '${DateFormat.yMMMM(locale).format(widget.visibleWeek)}',
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
    );
  }
}

/// Clearance under the last card so it clears the record button, matching the
/// recorder screen's bottom inset.
const double _listBottomInset = 42;

/// One period's reflection slot in the timeline: the editorial card, opening
/// the reflections pager landed on its period and start, entering with the
/// app's rise only when it arrived while home was up.
class _ReflectionCardSlot extends StatelessWidget {
  const _ReflectionCardSlot({required this.reflection, required this.entrance});

  final Reflection reflection;
  final bool entrance;

  @override
  Widget build(BuildContext context) {
    final card = ReflectionHomeCard(
      reflection: reflection,
      onTap: () => context.pushNamed(
        Routes.reflectionsName,
        queryParameters: {'period': reflection.period.wire, 'week': reflection.periodKey},
      ),
    );
    if (!entrance) return card;
    return EntranceRise(child: card);
  }
}

/// A section's reflection cards as ONE block, month over week over day, so the
/// stack reads outer to inner down to the day's own records. The gap above the
/// block is the group's break from the day before it and moves with the
/// timeline's other seams; the spacing INSIDE it is fixed except for a card
/// unseated by its day's delete, which folds with the exit. Any other card
/// joining or leaving re-seats its siblings at once, a change of contents,
/// not a fold.
class _ReflectionCardGroup extends StatelessWidget {
  const _ReflectionCardGroup({
    required this.reflections,
    required this.entered,
    required this.gapless,
    this.folding = const {},
    super.key,
  });

  final List<Reflection> reflections;

  /// Cards losing their seat with the rows now exiting; they fold on the
  /// exit's clock.
  final Set<ReflectionCardKey> folding;

  /// Cards that arrived while home was up; only these enter with motion.
  final Set<ReflectionCardKey> entered;

  /// The group leads the list, so it carries no break above it.
  final bool gapless;

  @override
  Widget build(BuildContext context) {
    // The block also folds once every card does, so its break closes with
    // them; the cards keep their own folds so a flip mid-flight never reverses one.
    final all = reflections.every((r) => folding.contains(cardKeyOf(r)));
    return _FoldAway(
      folded: all,
      child: SeamPadding(
        closing: gapless,
        padding: EdgeInsets.only(top: gapless ? 0 : AppSpacing.xxl, bottom: AppSpacing.sm),
        // Stretch: the cards size to the list's width in the timeline, and a
        // Column would otherwise hand them their intrinsic one.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (c, reflection) in reflections.indexed)
              // Keyed so a card joining or leaving the stack cannot re-inflate
              // the slot at its shifted index and replay the entrance.
              _FoldAway(
                key: ValueKey(cardKeyOf(reflection)),
                folded: folding.contains(cardKeyOf(reflection)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c > 0) const SizedBox(height: AppSpacing.sm),
                    _ReflectionCardSlot(
                      reflection: reflection,
                      entrance: entered.contains(cardKeyOf(reflection)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A timeline piece that arrived while home was up UNFOLDS into its seat -
/// the list glides apart to make room while it fades in - because a
/// full-height insert jumps everything below it, and no fade can mask a
/// layout jump. Wraps the entry rows and, for a brand-new day, its splitter.
/// Reduce Motion keeps the same tree at zero duration (the _Unfold trick), so
/// an accessibility flip mid-session cannot remount settled pieces and replay
/// their arrivals. Once settled, the clip relaxes so the delete disc keeps
/// its sanctioned spill into the row gap.
class _ArrivalUnfold extends StatelessWidget {
  const _ArrivalUnfold({required this.entrance, required this.child, super.key});

  final bool entrance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!entrance) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.reduceMotion ? Duration.zero : context.theme.motion.expand,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => _Fold(t: t, child: child!),
      child: child,
    );
  }
}

/// One frame for every timeline fold - arrivals, live folds and ghosts all
/// grow and close through this, so the fold visual lives once. topLeft, not
/// topCenter: the Align expands to the list's full width, so a centering
/// alignment would re-seat an intrinsic-width child (the day splitter) in the
/// middle; only the top matters, it is what the fold moves from. At rest the
/// clip relaxes so the delete disc keeps its sanctioned spill into the row
/// gap, and the wrapper stays constant so the subtree's element (and any
/// animation in flight inside it) survives a fold starting.
class _Fold extends StatelessWidget {
  const _Fold({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    return ClipRect(
      clipBehavior: t < 1 ? Clip.hardEdge : Clip.none,
      child: Align(
        alignment: Alignment.topLeft,
        heightFactor: t,
        child: Opacity(opacity: t, child: child),
      ),
    );
  }
}

/// The day splitter's padded label, shared by the live splitter and its
/// departing ghost so a ghost renders exactly what it replaces. Top spacing
/// only BETWEEN groups ([gapless] drops it); the left inset lands the label
/// on the records' TEXT column (content margin + rail gutter), not on the
/// rail, which belongs to the day's records.
class _SplitterLabel extends StatelessWidget {
  const _SplitterLabel({required this.day, required this.gapless, this.labelKey});

  final DateTime day;
  final bool gapless;

  /// The tracker's key, on the LABEL rather than the padded block: the
  /// tracker's line is about where the words are, so every day rests and
  /// lands in the same place regardless of the gap above it. Ghosts pass
  /// none; the tracker already pruned theirs.
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final locale = localeTag(context);
    return SeamPadding(
      closing: gapless,
      padding: EdgeInsets.fromLTRB(
        theme.entryList.textColumnInset,
        gapless ? 0 : AppSpacing.xxxl,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Text(
        '${DateFormat.EEEE(locale).format(day)}, ${DateFormat.MMMd(locale).format(day)}',
        key: labelKey,
        style: AppType.footnote.copyWith(color: theme.entryList.splitterColor),
      ),
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({
    required this.state,
    required this.cards,
    required this.departingCards,
    required this.enteredCards,
    required this.enteredEntries,
    required this.enteredDays,
    required this.departingDays,
    required this.onDepartureEnd,
    required this.dying,
    required this.onRowDeleteStart,
    required this.controller,
    required this.splitterKeys,
    required this.topPadding,
    required this.tail,
    required this.openRow,
    required this.onDelete,
    super.key,
  });

  final HomeState state;

  /// The reflection cards by section index, each stack at the top of the first
  /// section its period covers.
  final Map<int, List<Reflection>> cards;

  /// Stacks departed days carried, folding as ghosts beside the ghost splitters.
  final Map<DateTime, List<Reflection>> departingCards;

  /// Cards that arrived while home was up; only these enter with motion.
  final Set<ReflectionCardKey> enteredCards;

  /// Entry ids that arrived while home was up; only these rows enter with
  /// motion.
  final Set<String> enteredEntries;

  /// Days that arrived while home was up; their splitters unfold with their
  /// first row.
  final Set<DateTime> enteredDays;

  /// Days folding away after their last record left; each renders a ghost
  /// splitter in the seam its section vacated.
  final Set<DateTime> departingDays;

  /// A ghost's fold finished; the owner drops the day from [departingDays].
  final ValueChanged<DateTime> onDepartureEnd;

  /// Rows mid-exit, id to section day: already gone for layout decisions, so
  /// the surroundings close in step with the slot's own collapse.
  final Map<String, DateTime> dying;

  /// A row's delete committed; the owner marks it dying before the exit plays.
  final void Function(String id, DateTime day) onRowDeleteStart;
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
    final sections = state.sections;

    // Nothing floats over the list any more; the tail just clears the home
    // indicator.
    final clearance = MediaQuery.paddingOf(context).bottom;

    final sectionDays = [for (final section in sections) section.day];
    final sectionIds = [
      for (final section in sections) [for (final entry in section.entries) entry.id],
    ];
    final dyingIds = dying.keys.toSet();

    final unseating = unseatingCards(
      cards: cards,
      sectionDays: sectionDays,
      sectionIds: sectionIds,
      dying: dyingIds,
    );
    final ghosts = departingSplitterSlots(sectionDays: sectionDays, departing: departingDays);
    // Dying counts as gone, so a lead's seams close with the exits above them
    // instead of snapping when the emit lands.
    bool leads(int s) => s == 0 || sectionIds.take(s).every((ids) => allDying(ids, dyingIds));
    // A card group above the splitter supplies the break itself.
    bool gapless(int s) => leads(s) || cards[s] != null;

    return ListView(
      controller: controller,
      // Materialize everything: with every splitter measured, calendar taps
      // have exact targets and the title tracker never runs blind. Journal
      // scale keeps this affordable.
      scrollCacheExtent: const ScrollCacheExtent.pixels(1e5),
      padding: EdgeInsets.only(top: topPadding, bottom: clearance + AppSpacing.lg + tail),
      children: [
        for (final (s, section) in sections.indexed) ...[
          for (final (g, day) in ghosts[s].indexed) ...[
            if (departingCards[day] != null)
              _DepartingCardGroup(
                key: ValueKey('departing-cards-${day.toIso8601String()}'),
                reflections: departingCards[day]!,
                gapless: s == 0 && g == 0,
              ),
            _DepartingSplitter(
              key: ValueKey('departing-${day.toIso8601String()}'),
              day: day,
              gapless: (s == 0 && g == 0) || departingCards[day] != null,
              onEnd: () => onDepartureEnd(day),
            ),
          ],
          if (cards[s] != null)
            // Keyed on the day, not the index: an insert or delete above must
            // not hand this group's gap to another section's mid-flight.
            _ReflectionCardGroup(
              key: ValueKey('cards-${section.day.toIso8601String()}'),
              reflections: cards[s]!,
              entered: enteredCards,
              gapless: leads(s),
              folding: unseating,
            ),
          // Keyed (like the rows) so an insert or delete above cannot
          // re-inflate the slot at its shifted index and replay the entrance.
          _ArrivalUnfold(
            key: ValueKey(section.day),
            entrance: enteredDays.contains(section.day),
            // A day whose every row is mid-exit folds its title WITH them, on
            // the exit's own clock, so the emit lands on a seam already
            // closed; a refused delete retargets it back open.
            child: _FoldAway(
              folded: allDying(sectionIds[s], dyingIds),
              child: _SplitterLabel(
                day: section.day,
                gapless: gapless(s),
                labelKey: splitterKeys.putIfAbsent(section.day, GlobalKey.new),
              ),
            ),
          ),
          for (final (i, entry) in section.entries.indexed)
            // Keyed so an entry insert or delete above cannot re-inflate the
            // slot at its shifted index and replay the entrance.
            _ArrivalUnfold(
              key: ValueKey(entry.id),
              entrance: enteredEntries.contains(entry.id),
              child: EntryRow(
                entry: entry,
                // A dying successor is already gone for layout: the gap and
                // rail close in step with its exit, and the emit changes
                // nothing.
                last: allDying(sectionIds[s].skip(i + 1), dyingIds),
                openId: openRow,
                onDelete: onDelete,
                onDeleteStart: () => onRowDeleteStart(entry.id, section.day),
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
            ),
        ],
        for (final (g, day) in ghosts[sections.length].indexed) ...[
          if (departingCards[day] != null)
            _DepartingCardGroup(
              key: ValueKey('departing-cards-${day.toIso8601String()}'),
              reflections: departingCards[day]!,
              gapless: sections.isEmpty && g == 0,
            ),
          _DepartingSplitter(
            key: ValueKey('departing-${day.toIso8601String()}'),
            day: day,
            gapless: (sections.isEmpty && g == 0) || departingCards[day] != null,
            onEnd: () => onDepartureEnd(day),
          ),
        ],
        const SizedBox(height: _listBottomInset),
      ],
    );
  }
}

/// Folds its child away while [folded] holds and back open when it clears,
/// retargeting mid-flight - the live counterpart of [_DepartingSplitter],
/// for pieces that must close WITH a neighbor's delete exit (an emptying
/// day's title) rather than after it. Runs on the exit's own clock
/// ([AppMotion.swipeExit]) so the two collapses read as one, and the emit
/// lands on a seam already closed.
class _FoldAway extends StatelessWidget {
  const _FoldAway({required this.folded, required this.child, super.key});

  final bool folded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: folded ? 0.0 : 1.0),
      duration: context.reduceMotion ? Duration.zero : context.theme.motion.swipeExit,
      curve: AppMotion.swipeExitHeightCurve,
      builder: (context, t, child) => _Fold(t: t, child: child!),
      child: child,
    );
  }
}

/// A departed day's splitter, folding out of the seam its section vacated.
/// Rebuilt from the day alone, with no GlobalKey - the tracker already pruned
/// the real one - it closes on the delete exit's clock and interval so the
/// neighbor's top gap (which always closes on that clock) moves with it as
/// one, and reports [onEnd] so the ghost ledger can drop it. Never built
/// under Reduce Motion: the ledger stays empty there, and a flip mid-fold
/// clears it.
class _DepartingSplitter extends StatelessWidget {
  const _DepartingSplitter({
    required this.day,
    required this.gapless,
    required this.onEnd,
    super.key,
  });

  final DateTime day;

  /// Whether the ghost carries no top gap: it leads the list, or its day's
  /// ghost stack above it supplies the break.
  final bool gapless;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: context.theme.motion.swipeExit,
      curve: AppMotion.swipeExitHeightCurve,
      onEnd: onEnd,
      builder: (context, t, child) => _Fold(t: t, child: child!),
      child: _SplitterLabel(day: day, gapless: gapless),
    );
  }
}

/// A departed day's reflection stack, folding out beside its ghost splitter
/// on the same clock; the splitter's [onEnd] drops both from the ledger.
class _DepartingCardGroup extends StatelessWidget {
  const _DepartingCardGroup({required this.reflections, required this.gapless, super.key});

  final List<Reflection> reflections;
  final bool gapless;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: context.theme.motion.swipeExit,
      curve: AppMotion.swipeExitHeightCurve,
      builder: (context, t, child) => _Fold(t: t, child: child!),
      child: _ReflectionCardGroup(reflections: reflections, entered: const {}, gapless: gapless),
    );
  }
}
