import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/notifications_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/animated_reveal.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/time_field.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:reflections/reflections.dart';

/// Notifications: the local, on-device nudges. One master switch turns
/// reflection reminders on in a single tap; the capsule row under it picks
/// WHICH periods nudge and the time row says when. The scheduler and the
/// settings under it are generic, so a new notification type is another row
/// here, not new plumbing. Owns a [NotificationsCubit] and re-probes
/// permission on resume, so a grant changed in iOS Settings lands without a
/// relaunch.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with WidgetsBindingObserver {
  late final NotificationsCubit _cubit;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have flipped notification permission in iOS Settings while
    // this screen was backgrounded (via the deny row's deep-link).
    if (state == AppLifecycleState.resumed) unawaited(_cubit.load());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(value: _cubit, child: const _NotificationsView());
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<NotificationsCubit>();
    final state = context.watch<NotificationsCubit>().state;

    // A nudge is only meaningful for a period whose reflections generate, so
    // the capsules track the enabled periods; with none, the footer link is
    // the whole surface. An unavailable model leaves the switch listed but
    // inert, with the footer explaining why.
    final periods = state.shownPeriods;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: SettingsList(
        children: [
          const SizedBox(height: 10),
          if (periods.isNotEmpty)
            SettingsCard(
              children: [
                // One combined child so the card draws no divider of its own:
                // the capsule and time rows carry their dividers inside the
                // reveal and fold away with it when the switch turns off.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsToggleRow(
                      icon: AppIcons.bell,
                      label: l10n.notifyReflectionReminders,
                      value: state.master,
                      onChanged: state.reflectionsAvailable
                          ? (on) => unawaited(cubit.setMaster(on))
                          : null,
                    ),
                    AnimatedReveal(
                      visible:
                          state.reflectionsAvailable && state.master && !state.permissionBlocked,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A lone period has nothing to pick: the master
                          // alone governs it (the notifier counts it selected)
                          // and the picker would be a row of one dead chip.
                          if (periods.length > 1) ...[
                            const SettingsDivider(),
                            const _PeriodChips(),
                          ],
                          const SettingsDivider(),
                          TimeField(
                            label: l10n.notifyTime,
                            hour: state.hour,
                            minute: state.minute,
                            onChanged: (hour, minute) =>
                                unawaited(cubit.setTime(hour: hour, minute: minute)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (state.reflectionsAvailable && state.permissionBlocked) ...[
            const SizedBox(height: AppSpacing.md),
            SettingsCard(
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
          ],
          const SizedBox(height: AppSpacing.md),
          // Availability first: an unsupported device can't run reflections, so
          // never offer it the turn-on link even when every period reads off.
          if (!state.reflectionsAvailable)
            SectionInfo(l10n.notifyReflectionsUnavailable)
          else if (periods.isEmpty)
            SectionInfoLink(
              text: l10n.notifyNeedsReflections,
              linkLabel: l10n.notifyTurnOnReflections,
              onTap: () => unawaited(_openReflections(context, cubit)),
            )
          else
            SectionInfo(l10n.notifyReflectionsInfo),
        ],
      ),
    );
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

/// The period picker under the master switch: one chip per enabled reflection
/// period, sharing the row's width evenly, multi-select. Deselecting the last
/// one folds the whole reveal away: the cubit turns the master off with it.
/// Only built with two or more periods; a lone one is the master's alone.
class _PeriodChips extends StatelessWidget {
  const _PeriodChips();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    final state = context.watch<NotificationsCubit>().state;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          for (final (i, period) in state.shownPeriods.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PeriodChip(
                // Keyed by period so a shift in the set (a period enabled
                // elsewhere) keeps each chip with its period.
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

/// One period chip, drawn in the app's own shapes: a superellipse tile (the
/// icon tiles' curvature, not a generic stadium tag) carrying the period's
/// calendar glyph and its name. Selected is the toggle-on language - a solid
/// accent fill with ink-on-accent content - so on and off read at a glance
/// with no checkmark clutter; fill and content lerp on one clock so nothing
/// changes color out of step, and the chip breathes a touch at mid-flip.
class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.period, required this.selected, required this.onTap, super.key});

  final ReflectionPeriod period;
  final bool selected;
  final VoidCallback onTap;

  static const double _height = 36;

  /// The mid-transition breath: how far the chip swells as a flip passes
  /// halfway, zero again by the time it settles.
  static const double _pulse = 0.03;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final target = selected ? 1.0 : 0.0;

    return Touchable(
      onTap: onTap,
      haptic: true,
      pressedScale: theme.motion.pressIconScale,
      child: TweenAnimationBuilder<double>(
        // begin == end: a chip mounts already wearing its state (the reveal
        // re-mounts the row on every master flip, and that must not replay
        // every seeded chip filling in); only a real toggle animates,
        // retargeting from wherever the value currently is.
        tween: Tween(begin: target, end: target),
        duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) {
          final fill = Color.lerp(tokens.iconTileBackground, theme.accent, t)!;
          final content = Color.lerp(theme.textSecondary, theme.onAccent, t)!;
          return Transform.scale(
            scale: 1 + _pulse * math.sin(math.pi * t),
            child: Container(
              height: _height,
              alignment: Alignment.center,
              decoration: SuperellipseDecoration(borderRadius: tokens.iconTileRadius, color: fill),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                // Baseline, not box-centre: the glyph is a Text like the label,
                // and SF glyphs are drawn to sit against type on a shared
                // baseline - centring their line boxes leaves the calendar
                // riding high of the label's optical middle.
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AppIcon(_icon, size: 12, color: content),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _label(AppLocalizations.of(context)!),
                    style: AppType.footnote.copyWith(color: content, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData get _icon => switch (period) {
    ReflectionPeriod.daily => AppIcons.oneCalendar,
    ReflectionPeriod.weekly => AppIcons.sevenCalendar,
    ReflectionPeriod.monthly => AppIcons.calendar,
  };

  String _label(AppLocalizations l10n) => switch (period) {
    ReflectionPeriod.daily => l10n.notifyPeriodDay,
    ReflectionPeriod.weekly => l10n.notifyPeriodWeek,
    ReflectionPeriod.monthly => l10n.notifyPeriodMonth,
  };
}
