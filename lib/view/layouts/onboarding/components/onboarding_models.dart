import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_row.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/model_failure_line.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:reflections/reflections.dart';

/// Model step: offer the default language for download so transcription works
/// offline right away. Optional - more languages live in the Models screen, and
/// the default installs itself on first use if skipped here. On eligible
/// hardware a reflections mention sits beneath; ineligible devices see nothing.
class OnboardingModels extends StatelessWidget {
  const OnboardingModels({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        // The suggested language to start with is the app default.
        LanguageModelState? row;
        for (final r in state.languages) {
          if (r.tag == state.localeId) {
            row = r;
            break;
          }
        }
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
                  l10n.onboardingModelsTitle,
                  style: AppType.display2.copyWith(color: theme.text),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.onboardingModelsBody,
                  style: AppType.subhead.copyWith(color: theme.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (row == null)
                  // theme.text, not textSecondary: the spinner picks its dot
                  // color by the tint's luminance, and dark mode's mid-gray
                  // secondary picks black dots.
                  AppSpinner(size: 22, color: theme.text)
                else ...[
                  _ModelRow(row: row),
                  // Only beside a real model row: under the bare loading
                  // spinner the mention would read as the step's content.
                  const _ReflectionsMention(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.row});

  final LanguageModelState row;

  @override
  Widget build(BuildContext context) {
    final failure = modelFailureLine(AppLocalizations.of(context)!, row);
    return OnboardingRow(
      tile: LocaleFlag(localeFlag(row.tag), size: 20),
      title: localeDisplayName(row.tag),
      line: failure,
      trailing: _ModelTrailing(row: row),
    );
  }
}

class _ModelTrailing extends StatelessWidget {
  const _ModelTrailing({required this.row});

  final LanguageModelState row;

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
    return Touchable(
      onTap: () => context.read<SettingsCubit>().install(row.tag),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: AppIcon(AppIcons.icloud, size: 22, color: theme.accent),
      ),
    );
  }
}

/// The reflections line under the model row, ELIGIBLE hardware only: what the
/// feature is when it can run, how to enable it when Apple Intelligence is
/// off, one line while the OS prepares the model. Instructions only (iOS has
/// no deep-link to the Apple Intelligence pane) and never a gate; ineligible
/// or unsupported devices render nothing at all.
class _ReflectionsMention extends StatelessWidget {
  const _ReflectionsMention();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final status = context.watch<ReflectionsCubit>().state.availability.status;

    final line = switch (status) {
      ReflectionAvailabilityStatus.available => l10n.onboardingReflectionsOn,
      ReflectionAvailabilityStatus.modelNotReady => l10n.onboardingReflectionsPreparing,
      ReflectionAvailabilityStatus.notEnabled => l10n.onboardingReflectionsOff,
      // deviceNotEligible, unsupported: invisible here, not an apology.
      _ => null,
    };
    if (line == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: OnboardingRow(
        tile: AppIcon(AppIcons.calendar, size: 20, color: theme.text),
        title: l10n.reflectionsTitle,
        line: line,
        trailing: status == ReflectionAvailabilityStatus.available
            ? AppIcon(AppIcons.checkmark, size: 18, color: theme.accent)
            : null,
      ),
    );
  }
}
