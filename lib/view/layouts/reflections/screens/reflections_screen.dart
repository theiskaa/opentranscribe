import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_labels.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_page_logic.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflections_menu.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';

/// The reflections week pager: each closed week is a full reading page - its
/// range as the title, the reflection drawn below with the invisible-ink
/// reveal - swiped between horizontally (oldest first; the landing page is
/// the newest closed week, and the open week is never a page). The page IS
/// the chrome: a plain range title, no switcher, no position strip. ONE
/// top-bar menu acts on the viewed week and carries the settings knobs.
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

  /// The editorial copy for an empty screen: the first-run invitation when
  /// the model runs here, else the state and what would make it work.
  /// Instructions only for the off state: iOS has no public URL to the Apple
  /// Intelligence & Siri pane (only the app's own Settings page), so a button
  /// would land the user in the wrong place; the body says where to go instead.
  (String, String) _editorialCopy(AppLocalizations l10n, ReflectionsState state) {
    if (state.available) return (l10n.reflectionsEmptyTitle, l10n.reflectionsEmptyBody);
    return switch (state.availability.status) {
      ReflectionAvailabilityStatus.notEnabled => (l10n.reflectionOffTitle, l10n.reflectionOffBody),
      ReflectionAvailabilityStatus.modelNotReady => (
        l10n.reflectionPreparingTitle,
        l10n.reflectionPreparingBody,
      ),
      // deviceNotEligible, unsupported (and the unreachable available).
      _ => (l10n.reflectionUnsupportedTitle, l10n.reflectionUnsupportedBody),
    };
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
        child: _Editorial(copy: _editorialCopy(l10n, state)),
      );
    }
    return _WeekPagerView(initialWeekKey: widget.initialWeekKey);
  }
}

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

  /// Keeps the VIEWED WEEK stable when the timeline changes length: pages are
  /// remapped by identity, not position (the WeekCalendar lesson).
  PageController _configure(List<ReflectionWeek> timeline) {
    final page = pageForWeek(timeline, _viewedWeek);
    var controller = _controller;
    if (controller != null && timeline.length == _pageCount) return controller;
    final old = controller;
    controller = PageController(initialPage: page);
    _controller = controller;
    _pageCount = timeline.length;
    _settledPage = page;
    if (old != null) {
      // The PageView still holds the old controller until it rebuilds;
      // disposing mid-build would detach a dead ChangeNotifier.
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    return controller;
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

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      actions: [ReflectionsMenu(viewed: viewed, color: theme.topBar.iconColor)],
      // Like the entry screen: the pages run full height and wash under the
      // frosted bar (their top padding clears it), so the bar reads as
      // translucent over the reading text rather than a solid band.
      // The anchor listens for the pager's own rest, not the pages' vertical
      // scrolls bubbling through.
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.horizontal) {
            _settledPage = controller.page?.round() ?? _settledPage;
          }
          return false;
        },
        child: PageView.builder(
          controller: controller,
          // Snapping would stack the framework's PageScrollPhysics OUTSIDE
          // the eager physics, and its half-page rule settles every in-range
          // release before ours is ever asked.
          pageSnapping: false,
          physics: _EagerPagePhysics(settledPage: () => _settledPage),
          itemCount: timeline.length,
          onPageChanged: (page) {
            Haptics.selection();
            final week = timeline[page];
            setState(() {
              _viewedWeek = week.weekStart;
              // Committing to a page whose ink already runs spends its
              // write-on; see [_revealed].
              final key = revealKeyFor(week);
              if (_started.contains(key)) _revealed.add(key);
            });
          },
          itemBuilder: (context, page) {
            final week = timeline[page];
            return _WeekPage(
              week: week,
              regenerating: state.regenerating == week.weekStart,
              revealed: _revealed,
              length: state.style.length,
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
    required this.revealed,
    required this.length,
    required this.notice,
    required this.onNoticeDismiss,
    required this.onWriteStarted,
  });

  final ReflectionWeek week;
  final bool regenerating;
  final Set<String> revealed;
  final ReflectionLength length;

  /// The screen's transient failure line, or null; rendered in the page's own
  /// flow (floated under the bar it collides with the title, bare
  /// text-on-text).
  final String? notice;
  final VoidCallback onNoticeDismiss;
  final VoidCallback onWriteStarted;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        // Past the bar and its fade tail: the material is opaque through the
        // row and only melts across the tail, so the title clears the wash.
        AppTopBar.heightOf(context) + theme.topBar.fadeTail,
        AppSpacing.xl,
        MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppNotice(message: notice, onDismiss: onNoticeDismiss),
          Text(
            weekRangeLabel(week.weekStart, localeTag(context)),
            style: AppType.display2.copyWith(color: theme.text),
          ),
          const SizedBox(height: AppSpacing.xl),
          _PageBody(
            week: week,
            regenerating: regenerating,
            revealed: revealed,
            length: length,
            onWriteStarted: onWriteStarted,
          ),
        ],
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
    required this.revealed,
    required this.length,
    required this.onWriteStarted,
  });

  final ReflectionWeek week;
  final bool regenerating;
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
            phase: inkPhaseFor(week: week, regenerating: regenerating, revealed: revealed),
            color: theme.text,
            background: theme.screens.settings,
            placeholderLines: pendingLinesFor(
              week: week,
              width: MediaQuery.sizeOf(context).width - AppSpacing.xl * 2,
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
    final (title, body, marker) = switch (week.status) {
      ReflectionWeekStatus.silent => (l10n.reflectionQuietWeek, l10n.reflectionQuietBody, true),
      // The erased page drops the bullet: an absence the user authored, not a
      // quiet one the model recorded.
      ReflectionWeekStatus.erased => (l10n.reflectionErasedTitle, l10n.reflectionErasedBody, false),
      // unreflected (reflected handled above).
      _ => (l10n.reflectionWaitingTitle, l10n.reflectionWaitingBody, false),
    };
    final titleStyle = AppType.title.copyWith(color: theme.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (marker) ...[Text('·', style: titleStyle), const SizedBox(width: AppSpacing.sm)],
            Flexible(child: Text(title, style: titleStyle)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.4)),
      ],
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
    final theme = context.theme;
    final (title, body) = copy;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppScaffold.topPaddingOf(context) + AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
      ),
      children: [
        Text(title, style: AppType.display.copyWith(color: theme.text)),
        const SizedBox(height: AppSpacing.md),
        Text(body, style: AppType.body.copyWith(color: theme.textSecondary, height: 1.4)),
      ],
    );
  }
}

/// Page physics that commit early: the framework's [PageScrollPhysics] rounds
/// to the nearest page, demanding a half-viewport drag before a slow release
/// turns the week. This settles by [eagerPageTarget] instead - a fifth of a
/// page, or any flick, commits - anchored on the last RESTED page the state
/// supplies (reading the live rounding here would rebuild the 50% rule).
class _EagerPagePhysics extends ScrollPhysics {
  const _EagerPagePhysics({required this.settledPage, super.parent});

  /// The page the pager last came to rest on.
  final ValueGetter<int> settledPage;

  @override
  _EagerPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _EagerPagePhysics(settledPage: settledPage, parent: buildParent(ancestor));

  @override
  bool get allowImplicitScrolling => false;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
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
    return ScrollSpringSimulation(spring, position.pixels, pixels, velocity, tolerance: tolerance);
  }
}
