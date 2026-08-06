import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/reflections/components/day_chip_row.dart';
import 'package:opentranscribe/view/layouts/reflections/components/disabled_card.dart';
import 'package:opentranscribe/view/layouts/reflections/components/month_week_rows.dart';
import 'package:opentranscribe/view/layouts/reflections/components/period_children_logic.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_labels.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_page_logic.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_scrubber.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_states.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflections_menu.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';
import 'package:opentranscribe/view/widgets/selectable_prose.dart';

/// The reflections pager: each closed period is a full reading page - its
/// range as the title, the reflection drawn below with the invisible-ink
/// reveal - swiped between horizontally (oldest first; the landing page is
/// the newest closed period, and the open period is never a page). The page IS
/// the chrome, with one floating exception: a frosted scrubber capsule at
/// bottom center reads (and drives) the position, fading away once the user
/// scrolls into the text. ONE top-bar menu acts on the viewed page and
/// carries the settings knobs.
///
/// Periods nest instead of switching: a month page lists its weeks, a week
/// page wears its seven days, and taps drill DOWN in place: an instant swap
/// whose landed page transforms element by element - the title ROLLS from
/// the departed label ([_PageTitle], the odometer), the calendar pieces
/// stand with the swap while the departed level's empty seat glides shut
/// ([_SeatClose]), and the prose, only the prose, arrives through the
/// invisible-ink write-on. No route push, no slide, no crossfade, no
/// waiting beat. ONE smart back climbs UP the same way, and pops the route
/// only at the top of the hierarchy (the route-level edge swipe always
/// pops). Swiping moves between siblings, tapping between generations.
/// Reads the root-scoped [ReflectionsCubit];
/// a period filling via the foreground catch-up updates its page in place.
///
/// Availability gates only generation affordances, never stored history. With
/// an empty timeline the screen is a single editorial page, explaining either
/// the empty first run or how to make the feature work.
///
/// This is the ONE reflections surface: a home card deep-links here through
/// [initialStartKey] and lands on its page, with the same pages and the same
/// menu as the plain open.
class ReflectionsScreen extends StatefulWidget {
  const ReflectionsScreen({this.initialPeriod, this.initialStartKey, super.key});

  /// The period wire to land on (a home card deep-links its own period); null or
  /// unknown keeps the current viewed period.
  final String? initialPeriod;

  /// yyyy-MM-dd ([Reflection.keyFor]) of the start to land on; null (or an
  /// unknown one) lands on the newest closed page.
  final String? initialStartKey;

  @override
  State<ReflectionsScreen> createState() => _ReflectionsScreenState();
}

class _ReflectionsScreenState extends State<ReflectionsScreen> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<ReflectionsCubit>();
    // Recording an entry emits nothing on the cubit (only reflection writes
    // do), so the timeline inputs can be stale mid-session; opening the
    // surface re-reads them.
    unawaited(cubit.load());
    // A home card deep-links its period; land on it (a no-op when already there
    // or the period is off with no history, since it re-derives the view).
    final period = ReflectionPeriod.fromWire(widget.initialPeriod);
    if (period != null) cubit.setViewedPeriod(period);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<ReflectionsCubit>().state;

    // Timeline alone, not history: deleting the only reflection leaves a
    // tombstone (history empty, an erased page in the timeline), and that
    // page carries the regenerate route back. The first-run editorial there
    // would be a dead end. The cubit only lands here when EVERY period's
    // timeline is empty (an empty viewed period falls to the broadest one with
    // pages), so there is nothing to navigate to and the bar stays bare.
    if (state.timeline.isEmpty) {
      return AppScaffold(
        background: theme.screens.settings,
        onBack: () => context.pop(),
        actions: [ReflectionsMenu(viewed: null, color: theme.topBar.iconColor)],
        child: _Editorial(
          copy: reflectionEditorialCopy(
            l10n,
            available: state.available,
            status: state.availability.status,
          ),
        ),
      );
    }
    return _PeriodPagerView(initialStartKey: widget.initialStartKey);
  }
}

/// Where the capsule rests above the screen's bottom edge. Shared with the
/// pages' bottom inset, so the text always clears the seat.
double _capsuleSeat(BuildContext context) => MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

/// The pager body: owns the controller, the viewed page, and the reveal ledger
/// (which pages already wrote themselves on this visit).
class _PeriodPagerView extends StatefulWidget {
  const _PeriodPagerView({this.initialStartKey});

  final String? initialStartKey;

  @override
  State<_PeriodPagerView> createState() => _PeriodPagerViewState();
}

class _PeriodPagerViewState extends State<_PeriodPagerView> {
  PageController? _controller;
  int _pageCount = 0;

