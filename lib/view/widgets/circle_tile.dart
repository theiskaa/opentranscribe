import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';

/// The 44x44 secondary-surface circle that leads a row: onboarding's steps and
/// every sheet message share it, so raised surfaces read as the same app.
class CircleTile extends StatelessWidget {
  const CircleTile({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      width: AppSizes.barControl,
      height: AppSizes.barControl,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.button.secondaryBackground,
        shape: BoxShape.circle,
        border: Border.all(color: theme.button.secondaryBorder),
      ),
      child: child,
    );
  }
}
