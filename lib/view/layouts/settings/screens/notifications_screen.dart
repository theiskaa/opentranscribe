import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/notifications_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/animated_reveal.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/time_field.dart';

/// Notifications: the local, on-device nudges. Today the whole surface is one
/// toggle, the weekly reflection nudge, plus its fire time; the scheduler and
/// the settings under it are generic, so a second notification type is another
/// row here, not new plumbing. Owns a [NotificationsCubit] and re-probes
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

    // A weekly nudge is only meaningful when reflections can produce one. When
    // they cannot, the toggle is inert and the footer explains why rather than
    // offering a switch that silently does nothing.
    final usable = state.nudgeUsable;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: SettingsList(
        children: [
          const SizedBox(height: 10),
          SettingsCard(
            children: [
              // One combined child so the card draws no divider of its own: the
              // time row carries its divider inside the reveal, and the two fold
              // away together when the toggle turns off.
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsToggleRow(
                    icon: AppIcons.bellFill,
                    label: l10n.notifyWeeklyReflection,
                    value: state.weeklyEnabled,
                    onChanged: usable ? (on) => unawaited(cubit.setWeeklyEnabled(on)) : null,
                  ),
                  AnimatedReveal(
                    visible: usable && state.weeklyEnabled && !state.permissionBlocked,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
          if (usable && state.permissionBlocked) ...[
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
          // never offer it the turn-on link even when the pref also reads off.
          if (!state.reflectionsAvailable)
            SectionInfo(l10n.notifyReflectionsUnavailable)
          else if (!state.reflectionsEnabled)
            SectionInfoLink(
              text: l10n.notifyNeedsReflections,
              linkLabel: l10n.notifyTurnOnReflections,
              onTap: () => unawaited(_openReflections(context, cubit)),
            )
          else
            SectionInfo(l10n.notifyWeeklyReflectionInfo),
        ],
      ),
    );
  }

  /// Opens the reflections surface (where reflections are switched on) and
  /// re-reads state on return, so enabling them there lights this screen up
  /// without a relaunch. A same-app push is not an app resume, so the lifecycle
  /// observer would not catch it.
  Future<void> _openReflections(BuildContext context, NotificationsCubit cubit) async {
    await context.pushNamed(Routes.reflectionsName);
    if (context.mounted) unawaited(cubit.load());
  }
}