  /// The page the pager last came to REST on, feeding [_EagerPagePhysics] its
  /// gesture anchor. Updated only when scrolling truly ends: the live rounded
  /// page would recreate the framework's half-page commit rule.
  int _settledPage = 0;

  /// The viewed page's identity; null lands on the newest closed page.
  /// Seeded from the deep-link key when a home card opened its page
  /// ([pageForStart] falls back to the newest page for an unknown one).
  late DateTime? _viewedStart = DateTime.tryParse(widget.initialStartKey ?? '');

  /// The period the pager is currently showing. A switch to another period is a
  /// wholly new timeline, so the reveal ledger and the viewed identity reset.
  ReflectionPeriod? _shownPeriod;

  /// Where the next period switch lands, set by a drill tap just before it
  /// switches the cubit's viewed period. Null (a switch from elsewhere) lands
  /// on the newest page. Drills only offer starts holding a stored page, so
  /// the landing always exact-matches.
  DateTime? _pendingDrillStart;

  /// The last drill's departure context, consumed by the LANDED page: its
  /// title rolls from [fromLabel] and its meta subtitle from [fromMeta]
  /// instead of merely appearing (down-drills roll up, climbs roll down),
  /// and the seat the departed level's strip or rows
  /// ([fromPeriod]/[fromStart]) left behind glides shut instead of snapping.
  /// Only the prose transforms through ink - its ordinary write-on, which
  /// the cleared reveal ledger replays on landing. Cleared when the user
  /// pages away, so a later revisit does not replay the roll.
  ({
    DateTime start,
    String fromLabel,
    String? fromMeta,
    ReflectionPeriod fromPeriod,
    DateTime fromStart,
    int direction,
  })?
  _arrival;

  /// The drill, both directions: an instant swap whose landed page carries
  /// the transformation in its own elements. No beats, no holds, no overlay.
  void _drill(
    ReflectionPeriod period,
    DateTime start, {
    required String fromLabel,
    required String? fromMeta,
    required ReflectionPeriod fromPeriod,
    required DateTime fromStart,
    required bool deeper,
  }) {
    _arrival = (
      start: start,
      fromLabel: fromLabel,
      fromMeta: fromMeta,
      fromPeriod: fromPeriod,
      fromStart: fromStart,
      direction: deeper ? 1 : -1,
    );
    _pendingDrillStart = start;
    context.read<ReflectionsCubit>().setViewedPeriod(period);
  }

  /// Pages whose write-on this visit already SPENT: the write began while the
  /// page was current, or the pager committed to it mid-write. A
  /// peeked-then-abandoned neighbor starts writing (its first pixel is its
  /// cue) but is not spent, so backing out below the commit threshold does
  /// not eat the arrival. A regenerate changes the key and re-earns it.
  final Set<String> _revealed = {};

  /// Pages whose write-on has begun at all, spent or not; [_revealed] takes
  /// from here when the pager commits to a page whose ink already runs.
  final Set<String> _started = {};

  /// The reading fold ([scrubberScrollFold]): off once the reader travels
  /// down, back on the first deliberate move up. The anchor is the extremum
  /// offset since the last flip.
  bool _scrollShown = true;
  double _scrollAnchor = 0;

  /// True while the pager itself is in horizontal motion.
  bool _pagerActive = false;

  /// True while a finger owns the scrubber (also holds the page physics).
  bool _scrubbing = false;

  /// The capsule's last computed visibility; notifications setState only when
  /// the rule flips, never per scroll tick.
  bool _scrubberShown = false;

  bool _visibleFor(int count) => scrubberVisible(
    count: count,
    readingShown: _scrollShown,
    pagerActive: _pagerActive,
    scrubbing: _scrubbing,
  );

  void _refreshScrubber({required int count}) {
    final shown = _visibleFor(count);
    if (shown == _scrubberShown) return;
    setState(() => _scrubberShown = shown);
  }

  /// A scrub flip always rebuilds: the pages render settled while the finger
  /// owns the position, and the landed page's write-on resumes on release.
  void _setScrubbing({required bool value, required int count}) {
    if (!mounted || _scrubbing == value) return;
    setState(() {
      _scrubbing = value;
      _scrubberShown = _visibleFor(count);
    });
  }

