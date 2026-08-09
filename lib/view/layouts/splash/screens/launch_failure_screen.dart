import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// What runs when [Deps.init] threw, so the app has no dependencies at all.
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.launchFailedTitle,
                  textAlign: TextAlign.center,
                  style: AppType.title.copyWith(color: theme.text),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.launchFailedBody,
                  textAlign: TextAlign.center,
                  style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: AppType.footnote.copyWith(color: theme.danger),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
