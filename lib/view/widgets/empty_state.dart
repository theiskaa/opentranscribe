import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/entrance_rise.dart';

/// A quiet empty state: one card, a title, one line of explanation. The card
/// usually holds a still [icon]; pass [visual] instead for something live (the
/// home invitation's travelling wave), where a static glyph would undersell it.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, this.icon, this.visual, this.message, super.key})
    : assert(icon != null || visual != null, 'an empty state needs an icon or a visual');

  final IconData? icon;

  /// Replaces [icon] inside the card. When set, [icon] is ignored.
  final Widget? visual;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return EntranceRise(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: SuperellipseDecoration(
              borderRadius: AppRadius.panel,
              color: theme.surface,
              border: BorderSide(color: theme.surfaceBorder),
            ),
            child: Center(child: visual ?? AppIcon(icon!, size: 42, color: theme.textSecondary)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppType.title.copyWith(color: theme.text)),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
