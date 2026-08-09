import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// The root handed to `runApp` when startup itself threw, in place of `App`.
///
/// It must stand entirely on its own: no cubits, no router, no storage, no
/// theme selection, because the thing that builds those is what failed. Without
/// it nothing calls `runApp`, no frame is ever committed, and iOS holds the
/// launch screen until the watchdog kills the process, which reads as a hang
/// with no explanation.
///
/// Colours come from the static default palette against the platform
/// brightness: the stored theme lives behind the storage that may be the very
/// thing that failed.
class LaunchFailureApp extends StatelessWidget {
  const LaunchFailureApp(this.error, {super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final dark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final theme = dark ? AppTheme.defaultDark : AppTheme.defaultLight;
    return WidgetsApp(
      color: theme.accent,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return ColoredBox(
          color: theme.background,
          child: SafeArea(
            child: Center(
              // Scrollable: at the largest accessibility text sizes this copy is
              // taller than a small screen, and a clipped explanation is the one
              // thing this screen cannot afford to lose.
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                  vertical: AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.launchFailedTitle,
                      textAlign: TextAlign.center,
                      style: AppType.title.copyWith(color: theme.text),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.launchFailedBody,
                      textAlign: TextAlign.center,
                      style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5),
                    ),
                    // Not in release: a raw Dart error is the fastest thing to
                    // read off a profile build, and the last thing a shipped
                    // user should be shown.
                    if (!kReleaseMode) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        '$error',
                        textAlign: TextAlign.center,
                        style: AppType.footnote.copyWith(color: theme.danger),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
