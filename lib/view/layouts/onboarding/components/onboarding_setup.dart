import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/onboarding_cubit.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_page.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_row.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_steps.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/model_failure_line.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:reflections/reflections.dart';
import 'package:transcriber/transcriber.dart';

/// The last page: set up. Two settings cards of live rows: what the app runs
/// with (the default language, a download where the engine manages models
/// and built in otherwise; reflections, where the hardware has Apple
/// Intelligence) and what it asks for (the microphone, speech recognition).
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          children: [
            const _LanguageRow(),
            if (reflectionsEligible(reflections)) _ReflectionsRow(status: reflections),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const SettingsCard(children: [_MicRow(), _SpeechRow()]),
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

/// What the language row shows: the default's live row once a load has landed
/// one; a wait until the first load lands; and, once a load has failed with no
/// row to draw from, the default's name alone, since the wait would never end.
enum LanguageRowFace { live, loading, nameOnly }

LanguageRowFace languageRowFace({required bool hasRow, required bool loadFailed}) {
  if (hasRow) return LanguageRowFace.live;
  return loadFailed ? LanguageRowFace.nameOnly : LanguageRowFace.loading;
}

/// The default language as the Transcription screen knows it, see
/// [languageRowFace] for what it shows before the rows have loaded.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final row = state.defaultLanguage;
        return switch (languageRowFace(hasRow: row != null, loadFailed: state.loadFailed)) {
          LanguageRowFace.nameOnly => OnboardingRow(
            leading: LocaleFlag(localeFlag(state.localeId), size: 18),
            name: localeDisplayName(state.localeId),
            trailing: const SizedBox.shrink(),
          ),
          LanguageRowFace.loading => OnboardingRow(
            leading: AppSpinner(size: 16, color: theme.text),
            name: l10n.onboardingLanguageLoading,
            trailing: const SizedBox.shrink(),
          ),
          LanguageRowFace.live => _LiveLanguageRow(row: row!, managed: state.managesModels),
        };
      },
    );
  }
}

/// The loaded default. Where the engine downloads models the seat offers the
/// download and shows its progress; where the language is built in the seat is
/// a checkmark or nothing, and the note names what stands in the way.
class _LiveLanguageRow extends StatelessWidget {
  const _LiveLanguageRow({required this.row, required this.managed});

  final LanguageModelState row;
  final bool managed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trouble = modelTroubleLine(l10n, row, managesModels: managed);
    final note =
        trouble ??
        (row.isReady
            ? l10n.onboardingLanguageReady
            : (managed ? l10n.onboardingLanguageDownloads : l10n.onboardingLanguageBuiltIn));
    return OnboardingRow(
      leading: LocaleFlag(localeFlag(row.tag), size: 18),
      name: localeDisplayName(row.tag),
      note: note,
      trailing: _LanguageSeat(row: row, managed: managed),
    );
  }
}

class _LanguageSeat extends StatelessWidget {
  const _LanguageSeat({required this.row, required this.managed});

  final LanguageModelState row;
  final bool managed;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    if (row.isReady) return AppIcon(AppIcons.checkmark, size: 18, color: theme.accent);
    if (row.installing) {
      final fraction = row.installFraction!;
      // Before the first real fraction there is no honest progress to draw.
      return fraction <= 0
          ? AppSpinner(size: 22, color: theme.text)
          : ProgressRing(fraction: fraction);
    }
    // Nothing to offer: an engine with no downloads, or a language no model
    // exists for, whose install could only fail (the note already says why).
    if (!managed || row.status == ModelAssetStatus.unsupported) return const SizedBox.shrink();
    return Touchable(
      onTap: () => context.read<SettingsCubit>().install(row.tag),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: AppIcon(AppIcons.icloud, size: 22, color: theme.accent),
      ),
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
