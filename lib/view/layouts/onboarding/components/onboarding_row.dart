import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

/// A settings row without a tap of its own, for a [SettingsCard] on an
/// onboarding page: the tile, the name over its note, and a seat on the
/// trailing edge for the row's live answer. Padded and tiled like the kit's
/// own rows, so the card reads as the one the app will show.
class OnboardingRow extends StatelessWidget {
  const OnboardingRow({
    required this.leading,
    required this.name,
    required this.trailing,
    this.note,
    super.key,
  });

  final Widget leading;
  final String name;
  final String? note;
  final Widget trailing;

  /// The seat's floor: a spinner, a checkmark, or nothing must all take the
  /// same room, or the note reflows as the answer lands.
  static const double _seatMinWidth = 28;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    return Padding(
      padding: tokens.rowPadding,
      child: Row(
        children: [
          Container(
            width: tokens.iconTileSize,
            height: tokens.iconTileSize,
            alignment: Alignment.center,
            decoration: SuperellipseDecoration(
              borderRadius: tokens.iconTileRadius,
              color: tokens.iconTileBackground,
            ),
            child: leading,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppType.subhead.copyWith(color: theme.text)),
                if (note != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  // One line, so the card never changes shape as seats change.
                  Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.footnote.copyWith(color: theme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _seatMinWidth),
            child: Center(child: trailing),
          ),
        ],
      ),
    );
  }
}
