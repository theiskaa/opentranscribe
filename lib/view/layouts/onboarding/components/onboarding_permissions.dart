import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/state/onboarding_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_tile.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Permissions step: request microphone and speech recognition, both on-device.
/// Never blocks the flow - each row just reflects its status, and a denied one
/// offers a jump to Settings.
class OnboardingPermissions extends StatelessWidget {
  const OnboardingPermissions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        // Center when it fits, scroll when large type makes it tall.
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.onboardingPermissionsTitle,
                  style: AppType.display2.copyWith(color: theme.text),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.onboardingPermissionsBody,
                  style: AppType.subhead.copyWith(color: theme.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _PermissionRow(
                  icon: AppIcons.micFill,
                  name: l10n.onboardingMicName,
                  reason: l10n.onboardingMicReason,
                  granted: state.micGranted,
                  requesting: state.requestingMic,
                  // Restricted (parental controls) is not "yet to ask": there is
                  // nothing to grant here, so it reads like a denial - Settings.
                  denied:
                      state.mic == PermissionStatus.denied ||
                      state.mic == PermissionStatus.restricted,
                  onAllow: () => unawaited(cubit.requestMic()),
                ),
                const SizedBox(height: AppSpacing.lg),
                _PermissionRow(
                  icon: AppIcons.waveform,
                  name: l10n.onboardingSpeechName,
                  reason: l10n.onboardingSpeechReason,
                  granted: state.speechGranted,
                  requesting: state.requestingSpeech,
                  denied: state.speech == SpeechPermission.denied,
                  onAllow: () => unawaited(cubit.requestSpeech()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.name,
    required this.reason,
    required this.granted,
    required this.requesting,
    required this.denied,
    required this.onAllow,
  });

  final IconData icon;
  final String name;
  final String reason;
  final bool granted;
  final bool requesting;
  final bool denied;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return OnboardingRow(
      tile: AppIcon(icon, size: 20, color: theme.text),
      title: name,
      line: reason,
      trailing: _trailing(context),
    );
  }

  Widget _trailing(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    if (granted) return AppIcon(AppIcons.checkmark, size: 18, color: theme.accent);
    // theme.text, not textSecondary: the spinner picks its dot color by the
    // tint's luminance, and dark mode's mid-gray secondary picks black dots.
    if (requesting) return AppSpinner(color: theme.text);
    if (denied) {
      // The prompt only ever shows once; a denied permission can be granted only
      // from the system Settings, so send them there.
      return Touchable(
        onTap: () => unawaited(openAppSettings()),
        child: Text(
          l10n.onboardingOpenSettings,
          style: AppType.footnote.copyWith(color: theme.accent),
        ),
      );
    }
    return AppButton(
      label: l10n.onboardingAllow,
      variant: AppButtonVariant.secondary,
      expand: false,
      height: 40,
      onPressed: onAllow,
    );
  }
}
