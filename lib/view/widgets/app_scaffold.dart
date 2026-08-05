import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';

/// A page whose title floats in an [AppTopBar] overlay while [child] runs
/// behind it: scrollables pad their top by [topPaddingOf] and wash out under
/// the bar's material instead of hitting a band. Screens pass their
/// `ScreenColors` token as [background]; the base background is a fallback.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.title,
    this.titleWidget,
    this.background,
    this.actions = const [],
    this.onBack,
    super.key,
  }) : assert(
         title == null || titleWidget == null,
         'Pass a text title OR a title widget, not both',
       );

  /// The bar's large title, or null for a bare bar (just the back control over
  /// the material) - a screen whose own content carries the heading.
  final String? title;

  /// A widget centered in the bar between the back control and the actions.
  /// Takes the place of a text [title].
  final Widget? titleWidget;
  final Widget child;
  final Color? background;
  final List<Widget> actions;
  final VoidCallback? onBack;

  /// Where a scrollable behind the bar should start at rest: past the COMPACT
  /// bar (these screens carry no title, so the tall title row was dead space)
  /// plus a breath. Content peeks under the frosted tail as it scrolls, which is
  /// the point; nothing under the bar is a platform view, so the blur composites
  /// it cleanly.
  static double topPaddingOf(BuildContext context) => AppTopBar.heightOf(context) + AppSpacing.lg;

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
              title:
                  titleWidget ??
                  (title == null
                      ? null
                      : Text(
                          title!,
                          style: AppType.headline.copyWith(color: theme.topBar.titleColor),
                        )),
              centerTitle: titleWidget != null,
              actions: actions,
            ),
          ),
        ],
      ),
    );
  }
}
