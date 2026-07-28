import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/circle_tile.dart';

/// One onboarding row: the circle [tile], a [title] over its explaining
/// [line], and an optional [trailing] control, aligned the same on every step
/// so the three pages read as one surface.
class OnboardingRow extends StatelessWidget {
  const OnboardingRow({
    required this.tile,
    required this.title,
    this.line,
    this.trailing,
    super.key,
  });

  final Widget tile;
  final String title;
  final String? line;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: [
        CircleTile(child: tile),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.subhead.copyWith(color: theme.text)),
              if (line != null) ...[
                const SizedBox(height: 2),
                Text(line!, style: AppType.footnote.copyWith(color: theme.textSecondary)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.md), trailing!],
      ],
    );
  }
}
