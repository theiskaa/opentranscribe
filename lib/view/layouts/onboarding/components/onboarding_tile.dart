import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// The 44x44 secondary-surface circle that leads every onboarding row.
class OnboardingTile extends StatelessWidget {
  const OnboardingTile({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      width: 44,
      height: 44,
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
