import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_popup_button.dart';

class LiquidPopupMenuEntry {
  const LiquidPopupMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.children = const [],
    this.causesNavigation = false,
  }) : isDivider = false;

  const LiquidPopupMenuEntry.submenu({required this.label, required this.children, this.icon})
    : value = '__submenu__',
      isDivider = false,
      causesNavigation = false;

  /// Creates a divider entry that visually separates menu items.
  const LiquidPopupMenuEntry.divider()
    : value = '__divider__',
      label = '',
      icon = null,
      children = const [],
      isDivider = true,
      causesNavigation = false;

  final String value;
  final String label;
  final String? icon;
  final List<LiquidPopupMenuEntry> children;

  /// Whether this entry is a divider.
  final bool isDivider;

  /// Whether selecting this entry will cause navigation to another page.
  final bool causesNavigation;

  LiquidPopupButtonEntry toButtonEntry() {
    if (isDivider) {
      return LiquidPopupButtonEntry.divider();
    }
    return LiquidPopupButtonEntry(
      value: value,
      label: label,
      icon: icon,
      children: children.map((e) => e.toButtonEntry()).toList(),
      causesNavigation: causesNavigation,
    );
  }
}

class LiquidPopupMenu extends StatefulWidget {
  const LiquidPopupMenu({
    required this.items,
    this.onSelected,
    this.enabled = true,
    this.semanticLabel,
    this.buttonLabel,
    this.icon,
    this.iconPointSize,
    this.isDark,
    super.key,
  }) : assert(items.length > 0, 'At least one item is required');

  final List<LiquidPopupMenuEntry> items;

  /// Called after the dismiss delay when the menu item action should execute.
  final ValueChanged<String>? onSelected;

  final bool enabled;
  final String? semanticLabel;
  final String? buttonLabel;
  final String? icon;
  final double? iconPointSize;

  /// Whether to use dark mode appearance.
  ///
  /// When specified, overrides the system's user interface style on iOS.
  /// This ensures the native component matches Flutter's theme.
  final bool? isDark;

  @override
  State<LiquidPopupMenu> createState() => _LiquidPopupMenuState();
}

class _LiquidPopupMenuState extends State<LiquidPopupMenu> {
  @override
  Widget build(BuildContext context) {
    return LiquidPopupButton(
      items: widget.items.map((e) => e.toButtonEntry()).toList(),
      onSelected: widget.onSelected,
      enabled: widget.enabled,
      semanticLabel: widget.semanticLabel,
      buttonLabel: widget.buttonLabel,
      icon: widget.icon,
      iconPointSize: widget.iconPointSize,
      isDark: widget.isDark,
    );
  }
}
