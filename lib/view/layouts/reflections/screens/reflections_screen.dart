import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/reflections/components/disabled_card.dart';
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
import 'package:opentranscribe/view/widgets/selectable_prose.dart';

/// The reflections week pager: each closed week is a full reading page - its
/// range as the title, the reflection drawn below with the invisible-ink
/// reveal - swiped between horizontally (oldest first; the landing page is
/// the newest closed week, and the open week is never a page). The page IS
/// the chrome, with one floating exception: a frosted scrubber capsule at
/// bottom center reads (and drives) the position, fading away once the user
/// scrolls into the text. ONE top-bar menu acts on the viewed week and
/// carries the settings knobs.
/// Reads the root-scoped [ReflectionsCubit];
/// a week filling via the foreground catch-up updates its page in place.
///
/// Availability gates only generation affordances, never stored history. With
/// an empty timeline the screen is a single editorial page, explaining either
/// the empty first run or how to make the feature work.
///
/// This is the ONE reflections surface: a home card deep-links here through
/// [initialWeekKey] and lands on its week, with the same pages and the same
/// menu as the plain open.
class ReflectionsScreen extends StatefulWidget {
  const ReflectionsScreen({this.initialWeekKey, super.key});

  /// yyyy-MM-dd ([Reflection.keyFor]) of the week to land on; null (or an
  /// unknown week) lands on the newest closed week.
  final String? initialWeekKey;

  @override
  State<ReflectionsScreen> createState() => _ReflectionsScreenState();
}

class _ReflectionsScreenState extends State<ReflectionsScreen> {
  @override
  void initState() {
    super.initState();
    // Recording an entry emits nothing on the cubit (only reflection writes
    // do), so the timeline inputs can be stale mid-session; opening the
    // surface re-reads them.
    unawaited(context.read<ReflectionsCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<ReflectionsCubit>().state;

    // Timeline alone, not history: deleting the only reflection leaves a
    // tombstone (history empty, an erased page in the timeline), and that
    // page carries the regenerate route back. The first-run editorial there
    // would be a dead end.
    if (state.timeline.isEmpty) {
      return AppScaffold(
        background: theme.screens.settings,
        onBack: () => context.pop(),
        child: _Editorial(
          copy: reflectionEditorialCopy(
            l10n,
            available: state.available,
            status: state.availability.status,
          ),
        ),
      );
    }
    return _WeekPagerView(initialWeekKey: widget.initialWeekKey);
  }
}

/// Where the capsule rests above the screen's bottom edge. Shared with the
/// pages' bottom inset, so the text always clears the seat.
double _capsuleSeat(BuildContext context) => MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

/// The pager body: owns the controller, the viewed week, and the reveal ledger
/// (which weeks already wrote themselves on this visit).
class _WeekPagerView extends StatefulWidget {
  const _WeekPagerView({this.initialWeekKey});

  final String? initialWeekKey;

  @override
  State<_WeekPagerView> createState() => _WeekPagerViewState();
}

class _WeekPagerViewState extends State<_WeekPagerView> {
  PageController? _controller;
  int _pageCount = 0;

  /// The page the pager last came to REST on, feeding [_EagerPagePhysics] its
  /// gesture anchor. Updated only when scrolling truly ends: the live rounded
  /// page would recreate the framework's half-page commit rule.
  int _settledPage = 0;

  /// The viewed page's week identity; null lands on the newest closed week.
  /// Seeded from the deep-link key when a home card opened its week
  /// ([pageForWeek] falls back to the newest page for an unknown week).
  late DateTime? _viewedWeek = DateTime.tryParse(widget.initialWeekKey ?? '');

  /// Weeks whose write-on this visit already SPENT: the write began while the
  /// week was the current page, or the pager committed to it mid-write. A
  /// peeked-then-abandoned neighbor starts writing (its first pixel is its
  /// cue) but is not spent, so backing out below the commit threshold does
  /// not eat the arrival. A regenerate changes the key and re-earns it.
  final Set<String> _revealed = {};

  /// Weeks whose write-on has begun at all, spent or not; [_revealed] takes
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

