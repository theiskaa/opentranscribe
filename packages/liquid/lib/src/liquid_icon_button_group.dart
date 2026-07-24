import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_platform_view.dart';
import 'package:liquid/src/liquid_popup_button.dart';

/// An item in a [LiquidIconButtonGroup].
sealed class LiquidIconButtonGroupItem {
  const LiquidIconButtonGroupItem();

  Map<String, dynamic> toMap();
}

/// A plain action button inside a [LiquidIconButtonGroup].
class LiquidIconButtonGroupAction extends LiquidIconButtonGroupItem {
  const LiquidIconButtonGroupAction({
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.semanticLabel,
    this.causesNavigation = false,
  });

  /// SF Symbol name (e.g., `magnifyingglass`, `star`).
  final String icon;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  final bool enabled;
  final String? semanticLabel;

  /// Whether [onPressed] navigates to another page. When true, the group is
  /// hidden during navigation to prevent visual glitches with Platform View
  /// animations, then restored when the user returns.
  final bool causesNavigation;

  @override
  Map<String, dynamic> toMap() => {
    'type': 'action',
    'icon': icon,
    'enabled': enabled,
    if (semanticLabel != null) 'semanticLabel': semanticLabel,
  };
}

/// A menu-trigger button inside a [LiquidIconButtonGroup].
///
/// Tapping the button shows a native iOS popup menu.
class LiquidIconButtonGroupMenu extends LiquidIconButtonGroupItem {
  const LiquidIconButtonGroupMenu({
    required this.icon,
    required this.menuItems,
    this.onMenuSelected,
    this.enabled = true,
    this.semanticLabel,
  });

  /// SF Symbol name for the button icon (e.g., `ellipsis`).
  final String icon;

  /// The native iOS menu entries.
  final List<LiquidPopupButtonEntry> menuItems;

  /// Called with the selected item's string value after the menu dismisses.
  final ValueChanged<String>? onMenuSelected;

  final bool enabled;
  final String? semanticLabel;

  @override
  Map<String, dynamic> toMap() => {
    'type': 'menu',
    'icon': icon,
    'enabled': enabled,
    'items': menuItems.map((e) => e.toMap()).toList(),
    if (semanticLabel != null) 'semanticLabel': semanticLabel,
  };
}

/// A native iOS pill that groups multiple icon buttons into a single
/// glass-material surface.
///
/// On iOS 26+, the container's blur view automatically adopts the
/// Liquid Glass aesthetic.
///
/// Width is derived from [items.length] × [buttonSlotWidth].
/// Height defaults to 44 pt (standard nav-bar button height).
class LiquidIconButtonGroup extends StatefulWidget {
  const LiquidIconButtonGroup({
    required this.items,
    this.isDark,
    this.height = 44.0,
    this.slotWidth = buttonSlotWidth,
    this.iconPointSize,
    super.key,
  }) : assert(items.length >= 1, 'At least one item is required');

  final List<LiquidIconButtonGroupItem> items;
  final bool? isDark;
  final double height;

  /// Width allocated for each button slot inside the pill. Defaults to
  /// [buttonSlotWidth]; a caller can tighten it so the capsule is not wider than
  /// the icons need.
  final double slotWidth;
  final double? iconPointSize;

  /// The default per-slot width.
  static const double buttonSlotWidth = 52.0;

  @override
  State<LiquidIconButtonGroup> createState() => _LiquidIconButtonGroupState();
}

class _LiquidIconButtonGroupState extends State<LiquidIconButtonGroup> {
  bool _isHidden = false;

  /// Delay before executing the action to let the native UIMenu dismiss
  /// animation (or the hide) settle before navigation starts.
  static const _dismissDelay = Duration(milliseconds: 150);

  /// Delay before restoring visibility after navigation completes.
  static const _restoreDelay = Duration(milliseconds: 500);

  Map<String, dynamic> get _params => {
    'items': widget.items.map((item) => item.toMap()).toList(),
    'height': widget.height,
    if (widget.iconPointSize != null) 'iconPointSize': widget.iconPointSize,
    if (widget.isDark != null) 'isDark': widget.isDark,
  };

  @override
  Widget build(BuildContext context) {
    final width = widget.items.length * widget.slotWidth;
    // RepaintBoundary isolates the Platform View in a separate layer, helping
    // with compositing glitches during route transitions.
    return RepaintBoundary(
      child: Visibility.maintain(
        visible: !_isHidden,
        child: SizedBox(
          width: width,
          height: widget.height,
          child: LiquidPlatformView(
            viewType: 'liquid_icon_button_group',
            creationParams: _params,
            onMethodCall: _handleMethodCall,
          ),
        ),
      ),
    );
  }

  LiquidPopupButtonEntry? _findEntryByValue(List<LiquidPopupButtonEntry> entries, String value) {
    for (final entry in entries) {
      if (entry.value == value) return entry;
      if (entry.children.isNotEmpty) {
        final found = _findEntryByValue(entry.children, value);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Runs [action], hiding the group across the navigation it triggers when
  /// [causesNavigation] is true so the Platform View doesn't glitch during the
  /// route transition. Restores visibility once the user returns.
  Future<void> _runGuarded({required bool causesNavigation, required VoidCallback action}) async {
    if (causesNavigation) setState(() => _isHidden = true);

    // Give the UIMenu dismiss animation / the hide time to complete before
    // the action (and any navigation it triggers) runs.
    await Future.delayed(_dismissDelay);
    if (!mounted) return;
    action();

    if (causesNavigation) {
      await Future.delayed(_restoreDelay);
      if (mounted) setState(() => _isHidden = false);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];

      if (item is LiquidIconButtonGroupAction && call.method == 'onTap_$i') {
        if (item.causesNavigation) {
          await _runGuarded(causesNavigation: true, action: () => item.onPressed?.call());
        } else {
          item.onPressed?.call();
        }
        return;
      }

      if (item is LiquidIconButtonGroupMenu && call.method == 'onMenuSelected_$i') {
        final value = call.arguments as String?;
        if (value == null) return;
        final entry = _findEntryByValue(item.menuItems, value);
        await _runGuarded(
          causesNavigation: entry?.causesNavigation ?? false,
          action: () => item.onMenuSelected?.call(value),
        );
        return;
      }
    }
  }
}