  /// Keeps the VIEWED PAGE stable when the timeline changes length: pages are
  /// remapped by identity, not position.
  PageController _configure(List<ReflectionPage> timeline) {
    final page = pageForStart(timeline, _viewedStart);
    // Pin identity to the resolved page NOW: a null or unknown one left
    // unresolved would re-resolve against a grown timeline later and teleport
    // the pager off the page the user was reading.
    _viewedStart = timeline[page].periodStart;
    final controller = _controller;
    if (controller != null && timeline.length == _pageCount) return controller;
    final old = controller;
    final fresh = PageController(initialPage: page);
    _controller = fresh;
    _pageCount = timeline.length;
    _settledPage = page;
    if (old != null) {
      // The PageView still holds the old controller until it rebuilds;
      // disposing mid-build would detach a dead ChangeNotifier. And the
      // swap keeps the OLD scroll position (initialPage only applies to a
      // first attach), so land the kept page explicitly once attached.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
        if (fresh.hasClients && fresh.page?.round() != page) fresh.jumpToPage(page);
      });
    }
    return fresh;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.watch<ReflectionsCubit>();
    final state = cubit.state;
    // A period switch is a different timeline entirely: drop the reveal ledger
    // and land on that period's newest page, never a stale page identity.
    if (_shownPeriod != state.viewedPeriod) {
      if (_shownPeriod != null) {
        _revealed.clear();
        _started.clear();
        _viewedStart = _pendingDrillStart;
        // A switch no drill asked for (the cubit falling back when a period
        // empties) must not replay a stale arrival on whatever page it
        // lands: a daily start can collide with a weekly one.
        if (_pendingDrillStart == null) _arrival = null;
        _pageCount = 0;
        // A fresh pager's first attach never reports onPageChanged, so the
        // reading fold must reset here: the landed page rests at its top,
        // and a capsule folded away by the departed page's scroll would
        // otherwise stay hidden.
        _scrollShown = true;
        _scrollAnchor = 0;
        // The departed pager unmounts mid-flight on a drill tapped during a
        // settle, so its ScrollEnd never arrives to clear this.
        _pagerActive = false;
      }
      _shownPeriod = state.viewedPeriod;
    } else if (_pendingDrillStart != null) {
      // A drill whose period switch did not happen (the cubit refused or
      // fell back): its arrival must not replay a transformation on a page
      // that never changed.
      _arrival = null;
    }
    // Consumed by the switch above or stale (the cubit landed elsewhere);
    // either way it must not steer a later, unrelated period change.
    _pendingDrillStart = null;
    final timeline = state.timeline;
    final controller = _configure(timeline);
    final viewedIndex = pageForStart(timeline, _viewedStart);
    final viewed = timeline[viewedIndex];
    // Recomputed every build so a fresh timeline (a 1-page history) lands
    // right without waiting for a scroll tick; notifications only setState
    // when this flips.
    final shown = _visibleFor(timeline.length);
    _scrubberShown = shown;
    // ONE smart back, resolved by the VIEWED page: with a stored ancestor
    // above it, back reshapes up a level in place; only at the top of the
    // hierarchy does it pop the route. The route-level edge swipe always
    // pops, so no depth ever traps the user.
    final crumb = breadcrumbTarget(
      period: state.viewedPeriod,
      start: viewed.periodStart,
      reflectedStartsByPeriod: state.reflectedStartsByPeriod,
      localeId: localeTag(context),
    );

    return AppScaffold(
      background: theme.screens.settings,
      onBack: crumb == null
          ? () => context.pop()
          : () => _drill(
              crumb.period,
              crumb.start,
              fromLabel: periodRangeLabel(
                state.viewedPeriod,
                viewed.periodStart,
                localeTag(context),
              ),
              fromMeta: _metaLineOf(viewed, l10n, localeTag(context)),
              fromPeriod: state.viewedPeriod,
              fromStart: viewed.periodStart,
              deeper: false,
            ),
      actions: [ReflectionsMenu(viewed: viewed, color: theme.topBar.iconColor)],
      // Like the entry screen: the pages run full height and wash under the
      // frosted bar (their top padding clears it), so the bar reads as
      // translucent over the reading text rather than a solid band.
      // One listener reads both axes: the pager's own rest anchors the eager
      // physics, and the pages' vertical scrolls drive the capsule's fade.
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final horizontal = notification.metrics.axis == Axis.horizontal;
          // Only true movement counts as activity: a settled swipe trails a
          // UserScrollNotification(idle) AFTER its End, which would latch
          // the flag back on and defeat the reading fold for good.
          final moving =
              notification is ScrollStartNotification ||
              notification is ScrollUpdateNotification ||
              notification is OverscrollNotification;
          if (horizontal && moving) _pagerActive = true;
          if (horizontal && notification is ScrollEndNotification) {
            _settledPage = controller.page?.round() ?? _settledPage;
            _pagerActive = false;
          }
          if (!horizontal && notification is ScrollUpdateNotification) {
            final fold = scrubberScrollFold(
              shown: _scrollShown,
              anchor: _scrollAnchor,
              offset: notification.metrics.pixels,
              slack: theme.scrubber.slack,
              topBand: theme.scrubber.topBand,
            );
            _scrollShown = fold.shown;
            _scrollAnchor = fold.anchor;
          }
          _refreshScrubber(count: timeline.length);
          return false;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                // A period switch is a wholly new timeline: a fresh pager
                // whose FIRST attach honors the landing page, instead of one
                // frame at the old scroll position followed by a jump.
                key: ValueKey(state.viewedPeriod),
                controller: controller,
                // Snapping would stack the framework's PageScrollPhysics
                // OUTSIDE the eager physics, and its half-page rule settles
                // every in-range release before ours is ever asked.
                pageSnapping: false,
                physics: _EagerPagePhysics(
                  settledPage: () => _settledPage,
                  held: () => _scrubbing,
                  turnSpring: theme.motion.periodTurnSpring,
                ),
                itemCount: timeline.length,
                onPageChanged: (index) {
                  final page = timeline[index];
                  // A drill's landing reports through here too when the swap
                  // needs an explicit jump (a longer timeline keeps the old
                  // scroll position, so _configure jumps to the target): that
                  // jump must not tick or retire the arrival the landed page
                  // is about to play. Everything else is the user paging.
                  final landing = page.periodStart == _arrival?.start;
                  // Pages flown through mid-scrub tick neither the hand nor
                  // the ledger; the scrubber answers the grab and the settle
                  // itself, and only a real commit spends a write-on.
                  if (!_scrubbing && !landing) Haptics.selection();
                  setState(() {
                    _viewedStart = page.periodStart;
                    // Paging away retires a landed drill's roll context, so a
                    // later revisit shows a plain title instead of replaying.
                    if (!landing) _arrival = null;
                    // A fresh page always rests at its top (pages are
                    // disposed off screen), so the fold starts shown.
                    _scrollShown = true;
                    _scrollAnchor = 0;
                    // Committing to a page whose ink already runs spends its
                    // write-on; see [_revealed].
                    final key = revealKeyFor(page);
                    if (!_scrubbing && _started.contains(key)) _revealed.add(key);
                  });
                },
                itemBuilder: (context, index) {
                  final page = timeline[index];
                  final arrival = _arrival;
                  final arriving = arrival?.start == page.periodStart;
                  final reflectedDays =
                      state.reflectedStartsByPeriod[ReflectionPeriod.daily] ?? const <DateTime>{};
                  final reflectedWeeks =
                      state.reflectedStartsByPeriod[ReflectionPeriod.weekly] ?? const <DateTime>{};
                  String fromLabel() =>
                      periodRangeLabel(state.viewedPeriod, page.periodStart, localeTag(context));
                  String? fromMeta() => _metaLineOf(page, l10n, localeTag(context));
                  // The departed level's own strip or rows, rebuilt unseen on
                  // the landed page to measure the seat that glides shut.
                  final departedStrip = arriving && arrival!.fromPeriod == ReflectionPeriod.weekly
                      ? _WeekDayStrip(
                          weekStart: arrival.fromStart,
                          reflectedDays: reflectedDays,
                          journaledDays: state.journaledDays,
                          onDayTap: (_) {},
                        )
                      : null;
                  final departedContents =
                      arriving && arrival!.fromPeriod == ReflectionPeriod.monthly
                      ? _MonthContents(
                          monthStart: arrival.fromStart,
                          reflectedWeeks: reflectedWeeks,
                          reflectedDays: reflectedDays,
                          journaledDays: state.journaledDays,
                          onWeekTap: (_) {},
                        )
                      : null;
                  return _PeriodPage(
                    page: page,
                    period: state.viewedPeriod,
                    rollFrom: arriving ? arrival!.fromLabel : null,
                    metaRollFrom: arriving ? arrival!.fromMeta : null,
                    rollDirection: arrival?.direction ?? 1,
                    departedStrip: departedStrip,
                    departedContents: departedContents,
                    strip: state.viewedPeriod == ReflectionPeriod.weekly
                        ? _WeekDayStrip(
                            weekStart: page.periodStart,
                            reflectedDays: reflectedDays,
                            journaledDays: state.journaledDays,
                            onDayTap: (day) => _drill(
                              ReflectionPeriod.daily,
                              day,
                              fromLabel: fromLabel(),
                              fromMeta: fromMeta(),
                              fromPeriod: state.viewedPeriod,
                              fromStart: page.periodStart,
                              deeper: true,
                            ),
                          )
                        : null,
                    contents: state.viewedPeriod == ReflectionPeriod.monthly
                        ? _MonthContents(
                            monthStart: page.periodStart,
                            reflectedWeeks: reflectedWeeks,
                            reflectedDays: reflectedDays,
                            journaledDays: state.journaledDays,
                            onWeekTap: (start) => _drill(
                              ReflectionPeriod.weekly,
                              start,
                              fromLabel: fromLabel(),
                              fromMeta: fromMeta(),
                              fromPeriod: state.viewedPeriod,
                              fromStart: page.periodStart,
                              deeper: true,
                            ),
                          )
                        : null,
                    regenerating: state.regenerating == page.periodStart,
                    held: _scrubbing,
                    revealed: _revealed,
                    length: state.style.length,
                    disabled: state.allDisabled,
                    onEnable: () => unawaited(cubit.enableDefaults()),
                    notice: state.regenerateFailed ? l10n.reflectionRegenerateFailed : null,
                    onNoticeDismiss: cubit.clearRegenerateFailed,
                    onWriteStarted: () {
                      if (!mounted) return;
                      final key = revealKeyFor(page);
                      _started.add(key);
                      if (page.periodStart != viewed.periodStart) return;
                      setState(() => _revealed.add(key));
                    },
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _capsuleSeat(context),
              child: Center(
                child: IgnorePointer(
                  ignoring: !shown,
                  // Mirrored along one path: a soft rise in, a quicker sink
                  // out. The fade rides a single fraction into the scrubber
                  // rather than an Opacity layer: a BackdropFilter inside
                  // one samples the layer's own empty buffer, so the blur
                  // would pop instead of fading. Reduce Motion keeps only
                  // the fade; a fully-hidden capsule builds nothing.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: shown ? 1.0 : 0.0),
                    duration: shown ? theme.motion.indicator : theme.motion.crossfade,
                    curve: shown ? theme.motion.indicatorCurve : Curves.easeIn,
                    builder: (context, fade, _) {
                      if (fade <= 0) return const SizedBox.shrink();
                      final sink = context.reduceMotion
                          ? 0.0
                          : (1 - fade) * theme.scrubber.sinkDistance;
                      return Transform.translate(
                        offset: Offset(0, sink),
                        child: ReflectionScrubber(
                          controller: controller,
                          count: timeline.length,
                          timelineKey: state.viewedPeriod,
                          restPage: viewedIndex,
                          fade: fade,
                          onScrubStart: () => _setScrubbing(value: true, count: timeline.length),
                          onScrubEnd: () => _setScrubbing(value: false, count: timeline.length),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One period's page: ONE vertical scroll holding the range title and the
/// state's body, so a long reflection reads to its end with the title
/// scrolling away naturally. Reflected and regenerating pages render through
/// the SAME [InkReveal] element, so a regenerate dissolves the words on
/// screen instead of swapping widgets.
class _PeriodPage extends StatelessWidget {
  const _PeriodPage({
    required this.page,
    required this.period,
    required this.rollFrom,
    required this.metaRollFrom,
    required this.rollDirection,
    required this.departedStrip,
    required this.departedContents,
    required this.strip,
    required this.contents,
    required this.regenerating,
    required this.held,
    required this.revealed,
    required this.length,
    required this.disabled,
    required this.onEnable,
    required this.notice,
    required this.onNoticeDismiss,
    required this.onWriteStarted,
  });

  final ReflectionPage page;

  /// The viewed period, for the page's range title.
  final ReflectionPeriod period;

  /// Non-null on the page a drill just landed: the title ROLLS from this
  /// label to its own (the odometer way, no fade), the calendar pieces stand
  /// with the swap while the departed seat glides shut, and the quiet pieces
  /// unfold. The prose's ink write-on plays through the ordinary reveal
  /// ledger; ink carries only the content text.
  final String? rollFrom;

  /// The departed page's meta line, which the landed page's own subtitle
  /// rolls from; null when the departed page had none (the subtitle then
  /// unfolds like the other quiet pieces).
  final String? metaRollFrom;

  /// +1 rolls up (a drill deeper), -1 down (a climb).
  final int rollDirection;

  /// The departed week's day strip, never painted: it measures the seat
  /// under the title that [_SeatClose] glides shut on a drill landing; null
  /// off a landing or when the departed page wore none.
  final Widget? departedStrip;

  /// The departed month's week rows, measuring their closing seat below the
  /// body; null likewise.
  final Widget? departedContents;

  /// A week page's day strip, under the title where the mock put it, or null.
  final Widget? strip;

  /// A month page's week rows, after the body like a contents block, or null.
  final Widget? contents;
  final bool regenerating;

  /// The scrubber's grip holds the surface: pages render settled, starting no
  /// write-ons; the landed page re-earns its write when the grip releases.
  final bool held;
  final Set<String> revealed;
  final ReflectionLength length;

  /// The user turned reflections off: every page carries the standing notice
  /// card, since history stays readable while the open period goes unwritten.
  final bool disabled;

  /// The notice card's button: reenables in place (the card then dissolves).
  final VoidCallback onEnable;

  /// The screen's transient failure line, or null; rendered in the page's own
  /// flow (floated under the bar it collides with the title, bare
  /// text-on-text).
  final String? notice;
  final VoidCallback onNoticeDismiss;
  final VoidCallback onWriteStarted;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SelectableProse(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          // Past the bar and its fade tail: the material is opaque through the
          // row and only melts across the tail, so the title clears the wash.
          AppTopBar.heightOf(context) + theme.topBar.fadeTail,
          AppSpacing.xl,
          // Past the floating capsule too, so a short page's last lines never
          // rest under it.
          _capsuleSeat(context) + theme.scrubber.height + AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ONE selection region spans the page so a tap anywhere clears a
            // standing selection, but only the reflection's prose is content:
            // the chrome - title, calendar pieces, notices, meta - opts out.
            SelectionContainer.disabled(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReflectionsDisabledSlot(disabled: disabled, onEnable: onEnable),
                  AppNotice(message: notice, onDismiss: onNoticeDismiss),
                  _PageTitle(
                    label: periodRangeLabel(period, page.periodStart, localeTag(context)),
                    rollFrom: rollFrom,
                    direction: rollDirection,
                  ),
                  // The gap rides inside the seat, so a closing seat closes
                  // it too.
                  if (departedStrip != null)
                    _SeatClose(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: departedStrip,
                      ),
                    ),
                  if (strip != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: strip,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PageBody(
              page: page,
              period: period,
              entering: rollFrom != null,
              metaRollFrom: metaRollFrom,
              rollDirection: rollDirection,
              regenerating: regenerating,
              held: held,
              revealed: revealed,
              length: length,
              onWriteStarted: onWriteStarted,
            ),
            if (departedContents != null || contents != null)
              SelectionContainer.disabled(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (departedContents != null)
                      _SeatClose(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxl),
                          child: departedContents,
                        ),
                      ),
                    if (contents != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxl),
                        child: contents,
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

/// A week page's seven days, rendered whatever the page's own status: the
/// strip is about the days, not the reflection.
class _WeekDayStrip extends StatelessWidget {
  const _WeekDayStrip({
    required this.weekStart,
    required this.reflectedDays,
    required this.journaledDays,
    required this.onDayTap,
  });

  final DateTime weekStart;
  final Set<DateTime> reflectedDays;
  final Set<DateTime> journaledDays;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final days = daysOfWeek(weekStart);
    return DayChipRow(
      days: days,
      states: [
        for (final day in days)
          dayChipState(day: day, reflectedDays: reflectedDays, journaledDays: journaledDays),
      ],
      onDayTap: onDayTap,
    );
  }
}

/// A month page's weeks, below the reflection like a contents block.
class _MonthContents extends StatelessWidget {
  const _MonthContents({
    required this.monthStart,
    required this.reflectedWeeks,
    required this.reflectedDays,
    required this.journaledDays,
    required this.onWeekTap,
  });

  final DateTime monthStart;
  final Set<DateTime> reflectedWeeks;
  final Set<DateTime> reflectedDays;
  final Set<DateTime> journaledDays;
  final ValueChanged<DateTime> onWeekTap;

  @override
  Widget build(BuildContext context) {
    return MonthWeekRows(
      weeks: monthWeekRows(
        monthStart: monthStart,
        reflectedWeeks: reflectedWeeks,
        reflectedDays: reflectedDays,
        journaledDays: journaledDays,
        localeId: localeTag(context),
      ),
      onWeekTap: onWeekTap,
    );
  }
}

/// The page's range title. On a drill landing it ROLLS from the departed
/// page's label to its own, the odometer way ([RollingText]: glyphs travel
/// through the line box, nothing fades), so the title visibly transforms
/// between levels instead of being replaced. A plain [Text] otherwise.
class _PageTitle extends StatefulWidget {
  const _PageTitle({required this.label, required this.rollFrom, required this.direction});

  final String label;
  final String? rollFrom;
  final int direction;

  @override
  State<_PageTitle> createState() => _PageTitleState();
}

class _PageTitleState extends State<_PageTitle> {
  /// Starts as the departed label for one frame so the roll has a FROM state;
  /// the switch to the real label starts the odometer.
  late String _shown = widget.rollFrom ?? widget.label;

  @override
  void initState() {
    super.initState();
    if (widget.rollFrom != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = widget.label);
      });
    }
  }

  @override
  void didUpdateWidget(_PageTitle old) {
    super.didUpdateWidget(old);
    // A timeline remap can hand this element another page: show its truth
    // immediately, never a roll it did not earn.
    if (old.label != widget.label) _shown = widget.label;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppType.display2.copyWith(color: context.theme.text);
    if (widget.rollFrom == null) return Text(widget.label, style: style);
    return RollingText(text: _shown, style: style, direction: widget.direction);
  }
}

/// Unfolds a drill landing's quiet piece - a placeholder body, the meta line
/// - into its seat: pure height, no opacity. The content is simply not
/// there, then grows into place. The calendar pieces stand with the swap;
/// only the departed level's seat closes ([_SeatClose]).
class _Unfold extends StatelessWidget {
  const _Unfold({required this.child, this.enabled = true});

  final Widget child;

  /// False renders the child bare, so call sites stay one expression whether
  /// or not the page is a drill landing.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.reduceMotion ? Duration.zero : context.theme.motion.expand,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        if (t <= 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(alignment: Alignment.topCenter, heightFactor: t, child: child),
        );
      },
      child: child,
    );
  }
}

/// Closes the seat a departed calendar piece left behind. The piece itself
/// leaves WITH the swap - nothing lingers to be watched leaving - but its
/// footprint glides shut, so the content below settles into place instead of
/// jumping. The child only measures the seat; it is never painted.
class _SeatClose extends StatelessWidget {
  const _SeatClose({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: context.theme.motion.expand,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        if (t <= 0) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topCenter,
          heightFactor: t,
          child: IgnorePointer(child: Opacity(opacity: 0, child: child)),
        );
      },
      child: child,
    );
  }
}

