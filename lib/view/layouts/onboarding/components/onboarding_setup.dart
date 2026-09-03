import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/state/onboarding_cubit.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_page.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_row.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_steps.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:reflections/reflections.dart';
import 'package:transcriber/transcriber.dart';

/// The last page: set up. One settings card of live rows: reflections, where
/// the hardware has Apple Intelligence, then what the app asks for (the
/// microphone, speech recognition, and reminders where reflections can run).
/// The rows carry no prompt of their own - the screen's button fires the
/// system prompts on the way into the app, so this page is the priming App
/// Store 5.1.1(iv) asks for, and a denied row offers Settings. Never a wall.
class OnboardingSetup extends StatelessWidget {
  const OnboardingSetup({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OnboardingPage(
      scene: const _SetupCard(),
      title: l10n.onboardingPermissionsTitle,
      body: l10n.onboardingPermissionsBody,
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    final reflections = context.watch<ReflectionsCubit>().state.availability.status;
    final canReflect = reflectionsEligible(reflections);
    return SettingsCard(
      children: [
        if (canReflect) _ReflectionsRow(status: reflections),
        const _MicRow(),
        const _SpeechRow(),
        if (canReflect) const _RemindersRow(),
      ],
    );
  }
}

class _MicRow extends StatelessWidget {
  const _MicRow();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) => OnboardingRow(
        leading: AppIcon(AppIcons.micFill, size: 16, color: theme.textSecondary),
        name: l10n.onboardingMicName,
        note: l10n.onboardingMicReason,
        trailing: _PermissionSeat(
          granted: state.micGranted,
          requesting: state.requestingMic,
          // Restricted (parental controls) is not "yet to ask": there is
          // nothing to grant here, so it reads like a denial, Settings.
          denied: state.mic == PermissionStatus.denied || state.mic == PermissionStatus.restricted,
        ),
      ),
    );
  }
}

class _SpeechRow extends StatelessWidget {
  const _SpeechRow();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) => OnboardingRow(
        leading: AppIcon(AppIcons.waveform, size: 16, color: theme.textSecondary),
        name: l10n.onboardingSpeechName,
        note: l10n.onboardingSpeechReason,
        trailing: _PermissionSeat(
          granted: state.speechGranted,
          requesting: state.requestingSpeech,
          denied: state.speech == SpeechPermission.denied,
        ),
      ),
    );
  }
}

/// Notification permission for the reflection reminders, asked with the other
/// two so a yes here switches the reminders on without a trip to their screen.
class _RemindersRow extends StatelessWidget {
  const _RemindersRow();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) => OnboardingRow(
        leading: AppIcon(AppIcons.bell, size: 16, color: theme.textSecondary),
        name: l10n.onboardingRemindersName,
        note: l10n.onboardingRemindersReason,
        trailing: _PermissionSeat(
          granted: state.remindersGranted,
          requesting: state.requestingReminders,
          denied: state.reminders == NotificationPermission.denied,
        ),
      ),
    );
  }
}

/// Reflections as this phone can run them: on, still preparing, or waiting for
/// Apple Intelligence to be switched on. Instructions only (iOS has no link to
/// that pane) and never a gate; hardware that can never run them has no row.
class _ReflectionsRow extends StatelessWidget {
  const _ReflectionsRow({required this.status});

  final ReflectionAvailabilityStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final on = status == ReflectionAvailabilityStatus.available;
    return OnboardingRow(
      leading: AppIcon(AppIcons.sevenCalendar, size: 16, color: theme.textSecondary),
      name: l10n.reflectionsTitle,
      note: switch (status) {
        ReflectionAvailabilityStatus.available => l10n.onboardingReflectionsOn,
        ReflectionAvailabilityStatus.modelNotReady => l10n.onboardingReflectionsPreparing,
        _ => l10n.onboardingReflectionsOff,
      },
      trailing: on
          ? AppIcon(AppIcons.checkmark, size: 18, color: theme.accent)
          : const SizedBox.shrink(),
    );
  }
}

class _PermissionSeat extends StatelessWidget {
  const _PermissionSeat({required this.granted, required this.requesting, required this.denied});

  final bool granted;
  final bool requesting;
  final bool denied;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    if (granted) return AppIcon(AppIcons.checkmark, size: 18, color: theme.accent);
    // theme.text, not textSecondary: the spinner picks its dot color by the
    // tint's luminance, and dark mode's mid-gray secondary picks black dots.
    if (requesting) return AppSpinner(size: 22, color: theme.text);
    if (denied) {
      // The prompt only ever shows once; a denied permission can be granted
      // only from the system Settings, so send them there.
      return Touchable(
        onTap: () => unawaited(openAppSettings()),
        child: Text(
          l10n.onboardingOpenSettings,
          style: AppType.footnote.copyWith(color: theme.accent, fontWeight: FontWeight.w600),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
