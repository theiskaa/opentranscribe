import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

/// The skeleton every onboarding page shares: the words, then the [scene]
/// under them, the block hung from one line a fixed way down the page, so the
/// title sits at the same height on every page whatever the scene below it
/// measures. A plain scroll view, no fill sliver: the scenes hold painters and
/// layout builders that cannot answer an intrinsic pass, and it scrolls only
/// when large type makes the block taller than the room.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({required this.scene, required this.title, required this.body, super.key});

  final Widget scene;
  final String title;
  final String body;

  /// How far down the room the title line sits, as a fraction of its height.
  static const _titleLine = 0.22;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          constraints.maxHeight * _titleLine,
          AppSpacing.xxl,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppType.display2.copyWith(color: theme.text)),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.4)),
            const SizedBox(height: AppSpacing.xxxl),
            scene,
          ],
        ),
      ),
    );
  }
}