/// The localized voice name, or null for records from before it was stored.
String? _voiceLabelOf(AppLocalizations l10n, ReflectionVoice? voice) => switch (voice) {
  ReflectionVoice.literary => l10n.reflectionVoiceLiterary,
  ReflectionVoice.observational => l10n.reflectionVoiceObservational,
  ReflectionVoice.sparse => l10n.reflectionVoiceSparse,
  null => null,
};

/// The page's reading meta - voice and written date - or null when it holds
/// no settled text to date.
String? _metaLineOf(ReflectionPage page, AppLocalizations l10n, String localeId) {
  final reflection = page.reflection;
  if (reflection?.text == null) return null;
  return reflectionMetaLine(
    voiceLabel: _voiceLabelOf(l10n, reflection!.voice),
    writtenLabel: l10n.reflectionWrittenOn(
      shortDateLabel(reflection.generatedAt.toLocal(), localeId),
    ),
  );
}

/// The meta line under the settled words, always set to the left edge. On a
/// drill landing it rolls from the departed page's meta the way the title
/// rolls - one quick unified roll, the bar subtitle's pace - or unfolds when
/// the departed page had none.
class _PageMeta extends StatefulWidget {
  const _PageMeta({
    required this.text,
    required this.rollFrom,
    required this.direction,
    required this.entering,
  });

