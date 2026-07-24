import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/core/utils/platform_caps.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// One choice in a menu.
class AppMenuItem {
  const AppMenuItem({required this.label, this.icon, this.destructive = false});

  final String label;
  final IconData? icon;

  /// Marks what cannot be undone. It carries no colour: the app has none, so
  /// the confirm that follows does the warning.
  final bool destructive;
}

/// The menu's own metrics.
const double _menuWidth = 232;
const double _rowHeight = 44;
const double _menuGap = AppSpacing.sm;

/// Opens a menu ANCHORED to [anchor] (a global rect, usually the trigger's own
/// bounds) and resolves to the chosen index, or null if it was dismissed. It
/// grows out of the trigger rather than up from the bottom of the screen: a
/// menu belongs to the control that opened it.
Future<int?> showAppMenu(
  BuildContext context, {
  required Rect anchor,
  required List<AppMenuItem> items,
}) {
  // A one-shot read: this runs from tap handlers, where select is illegal.
  final motion = context.read<ThemeCubit>().state.resolved.motion;
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: const Color(0x00000000),
    transitionDuration: motion.indicator,
    pageBuilder: (context, animation, secondaryAnimation) =>
        _MenuBody(anchor: anchor, items: items),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: motion.indicatorCurve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          // Out of the trigger's near corner, so the menu reads as belonging
          // to what was tapped.
          alignment: anchor.center.dx > MediaQuery.sizeOf(context).width / 2
              ? Alignment.topRight
              : Alignment.topLeft,
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _MenuBody extends StatelessWidget {
  const _MenuBody({required this.anchor, required this.items});

  final Rect anchor;
  final List<AppMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final screen = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final height = items.length * _rowHeight + AppSpacing.sm * 2;

    // Below the trigger when there is room, above it when there is not.
    final below = anchor.bottom + _menuGap;
    final fits = below + height + insets.bottom + AppSpacing.md <= screen.height;
    final top = fits ? below : anchor.top - _menuGap - height;
    final left = (anchor.right - _menuWidth).clamp(
      AppSpacing.md,
      screen.width - _menuWidth - AppSpacing.md,
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top.clamp(insets.top + AppSpacing.md, screen.height - height),
          width: _menuWidth,
          child: DecoratedBox(
            decoration: SuperellipseDecoration(
              borderRadius: AppRadius.card,
              color: theme.surface,
              border: BorderSide(color: theme.surfaceBorder),
              shadows: [
                BoxShadow(
                  color: theme.shadow.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, item) in items.indexed)
                    _MenuRow(item: item, onTap: () => Navigator.of(context).pop(index)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});

  final AppMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Touchable(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      child: SizedBox(
        height: _rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(item.label, style: AppType.callout.copyWith(color: theme.text)),
              ),
              if (item.icon != null) ...[
                const SizedBox(width: AppSpacing.md),
                AppIcon(item.icon!, size: 17, color: theme.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A bar control that owns a menu: the NATIVE popup button on iOS 26 (a real
/// UIMenu under a glass circle) and the app's own circle plus [showAppMenu]
/// everywhere else, so the behaviour is the same wherever it runs.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({
    required this.icon,
    required this.items,
    required this.onSelected,
    this.size = 44,
    this.iconSize = 20,
    this.color,
    super.key,
  });

  final IconData icon;
  final List<AppMenuItem> items;
  final ValueChanged<int> onSelected;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (PlatformCaps.nativeGlass) {
      // The native menu answers with an entry's VALUE, not its position, so the
      // index is carried across as the value and handed back to the same
      // callback the fallback uses. Both sides then speak in indices.
      return LiquidPopupButton(
        icon: AppIcons.sfSymbolName(icon),
        iconPointSize: iconSize,
        // Sized to the row's own label, not to the symbol's intrinsic size,
        // which UIKit otherwise draws far larger than the words beside it.
        itemIconPointSize: AppType.callout.fontSize,
        size: size,
        items: [
          for (final (i, item) in items.indexed)
            LiquidPopupButtonEntry(
              value: '$i',
              label: item.label,
              icon: item.icon == null ? null : AppIcons.sfSymbolName(item.icon!),
              isDestructive: item.destructive,
            ),
        ],
        onSelected: (value) {
          final index = int.tryParse(value);
          if (index != null) onSelected(index);
        },
      );
    }
    return _MenuTrigger(
      icon: icon,
      items: items,
      onSelected: onSelected,
      size: size,
      iconSize: iconSize,
      color: color,
    );
  }
}

/// The non-native trigger. Stateful only to hold its own element, which is how
/// the menu learns where to grow from.
class _MenuTrigger extends StatefulWidget {
  const _MenuTrigger({
    required this.icon,
    required this.items,
    required this.onSelected,
    required this.size,
    required this.iconSize,
    required this.color,
  });

  final IconData icon;
  final List<AppMenuItem> items;
  final ValueChanged<int> onSelected;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  State<_MenuTrigger> createState() => _MenuTriggerState();
}

class _MenuTriggerState extends State<_MenuTrigger> {
  Future<void> _open() async {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final origin = box.localToGlobal(Offset.zero);
    final index = await showAppMenu(context, anchor: origin & box.size, items: widget.items);
    if (index != null) widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: widget.icon,
      onTap: _open,
      size: widget.size,
      iconSize: widget.iconSize,
      foreground: widget.color,
    );
  }
}
