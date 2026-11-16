import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/view/widgets/duo_style.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';

/// A page whose title floats in an [AppTopBar] overlay while [child] runs
/// behind it: scrollables pad their top by [topPaddingOf] and wash out under
/// the bar's material instead of hitting a band. Screens pass their
/// `ScreenColors` token as [background]; the base background is a fallback.
/// The background, the bar's material and [child] span the window; the body
/// keeps its content in the safe band itself (`SafeSides.scroll`).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.title,
    this.background,
    this.actions = const [],
    this.onBack,
    super.key,
  });

  /// The bar's large title, or null for a bare bar (just the back control over
  /// the material) - a screen whose own content carries the heading.
  final String? title;
  final Widget child;
  final Color? background;
  final List<Widget> actions;
  final VoidCallback? onBack;

  /// Where a scrollable behind the bar should start at rest: past the COMPACT
  /// bar (these screens carry no title, so the tall title row was dead space)
  /// plus a breath. Content peeks under the frosted tail as it scrolls, which is
  /// the point; nothing under the bar is a platform view, so the blur composites
  /// it cleanly.
  static double topPaddingOf(BuildContext context) =>
      AppTopBar.heightOf(context) + (duoInnerOf(context) ? DuoTheme.pageTop : AppSpacing.lg);

  /// Where a control anchored to the screen's bottom rests: xl above the safe
  /// area, the same for every one of them (a floating disc, a dock, a capsule,
  /// the recorder's row).
  static double bottomControlOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ColoredBox(
      color: background ?? theme.background,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Compact bar: just the back chevron over the frost, no tall title
            // row. A title, if ever passed, rides the same compact row.
            child: AppTopBar(
              frosted: true,
              leading: onBack != null ? AppBackButton(onBack: onBack) : null,
              title: title == null
                  ? null
                  : Text(title!, style: AppType.headline.copyWith(color: theme.topBar.titleColor)),
              actions: actions,
            ),
          ),
        ],
      ),
    );
  }
}
