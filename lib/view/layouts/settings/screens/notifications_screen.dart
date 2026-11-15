import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/notify/nudge_schedule.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/notifications_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/animated_reveal.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/time_field.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:reflections/reflections.dart';

/// Notifications: the local, on-device nudges. One master switch turns
/// reflection reminders on in a single tap and says when the next one lands;
/// the period tiles under it pick WHICH periods nudge, each naming its day,
/// and the time row says at what time. The scheduler and the settings under
/// it are generic, so a new notification type is another row here, not new
/// plumbing. Owns a [NotificationsCubit] and re-probes
/// permission on resume, so a grant changed in iOS Settings lands without a
/// relaunch.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with WidgetsBindingObserver {
  late final NotificationsCubit _cubit;

  /// The minute the "next" line reads from, so it turns over with the clock
  /// (a time passing, midnight) rather than only when the settings change.
  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _cubit = NotificationsCubit(
      scheduler: Deps.i.notificationScheduler,
      settings: Deps.i.notificationSettings,
      notifier: Deps.i.reflectionNotifier,
      reflectionSettings: Deps.i.reflectionSettings,
      availability: Deps.i.reflectionService.availability,
    );
    WidgetsBinding.instance.addObserver(this);
    _startTick();
  }

  /// Lands on the next whole minute first, so the line turns with the clock
  /// rather than up to a minute behind it.
  void _startTick() {
    _tick?.cancel();
    _tick = Timer(untilNextMinute(DateTime.now()), () {
      _turnMinute();
      _tick = Timer.periodic(const Duration(minutes: 1), (_) => _turnMinute());
    });
  }

  void _turnMinute() => setState(() => _now = DateTime.now());

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _cubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have flipped notification permission in iOS Settings while
    // this screen was backgrounded (via the deny row's deep-link).
    if (state == AppLifecycleState.resumed) {
      unawaited(_cubit.load());
      // Timers sleep in the background; the clock may have moved a day.
      _turnMinute();
      _startTick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: _NotificationsView(now: _now),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<NotificationsCubit>();
    final state = context.watch<NotificationsCubit>().state;

    // A nudge only means something for a period whose reflections generate,
    // so the tiles track the enabled periods.
    final periods = state.shownPeriods;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: SettingsList(
        children: [
          AnimatedReveal(
            visible: periods.isNotEmpty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsCard(
                  children: [
                    SettingsToggleRow(
                      icon: AppIcons.bell,
                      label: l10n.notifyReflectionReminders,
                      note: _nextLine(context, state, now),
                      value: state.master,
                      onChanged: state.reflectionsAvailable
                          ? (on) => unawaited(cubit.setMaster(on))
                          : null,
                    ),
                  ],
                ),
                AnimatedReveal(
                  visible: state.reflectionsAvailable && state.master && !state.permissionBlocked,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A lone period has nothing to pick: the master alone
                      // governs it (the notifier counts it selected).
                      AnimatedReveal(
                        visible: periods.length > 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [SectionLabel(l10n.notifyPeriodsLabel), const _PeriodTiles()],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SettingsCard(
                        children: [
                          TimeField(
                            label: l10n.notifyTime,
                            hour: state.hour,
                            minute: state.minute,
                            onChanged: (hour, minute) =>
                                unawaited(cubit.setTime(hour: hour, minute: minute)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AnimatedReveal(
            visible: state.reflectionsAvailable && state.permissionBlocked,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: SettingsCard(
                children: [
                  SettingsActionRow(
                    icon: AppIcons.bell,
                    label: l10n.notifyPermissionDenied,
                    trailing: l10n.notifyOpenSettings,
                    tint: theme.danger,
                    onTap: () => unawaited(openAppSettings()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Footnote(
            face: remindersFootnoteOf(state),
            onTurnOn: () => unawaited(_openReflections(context, cubit)),
          ),
        ],
      ),
    );
  }

  /// When the next nudge lands, said as a day and a time; null while nothing
  /// will fire (off, unavailable, or iOS not letting the app notify).
  static String? _nextLine(BuildContext context, NotificationsState state, DateTime now) {
    final locale = localeTag(context);
    final at = nextNudge(
      now: now,
      hour: state.hour,
      minute: state.minute,
      periods: state.nudgingPeriods,
      weekStart: weekStartWeekday(localeId: locale),
    );
    if (at == null) return null;
    final l10n = AppLocalizations.of(context)!;
    // The chosen time, not [at]'s: a time a clock change skips still reads as
    // the one the row below shows.
    final time = DateFormat.Hm(locale).format(DateTime(2000, 1, 1, state.hour, state.minute));
    return switch (nudgeDayOf(now, at)) {
      NudgeDay.today => l10n.notifyNextToday(time),
      NudgeDay.tomorrow => l10n.notifyNextTomorrow(time),
      NudgeDay.later => l10n.notifyNextOn(DateFormat.MMMEd(locale).format(at), time),
    };
  }

  /// Opens the reflections surface (where periods are switched on) and re-reads
  /// state on return, so enabling one there lights this screen up without a
  /// relaunch. A same-app push is not an app resume, so the lifecycle observer
  /// would not catch it.
  Future<void> _openReflections(BuildContext context, NotificationsCubit cubit) async {
    await context.pushNamed(Routes.reflectionsName);
    if (context.mounted) unawaited(cubit.load());
  }
}

/// How long from [now] until the next whole minute, never zero: a tick that
/// lands exactly on one waits for the next.
Duration untilNextMinute(DateTime now) =>
    const Duration(minutes: 1) -
    Duration(seconds: now.second, milliseconds: now.millisecond, microseconds: now.microsecond);

/// Which footnote closes the screen.
enum RemindersFootnote { unavailable, needsReflections, info }

/// Availability first: an unsupported device can't run reflections, so it is
/// never offered the turn-on link, even when every period reads off.
RemindersFootnote remindersFootnoteOf(NotificationsState state) {
  if (!state.reflectionsAvailable) return RemindersFootnote.unavailable;
  if (state.shownPeriods.isEmpty) return RemindersFootnote.needsReflections;
  return RemindersFootnote.info;
}

/// The footnote, crossfading to a new one while its height eases on the
/// switch's clock, so a probe that changes it never pops the screen's end.
class _Footnote extends StatelessWidget {
  const _Footnote({required this.face, required this.onTurnOn});

  final RemindersFootnote face;
  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final Widget note = switch (face) {
      RemindersFootnote.unavailable => SectionInfo(l10n.notifyReflectionsUnavailable),
      RemindersFootnote.needsReflections => SectionInfoLink(
        text: l10n.notifyNeedsReflections,
        linkLabel: l10n.notifyTurnOnReflections,
        onTap: onTurnOn,
      ),
      RemindersFootnote.info => SectionInfo(l10n.notifyReflectionsInfo),
    };
    return MeltSwap(id: face, child: note);
  }
}

/// The period picker under the switch: one tile per enabled reflection
/// period, sharing the width evenly, multi-select. Each says which day its
/// nudge lands on. Deselecting the last one folds the options away: the cubit
/// turns the master off with it. Only built with two or more periods.
class _PeriodTiles extends StatelessWidget {
  const _PeriodTiles();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    final state = context.watch<NotificationsCubit>().state;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, period) in state.shownPeriods.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PeriodTile(
                // Keyed by period so a shift in the set (a period enabled
                // elsewhere) keeps each tile with its period.
                key: ValueKey(period),
                period: period,
                selected: state.slotOf(period).selected,
                onTap: () => unawaited(cubit.setSelected(period, !state.slotOf(period).selected)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One period: its calendar glyph, its name, and the day its nudge lands,
/// with a check in the corner. Selected is quiet, an ink outline and a filled
/// check, so the switch above stays the loudest control on the screen.
class _PeriodTile extends StatelessWidget {
  const _PeriodTile({required this.period, required this.selected, required this.onTap, super.key});

  final ReflectionPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;
    final target = selected ? 1.0 : 0.0;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: Touchable(
        onTap: onTap,
        haptic: true,
        pressedScale: theme.motion.pressIconScale,
        child: TweenAnimationBuilder<double>(
          // begin == end: a tile mounts wearing its state; only a real toggle
          // animates, retargeting from wherever it is.
          tween: Tween(begin: target, end: target),
          duration: context.reduceMotion ? Duration.zero : theme.motion.indicator,
          curve: theme.motion.indicatorCurve,
          builder: (context, t, _) {
            final ink = Color.lerp(theme.textSecondary, theme.text, t)!;
            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: SuperellipseDecoration(
                borderRadius: tokens.cardRadius,
                color: tokens.cardBackground,
                border: BorderSide(color: tokens.cardBorder),
              ),
              // Painted over the card, so the ring never grows the tile; inset
              // by the strokes' gap, so it runs parallel to the hairline.
              foregroundDecoration: SuperellipseDecoration(
                borderRadius: AppRadius.inner(
                  tokens.cardRadius,
                  (AppStroke.ring - AppStroke.hairline) / 2,
                ),
                border: BorderSide(
                  color: theme.text.withValues(alpha: t),
                  width: AppStroke.ring,
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(_icon, size: AppIconSize.body, color: ink),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _name(l10n),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.subhead.copyWith(color: ink, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: tokens.noteGap),
                      Text(
                        _day(context, l10n),
                        style: AppType.rowNote.copyWith(color: theme.textSecondary),
                      ),
                    ],
                  ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: Container(
                      width: AppSizes.badge,
                      height: AppSizes.badge,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.accent.withValues(alpha: t),
                        border: Border.all(
                          color: Color.lerp(tokens.cardBorder, theme.accent, t)!,
                          width: AppStroke.ring,
                        ),
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: t,
                          child: AppIcon(
                            AppIcons.checkmark,
                            size: AppIconSize.badge,
                            color: theme.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData get _icon => switch (period) {
    ReflectionPeriod.daily => AppIcons.oneCalendar,
    ReflectionPeriod.weekly => AppIcons.sevenCalendar,
    ReflectionPeriod.monthly => AppIcons.calendar,
  };

  String _name(AppLocalizations l10n) => switch (period) {
    ReflectionPeriod.daily => l10n.notifyPeriodDay,
    ReflectionPeriod.weekly => l10n.notifyPeriodWeek,
    ReflectionPeriod.monthly => l10n.notifyPeriodMonth,
  };

  String _day(BuildContext context, AppLocalizations l10n) {
    final locale = localeTag(context);
    // 1 January 2024 was a Monday: offset to the locale's first weekday.
    final weekStart = addDays(DateTime(2024), weekStartWeekday(localeId: locale) - 1);
    return switch (period) {
      ReflectionPeriod.daily => l10n.notifyEveryDay,
      ReflectionPeriod.weekly => l10n.notifyEveryWeekday(DateFormat.EEEE(locale).format(weekStart)),
      ReflectionPeriod.monthly => l10n.notifyOnTheFirst,
    };
  }
}
