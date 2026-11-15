import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/platform_caps.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The floating action disc: home's record button and the entry screen's edit
/// exit wear the same one. On iOS 26 it is the native Liquid Glass circle so
/// it matches the rest of the app's glass chrome; everywhere else it is a
/// surface disc with the glyph in ink - the same restrained tone in every
/// theme (never the accent hue, never stark white). The tap's haptic and
/// navigation belong to [onTap], so this stays presentation-only.
class GlassFab extends StatelessWidget {
  const GlassFab({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.iconSize = AppIconSize.fab,
    super.key,
  });

  final IconData icon;

  /// What VoiceOver calls the disc, on both faces.
  final String semanticLabel;

  /// Null disables the disc; both faces render inert rather than vanish.
  final VoidCallback? onTap;
  final double iconSize;

  static const double size = AppSizes.fab;

  /// How far the disc floats in from the safe edge.
  static const double floatInset = AppSpacing.xl;

  /// The disc's `right` offset in a stack spanning the window: [floatInset]
  /// past the right safe inset, so a side status column never covers it.
  static double rightFor(EdgeInsets padding) => floatInset + padding.right;

  /// [rightFor] from [context]'s safe area.
  static double rightOf(BuildContext context) => rightFor(MediaQuery.paddingOf(context));

  /// Where content under a floating disc must end so its last line clears
  /// the disc: the disc's seat, the disc, and a breath above it.
  static double clearanceOf(BuildContext context) =>
      AppScaffold.bottomControlOf(context) + size + AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    if (PlatformCaps.nativeGlass) {
      // The native side draws the glyph from the SF Symbol NAME - the vendored
      // icon font never reaches it. isDark keeps the glass in step with the
      // chosen theme family, not just the system appearance.
      return LiquidIconButton(
        icon: AppIcons.sfSymbolName(icon),
        iconPointSize: iconSize,
        tintColor: theme.text,
        semanticLabel: semanticLabel,
        isDark: theme.brightness == Brightness.dark,
        onPressed: onTap,
        enabled: onTap != null,
        size: size,
      );
    }

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Touchable(
        onTap: onTap,
        pressedScale: theme.motion.pressScale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: theme.surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: theme.shadow.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: AppIcon(icon, size: iconSize, color: theme.text),
          ),
        ),
      ),
    );
  }
}
