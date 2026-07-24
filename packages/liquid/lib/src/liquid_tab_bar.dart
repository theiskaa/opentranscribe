import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_platform_view.dart';

class LiquidTab {
  const LiquidTab({this.label, this.icon, this.asset})
    : assert(
        label != null || icon != null || asset != null,
        'Either label, icon, or asset must be provided',
      );

  final String? label;

  /// SF Symbols name (e.g. `house`, `ellipsis`).
  final String? icon;

  /// iOS asset catalog image name (e.g. `tab_menu`).
  ///
  /// This is resolved on the native iOS side using `UIImage(named:)`.
  final String? asset;

  Map<String, dynamic> toMap() => {
    'label': label ?? '',
    if (icon != null) 'icon': icon,
    if (asset != null) 'asset': asset,
  };
}

class LiquidTabBar extends StatefulWidget {
  const LiquidTabBar({
    required this.tabs,
    this.initialIndex = 0,
    this.onTabSelected,
    this.enabled = true,
    this.activeIconColor,
    this.inactiveIconColor,
    this.semanticLabel,
    this.isDark,
    this.actionIcon,
    this.actionIconColor,
    this.onActionPressed,
    super.key,
  }) : assert(
         tabs.length > 0 || actionIcon != null,
         'Provide at least one tab, or an actionIcon for an action-only bar',
       );

  final List<LiquidTab> tabs;
  final int? initialIndex;
  final ValueChanged<int>? onTabSelected;
  final bool enabled;

  /// Tint color for the selected tab icon.
  ///
  /// iOS: maps to `UITabBar.tintColor`.
  final Color? activeIconColor;

  /// Tint color for unselected tab icons.
  ///
  /// iOS: maps to `UITabBar.unselectedItemTintColor`.
  final Color? inactiveIconColor;
  final String? semanticLabel;

  /// Whether to use dark mode appearance.
  ///
  /// When specified, overrides the system's user interface style on iOS.
  /// This ensures the native component matches Flutter's theme.
  final bool? isDark;

  /// SF Symbols name for the action button shown to the right of the tab bar
  /// (e.g. `'plus'`, `'square.and.pencil'`).
  ///
  /// When null, no action button is rendered.
  final String? actionIcon;

  /// Tint color for the action button icon.
  ///
  /// When null, the system label color is used.
  final Color? actionIconColor;

  /// Called when the action button is tapped.
  final VoidCallback? onActionPressed;

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar> {
  Map<String, dynamic> get _params => {
    'tabs': widget.tabs.map((tab) => tab.toMap()).toList(),
    'initialIndex': widget.initialIndex,
    'enabled': widget.enabled,
    if (widget.activeIconColor != null) 'activeIconColor': widget.activeIconColor!.toARGB32(),
    if (widget.inactiveIconColor != null) 'inactiveIconColor': widget.inactiveIconColor!.toARGB32(),
    if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
    if (widget.isDark != null) 'isDark': widget.isDark,
    if (widget.actionIcon != null) 'actionIcon': widget.actionIcon,
    if (widget.actionIconColor != null) 'actionIconColor': widget.actionIconColor!.toARGB32(),
  };

  @override
  Widget build(BuildContext context) {
    return LiquidPlatformView(
      viewType: 'liquid_tab_bar',
      creationParams: _params,
      // The native bar applies initialIndex once and owns its selection from
      // then on; index-only rebuilds must not ping it mid-animation.
      creationOnlyParamKeys: const {'initialIndex'},
      onMethodCall: _handleMethodCall,
    );
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTabSelected':
        final index = call.arguments as int?;
        if (index != null) widget.onTabSelected?.call(index);
      case 'onActionPressed':
        widget.onActionPressed?.call();
    }
  }
}
