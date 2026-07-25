import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// The home empty state: not a card in the middle of the screen but a title and
/// a line of writing at the top-left, like the first page of the journal. It
/// rides inside a scrollable so the pull-to-record gesture is available here too.
class HomeEmpty extends StatelessWidget {
  const HomeEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      // Lands on the records' text column and leaves a comfortable reading
      // measure on the right, so the subtitle never runs the full width.
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxxl, AppSpacing.xxxl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homeEmptyHeadline, style: AppType.display.copyWith(color: theme.text)),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.homeEmptySubtitle, style: AppType.body.copyWith(color: theme.textSecondary)),
        ],
      ),
    );
  }
}