  /// Keeps the VIEWED WEEK stable when the timeline changes length: pages are
  /// remapped by identity, not position.
  PageController _configure(List<ReflectionWeek> timeline) {
    final page = pageForWeek(timeline, _viewedWeek);
    // Pin identity to the resolved page NOW: a null or unknown week left
    // unresolved would re-resolve against a grown timeline later and teleport
    // the pager off the week the user was reading.
    _viewedWeek = timeline[page].weekStart;
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
      // first attach), so land the kept week explicitly once attached.
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
    final timeline = state.timeline;
    final controller = _configure(timeline);
    final viewed = timeline[pageForWeek(timeline, _viewedWeek)];
    // Recomputed every build so a fresh timeline (a 1-page history) lands
    // right without waiting for a scroll tick; notifications only setState
    // when this flips.
    final shown = _visibleFor(timeline.length);
    _scrubberShown = shown;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
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
                controller: controller,
                // Snapping would stack the framework's PageScrollPhysics
                // OUTSIDE the eager physics, and its half-page rule settles
                // every in-range release before ours is ever asked.
                pageSnapping: false,
                physics: _EagerPagePhysics(
                  settledPage: () => _settledPage,
                  held: () => _scrubbing,
                  turnSpring: theme.motion.weekTurnSpring,
                ),
                itemCount: timeline.length,
                onPageChanged: (page) {
                  // Pages flown through mid-scrub tick neither the hand nor
                  // the ledger; the scrubber answers the grab and the settle
                  // itself, and only a real commit spends a write-on.
                  if (!_scrubbing) Haptics.selection();
                  final week = timeline[page];
                  setState(() {
                    _viewedWeek = week.weekStart;
                    // A fresh page always rests at its top (pages are
                    // disposed off screen), so the fold starts shown.
                    _scrollShown = true;
                    _scrollAnchor = 0;
                    // Committing to a page whose ink already runs spends its
                    // write-on; see [_revealed].
                    final key = revealKeyFor(week);
                    if (!_scrubbing && _started.contains(key)) _revealed.add(key);
                  });
                },
                itemBuilder: (context, page) {
                  final week = timeline[page];
                  return _WeekPage(
                    week: week,
                    regenerating: state.regenerating == week.weekStart,
                    scrubbing: _scrubbing,
                    revealed: _revealed,
                    length: state.style.length,
                    disabled: !state.enabled,
                    onEnable: () => unawaited(cubit.setEnabled(true)),
                    notice: state.regenerateFailed ? l10n.reflectionRegenerateFailed : null,
                    onNoticeDismiss: cubit.clearRegenerateFailed,
                    onWriteStarted: () {
                      if (!mounted) return;
                      final key = revealKeyFor(week);
                      _started.add(key);
                      if (week.weekStart != viewed.weekStart) return;
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

/// One week's page: ONE vertical scroll holding the range title and the
/// state's body, so a long reflection reads to its end with the title
/// scrolling away naturally. Reflected and regenerating weeks render through
/// the SAME [InkReveal] element, so a regenerate dissolves the words on
/// screen instead of swapping widgets.
class _WeekPage extends StatelessWidget {
  const _WeekPage({
    required this.week,
    required this.regenerating,
    required this.scrubbing,
    required this.revealed,
    required this.length,
    required this.disabled,
    required this.onEnable,
    required this.notice,
    required this.onNoticeDismiss,
    required this.onWriteStarted,
  });

  final ReflectionWeek week;
  final bool regenerating;

  /// A finger owns the scrubber: pages fly by settled, starting no write-ons.
  final bool scrubbing;
  final Set<String> revealed;
  final ReflectionLength length;

  /// The user turned reflections off: every page carries the standing notice
  /// card, since history stays readable while the open week goes unwritten.
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
            ReflectionsDisabledSlot(disabled: disabled, onEnable: onEnable),
            AppNotice(message: notice, onDismiss: onNoticeDismiss),
            Text(
              weekRangeLabel(week.weekStart, localeTag(context)),
              style: AppType.display2.copyWith(color: theme.text),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PageBody(
              week: week,
              regenerating: regenerating,
              scrubbing: scrubbing,
              revealed: revealed,
              length: length,
              onWriteStarted: onWriteStarted,
            ),
          ],
        ),
      ),
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

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.week,
    required this.regenerating,
    required this.scrubbing,
    required this.revealed,
    required this.length,
    required this.onWriteStarted,
  });

  final ReflectionWeek week;
  final bool regenerating;
  final bool scrubbing;
  final Set<String> revealed;
  final ReflectionLength length;
  final VoidCallback onWriteStarted;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;

    if (regenerating || week.status == ReflectionWeekStatus.reflected) {
      final reflection = week.reflection;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The write-on starts with the page's first visible pixel (the
          // pager only builds a page as it scrolls into view), not at the
          // 50% crossing, which read as the page refusing to load mid-drag.
          // Whether that start SPENDS the replay is the parent ledger's call.
          InkReveal(
            phase: inkPhaseFor(
              week: week,
              regenerating: regenerating,
              scrubbing: scrubbing,
              revealed: revealed,
            ),
            color: theme.text,
            background: theme.screens.settings,
            placeholderLines: pendingLinesFor(
              week: week,
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
            Text(
              reflectionMetaLine(
                voiceLabel: _voiceLabelOf(l10n, reflection!.voice),
                writtenLabel: l10n.reflectionWrittenOn(
                  shortDateLabel(reflection.generatedAt.toLocal(), localeTag(context)),
                ),
              ),
              style: AppType.footnote.copyWith(color: theme.textSecondary),
            ),
          ],
        ],
      );
    }
    // reflected is handled above, so the placeholder is always present here.
    final placeholder = reflectionWeekPlaceholder(l10n, week.status)!;
    return ReflectionWeekPlaceholder(
      title: placeholder.title,
      body: placeholder.body,
      marker: placeholder.marker,
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
/// turns the week. This settles by [eagerPageTarget] instead - a fifth of a
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

  /// The settle's own spring ([AppMotion.weekTurnSpring]), softer than the
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
