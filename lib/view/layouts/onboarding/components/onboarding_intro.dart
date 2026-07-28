import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_tile.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/github_mark.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:opentranscribe/view/widgets/wave_glyph.dart';

/// Intro step: the brand lockup stacked over the promise, three rows of what
/// the app does, and the open-source row. The source row is the one
/// outward-pointing tap in onboarding (opens the repo in the system browser);
/// it carries no user data.
class OnboardingIntro extends StatelessWidget {
  const OnboardingIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    // Center when it fits, scroll when large type makes it tall.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WaveGlyph(color: theme.text),
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.appTitle, style: AppType.display.copyWith(color: theme.text, height: 1)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.onboardingIntroBody,
              style: AppType.subhead.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            OnboardingRow(
              tile: AppIcon(AppIcons.micFill, size: 20, color: theme.text),
              title: l10n.onboardingSpeakTitle,
              line: l10n.onboardingSpeakLine,
            ),
            const SizedBox(height: AppSpacing.lg),
            OnboardingRow(
              tile: AppIcon(AppIcons.textformat, size: 20, color: theme.text),
              title: l10n.onboardingWriteTitle,
              line: l10n.onboardingWriteLine,
            ),
            const SizedBox(height: AppSpacing.lg),
            OnboardingRow(
              tile: AppIcon(AppIcons.houseFill, size: 20, color: theme.text),
              title: l10n.onboardingPrivateTitle,
              line: l10n.onboardingPrivateLine,
            ),
            const SizedBox(height: AppSpacing.xl),
            Touchable(
              onTap: () => unawaited(openLink(kRepoUrl)),
              child: OnboardingRow(
                tile: GithubMark(color: theme.text, size: 20),
                title: l10n.onboardingSource,
                line: l10n.onboardingSourceLine,
                trailing: AppIcon(AppIcons.arrowUpRight, size: 16, color: theme.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
