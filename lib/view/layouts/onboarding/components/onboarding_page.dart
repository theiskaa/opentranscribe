import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_arrangement.dart';

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
  static const _titleLine = AppDuo.onboardingTitleFraction;

  /// The page's side inset, which the button under every page shares.
  static const gutter = AppSpacing.xxl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = OnboardingColumns.of(context);
        final wide = layout?.mode == PaneMode.split;
        final top = constraints.maxHeight * _titleLine;
        return SingleChildScrollView(
          physics: wide ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.fromLTRB(gutter, top, gutter, AppSpacing.xl),
          child: OnboardingContent(
            layout: layout,
            viewportHeight: (constraints.maxHeight - top - AppSpacing.xl).clamp(0, double.infinity),
            words: SingleChildScrollView(
              primary: false,
              physics: wide ? null : const NeverScrollableScrollPhysics(),
              child: _Words(title: title, body: body),
            ),
            scene: SingleChildScrollView(
              primary: false,
              physics: wide ? null : const NeverScrollableScrollPhysics(),
              child: scene,
            ),
          ),
        );
      },
    );
  }
}

class _Words extends StatelessWidget {
  const _Words({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppType.display2.copyWith(color: theme.text)),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: AppType.subheadParagraph.copyWith(color: theme.textSecondary)),
      ],
    );
  }
}