  final String text;
  final String? rollFrom;
  final int direction;
  final bool entering;

  @override
  State<_PageMeta> createState() => _PageMetaState();
}

class _PageMetaState extends State<_PageMeta> {
  /// Starts as the departed meta for one frame so the roll has a FROM state.
  late String _shown = widget.rollFrom ?? widget.text;

  @override
  void initState() {
    super.initState();
    if (widget.rollFrom != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = widget.text);
      });
    }
  }

  @override
  void didUpdateWidget(_PageMeta old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _shown = widget.text;
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    final style = AppType.footnote.copyWith(color: context.theme.textSecondary);
    if (widget.rollFrom != null) {
      return RollingText(
        text: _shown,
        style: style,
        direction: widget.direction,
        window: motion.subtitleRoll,
        stagger: Duration.zero,
      );
    }
    final text = Text(widget.text, style: style);
    return widget.entering ? _Unfold(child: text) : text;
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.page,
    required this.period,
    required this.entering,
    required this.metaRollFrom,
    required this.rollDirection,
    required this.regenerating,
    required this.held,
    required this.revealed,
    required this.length,
    required this.onWriteStarted,
  });

  final ReflectionPage page;

  /// The viewed period, so a quiet page names itself (day, week, month).
  final ReflectionPeriod period;

  /// This page is a drill's landing: the pieces the ink cannot carry - a
  /// placeholder body, the meta line - transform into place instead of
  /// popping, so a quiet page changes as completely as a written one.
  final bool entering;

  /// The departed page's meta line for the landing's subtitle roll; see
  /// [_PageMeta].
  final String? metaRollFrom;

  /// +1 rolls up (a drill deeper), -1 down (a climb).
  final int rollDirection;
  final bool regenerating;
  final bool held;
  final Set<String> revealed;
  final ReflectionLength length;
  final VoidCallback onWriteStarted;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;

    if (regenerating || page.status == ReflectionPageStatus.reflected) {
      final reflection = page.reflection;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The write-on starts with the page's first visible pixel (the
          // pager only builds a page as it scrolls into view), not at the
          // 50% crossing, which read as the page refusing to load mid-drag.
          // Whether that start SPENDS the replay is the parent ledger's call.
          InkReveal(
            phase: inkPhaseFor(
              page: page,
              regenerating: regenerating,
              held: held,
              revealed: revealed,
            ),
            color: theme.text,
            background: theme.screens.settings,
            placeholderLines: pendingLinesFor(
              page: page,
              width: MediaQuery.sizeOf(context).width - AppSpacing.xl * 2,
              fontSize: MediaQuery.textScalerOf(context).scale(AppType.body.fontSize!),
              length: length,
            ),
            onWriteStarted: onWriteStarted,
            child: Text(
              reflection?.text ?? '',
              style: AppType.body.copyWith(color: theme.text, height: 1.45),
            ),
          ),
          // The reading meta rides under the settled words; while a
          // regenerate is in flight it would date the dissolving text, so
          // it waits for the new arrival.
          if (!regenerating && reflection?.text != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SelectionContainer.disabled(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _PageMeta(
                  text: _metaLineOf(page, l10n, localeTag(context))!,
                  rollFrom: entering ? metaRollFrom : null,
                  direction: rollDirection,
                  entering: entering,
                ),
              ),
            ),
          ],
        ],
      );
    }
    // reflected is handled above, so the placeholder is always present here.
    final placeholder = reflectionPlaceholderContent(l10n, page.status, period)!;
    return _Unfold(
      enabled: entering,
      child: SelectionContainer.disabled(
        child: ReflectionPlaceholder(
          title: placeholder.title,
          body: placeholder.body,
          marker: placeholder.marker,
        ),
      ),
    );
  }
}

