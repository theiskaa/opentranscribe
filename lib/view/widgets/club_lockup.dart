import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/wave_glyph.dart';

/// The club's identity lockup: the app's wave beside its name over the CLUB
/// eyebrow. One widget for every surface that fronts the club (the support
/// screen's header, the gate sheet), so the brand is drawn once and cannot
/// drift. The wave is [WaveGlyph], the same mark the empty home draws, never
/// a bitmap.
class ClubLockup extends StatelessWidget {
  const ClubLockup({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tag = AppLocalizations.of(context)!.supporterTag;
    return Row(
      children: [
        WaveGlyph(color: theme.text),
        const SizedBox(width: AppSpacing.md),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OpenTranscribe', style: AppType.title.copyWith(color: theme.text)),
            const SizedBox(height: AppSpacing.xs),
            Text(tag.toUpperCase(), style: AppType.eyebrow.copyWith(color: theme.accent)),
          ],
        ),
      ],
    );
  }
}
