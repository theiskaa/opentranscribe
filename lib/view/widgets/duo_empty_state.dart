import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/safe_sides.dart';

class DuoEmptyState extends StatelessWidget {
  const DuoEmptyState({required this.title, required this.body, required this.icon, super.key});

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final panes = PaneLayoutScope.maybeOf(context);
    return SafeSides.scroll(
      builder: (context, sides) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: duoDetailInsets(
              width: MediaQuery.sizeOf(context).width + sides.horizontal,
              safe: MediaQuery.paddingOf(context) + sides,
              fold: panes == null
                  ? EdgeInsets.zero
                  : duoFoldInsets(panes.layout, PaneScope.maybeOf(context)?.touch),
              top: AppScaffold.topPaddingOf(context) - MediaQuery.paddingOf(context).top,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
            ),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: DuoTheme.emptyAlignment,
                child: DuoEmptyContent(title: title, body: body, icon: icon),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DuoEmptyContent extends StatelessWidget {
  const DuoEmptyContent({required this.title, required this.body, required this.icon, super.key});

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: DuoTheme.emptyMeasure),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: DuoTheme.emptyGlyph, color: theme.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: DuoTheme.emptyTitle.copyWith(color: theme.text),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: DuoTheme.sheetSubtitle.copyWith(color: theme.textSecondary),
          ),
        ],
      ),
    );
  }
}
