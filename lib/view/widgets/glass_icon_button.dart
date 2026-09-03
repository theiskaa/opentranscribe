import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
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
    this.size = 44,
    this.iconSize = 18,
    this.color,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (PlatformCaps.nativeGlass) {
      // The native side draws the glyph itself, from the SF Symbol NAME - our
      // vendored icon font never reaches it. isDark keeps the glass in step
      // with the chosen theme family, not just the system appearance.
    final onTap = this.onTap;
      return LiquidIconButton(
        icon: AppIcons.sfSymbolName(icon),
        iconPointSize: iconSize,
        tintColor: color,
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
    return AppIconButton(
      icon: icon,
      onTap: onTap,
      size: size,
      iconSize: iconSize,
      foreground: color,
    );
  }
}
