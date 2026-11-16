import 'package:flutter/widgets.dart';
import 'package:opentranscribe/view/widgets/duo_style.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/core/utils/platform_caps.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';

/// The bar icon button, the reeed way: the NATIVE Liquid Glass circle (UIKit's
/// glass button) on iOS 26, and the app's own circular icon button everywhere
/// else, so a bar control is always a control and never a bare glyph.
class AppGlassIconButton extends StatelessWidget {
  const AppGlassIconButton({
    required this.icon,
    required this.onTap,
    this.size = AppSizes.barControl,
    this.iconSize = AppIconSize.bar,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? color;

  /// What VoiceOver calls the button, on both faces.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    final glyphSize = duoInnerOf(context) ? AppDuo.barGlyph : iconSize;
    if (PlatformCaps.nativeGlass) {
      // The native side draws the glyph itself, from the SF Symbol NAME - our
      // vendored icon font never reaches it. isDark keeps the glass in step
      // with the chosen theme family, not just the system appearance.
      return LiquidIconButton(
        icon: AppIcons.sfSymbolName(icon),
        iconPointSize: glyphSize,
        tintColor: color,
        semanticLabel: semanticLabel,
        isDark: context.theme.brightness == Brightness.dark,
        // UIButton gives no haptic of its own; the drawn button buzzes, so
        // the glass one must too.
        onPressed: onTap == null
            ? null
            : () {
                Haptics.light();
                onTap();
              },
        enabled: onTap != null,
        size: size,
      );
    }
    if (duoInnerOf(context)) {
      final theme = context.theme;
      return Semantics(
        button: true,
        enabled: onTap != null,
        label: semanticLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: Touchable(
          onTap: onTap,
          haptic: true,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: theme.duo.controlSurface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.duo.separator, width: AppDuo.separatorWidth),
            ),
            child: Center(
              child: AppIcon(icon, size: AppDuo.barGlyph, color: color ?? theme.text),
            ),
          ),
        ),
      );
    }
    return AppIconButton(
      icon: icon,
      onTap: onTap,
      size: size,
      iconSize: iconSize,
      foreground: color,
      semanticLabel: semanticLabel,
    );
  }
}
