import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/utils/platform_caps.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// One button in an [AppIconButtonGroup]. A null [onTap] renders disabled - the
/// slot is present but inert, for a control that exists before it does anything.
class AppIconButtonGroupItem {
  const AppIconButtonGroupItem({
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.causesNavigation = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Whether [onTap] pushes a route. iOS 26 hides the platform view across the
  /// transition when this is set, so the glass never ghosts over the incoming
  /// screen; the fallback ignores it (a Flutter widget composites cleanly).
  final bool causesNavigation;
}

/// Several bar icons on ONE surface: the native Liquid Glass capsule on iOS 26,
/// and the app's own capsule of the same size everywhere else. A sibling of
/// [AppGlassIconButton], gated the same way - only the material changes across
/// OS versions, never the geometry, so a bar reads identically wherever it runs.
class AppIconButtonGroup extends StatelessWidget {
  const AppIconButtonGroup({
    required this.items,
    this.height = 38,
    this.slotWidth = 42,
    this.iconSize = 15,
    this.color,
    super.key,
  });

  final List<AppIconButtonGroupItem> items;

  /// The capsule's height, and one button's width within it. Tighter than
  /// liquid's 44/52 default: a group of two full nav circles overpowers a bar
  /// whose title is the point. Shared with the native view so the capsule is
  /// the same size across the OS split.
  final double height;
  final double slotWidth;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (PlatformCaps.nativeGlass) {
      // The native side draws each glyph from its SF Symbol NAME; our vendored
      // font never reaches it. isDark keeps the glass in step with the chosen
      // theme family, not just the system appearance.
      return LiquidIconButtonGroup(
        height: height,
        slotWidth: slotWidth,
        iconPointSize: iconSize,
        isDark: context.theme.brightness == Brightness.dark,
        items: [
          for (final item in items)
            LiquidIconButtonGroupAction(
              icon: AppIcons.sfSymbolName(item.icon),
              onPressed: item.onTap,
              enabled: item.onTap != null,
              semanticLabel: item.semanticLabel,
              causesNavigation: item.causesNavigation,
            ),
        ],
      );
    }
    return _FallbackGroup(
      items: items,
      height: height,
      slotWidth: slotWidth,
      iconSize: iconSize,
      color: color,
    );
  }
}

/// The below-iOS-26 capsule: what the native view draws there, in the app's own
/// materials - a surface pill with a hairline, one slot per button, a hairline
/// between them.
class _FallbackGroup extends StatelessWidget {
  const _FallbackGroup({
    required this.items,
    required this.height,
    required this.slotWidth,
    required this.iconSize,
    required this.color,
  });

  final List<AppIconButtonGroupItem> items;
  final double height;
  final double slotWidth;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      // A true capsule, radius = half the height, matching the native pill.
      decoration: SuperellipseDecoration(
        borderRadius: height / 2,
        color: theme.surface,
        border: BorderSide(color: theme.surfaceBorder),
      ),
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, item) in items.indexed) ...[
              if (i > 0)
                // The native separator: a short hairline, not a full-height
                // rule, so it divides without boxing each slot.
                Container(width: 1, height: height * 0.45, color: theme.surfaceBorder),
              _FallbackSlot(
                item: item,
                width: slotWidth,
                iconSize: iconSize,
                color: color ?? theme.text,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FallbackSlot extends StatelessWidget {
  const _FallbackSlot({
    required this.item,
    required this.width,
    required this.iconSize,
    required this.color,
  });

  final AppIconButtonGroupItem item;
  final double width;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = item.onTap != null;
    return Touchable(
      onTap: item.onTap,
      pressedScale: enabled ? context.theme.motion.pressIconScale : null,
      haptic: true,
      child: Opacity(
        opacity: enabled ? 1 : context.theme.button.disabledOpacity,
        child: SizedBox(
          width: width,
          child: Center(
            child: AppIcon(item.icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}
