import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/circle_tile.dart';

/// One layout for every message a sheet raises: the circle tile and title on
/// one left-aligned row (the same row language as onboarding and the settings
/// lists, not a centered hero), the body under them, optional [rows], and an
/// optional [action] pinned last.
class SheetMessage extends StatelessWidget {
  const SheetMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.rows = const [],
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Extra rows between the body and the action (the cap sheet's evict list).
  final List<Widget> rows;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleTile(child: AppIcon(icon, size: 20, color: theme.textSecondary)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(title, style: AppType.headline.copyWith(color: theme.text)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(body, style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5)),
        if (rows.isNotEmpty) ...[const SizedBox(height: AppSpacing.xl), ...rows],
        if (action != null) ...[const SizedBox(height: AppSpacing.xxl), action!],
      ],
    );
  }
}
