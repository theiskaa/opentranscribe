import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/github_mark.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:opentranscribe/view/widgets/wave_glyph.dart';

/// Intro step: the brand mark, what the app is, the offline promise, and a link
/// to the source. The one outward-pointing tap in onboarding (opens the repo in
/// the system browser); it carries no user data.
class OnboardingIntro extends StatelessWidget {
  const OnboardingIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wave + wordmark, the same lockup as the readme banner.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WaveGlyph(size: 34, color: theme.text),
              const SizedBox(width: AppSpacing.xl),
              Text(l10n.appTitle, style: AppType.display2.copyWith(color: theme.text, height: 1)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            l10n.onboardingIntroBody,
            style: AppType.footnote.copyWith(color: theme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.settingsOffline, style: AppType.footnote.copyWith(color: theme.textSecondary)),
          const SizedBox(height: AppSpacing.xxxl),
          Touchable(
            onTap: () => unawaited(openLink(kRepoUrl)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GithubMark(color: theme.accent, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.onboardingSource,
                  style: AppType.footnote.copyWith(color: theme.accent, height: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