/// The screen's editorial page: a display title and a line of writing at the
/// top left, the same first-page-of-the-journal vocabulary as home's empty
/// state, not a card floated in the middle. Scrollable so it sits under the
/// frosted bar like the pager it replaces.
class _Editorial extends StatelessWidget {
  const _Editorial({required this.copy});

  final (String, String) copy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppScaffold.topPaddingOf(context) + AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
      ),
      children: [ReflectionEditorialBody(copy: copy)],
    );
  }
}

/// Page physics that commit early: the framework's [PageScrollPhysics] rounds
/// to the nearest page, demanding a half-viewport drag before a slow release
/// turns the page. This settles by [eagerPageTarget] instead - a fifth of a
/// page, or any flick, commits - anchored on the last RESTED page the state
/// supplies (reading the live rounding here would rebuild the 50% rule).
class _EagerPagePhysics extends ScrollPhysics {
  const _EagerPagePhysics({
    required this.settledPage,
    required this.held,
    required this.turnSpring,
    super.parent,
  });

  /// The page the pager last came to rest on.
  final ValueGetter<int> settledPage;

  /// True while a scrub owns the position: every jumpTo ends in a ballistic
  /// kick, and the snap it would start here fights the finger between moves.
  /// Held means no simulation; the scrubber settles explicitly on release.
  final ValueGetter<bool> held;

  /// The settle's own spring ([AppMotion.periodTurnSpring]), softer than the
  /// framework default so the ink bridge pours at the turn's liquid pace.
  final SpringDescription turnSpring;

  @override
  _EagerPagePhysics applyTo(ScrollPhysics? ancestor) => _EagerPagePhysics(
    settledPage: settledPage,
    held: held,
    turnSpring: turnSpring,
    parent: buildParent(ancestor),
  );

  @override
  bool get allowImplicitScrolling => false;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (held()) return null;
    // Overscroll keeps the framework's edge spring.
    if (position.outOfRange) return super.createBallisticSimulation(position, velocity);
    final tolerance = toleranceFor(position);
    final page = position.pixels / position.viewportDimension;
    final flick = velocity.abs() > tolerance.velocity ? velocity.sign.toInt() : 0;
    final target = eagerPageTarget(page: page, from: settledPage(), flick: flick);
    final pixels = (target * position.viewportDimension).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((pixels - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      turnSpring,
      position.pixels,
      pixels,
      velocity,
      tolerance: tolerance,
    );
  }
}
