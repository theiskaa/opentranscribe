import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_platform_view.dart';

class LiquidPopupButtonEntry {
  const LiquidPopupButtonEntry({
    required this.value,
    required this.label,
    this.icon,
    this.iconBytes,
    this.children = const [],
    this.causesNavigation = false,
    this.isDestructive = false,
    this.isSelected = false,
    this.keepsPresented = false,
  }) : isDivider = false;

  const LiquidPopupButtonEntry.submenu({required this.label, required this.children, this.icon})
    : value = '__submenu__',
      iconBytes = null,
      isDivider = false,
      causesNavigation = false,
      isDestructive = false,
      isSelected = false,
      keepsPresented = false;

  /// Creates a divider entry that visually separates menu items.
  const LiquidPopupButtonEntry.divider()
    : value = '__divider__',
      label = '',
      icon = null,
      iconBytes = null,
      children = const [],
      isDivider = true,
      causesNavigation = false,
      isDestructive = false,
      isSelected = false,
      keepsPresented = false;

  final String value;
  final String label;

  /// SF Symbol name for this menu item (iOS only).
  final String? icon;

  /// Raw image bytes (PNG) for a mark with no SF Symbol (e.g. a brand logo),
  /// rendered as a template beside the label. Travels with the menu over the
  /// channel, so it needs no asset-catalog entry. Wins over [icon] natively.
  final Uint8List? iconBytes;

  /// When non-null, this entry is rendered as a submenu.
  final List<LiquidPopupButtonEntry> children;

  /// Whether this entry is a divider.
  final bool isDivider;

  /// Whether selecting this entry will cause navigation to another page.
  /// When true, the button will be hidden during navigation to prevent
  /// visual glitches with Platform View animations.
  final bool causesNavigation;

  /// Whether this entry should be shown as destructive.
  final bool isDestructive;

  /// Whether this entry renders with a selection checkmark (UIMenu state).
  final bool isSelected;

  /// Keeps the menu presented when this entry is selected (a toggle that
  /// will be tapped again in the same visit); the native side flips the
  /// entry's checkmark in place so the open menu shows the new state
  /// without waiting a channel round trip.
  final bool keepsPresented;

  Map<String, dynamic> toMap() => {
    'value': value,
    'label': label,
    if (icon != null) 'icon': icon,
    if (iconBytes != null) 'iconBytes': iconBytes,
    if (children.isNotEmpty) 'children': children.map((e) => e.toMap()).toList(),
    if (isDivider) 'isDivider': true,
    if (isDestructive) 'isDestructive': true,
    if (isSelected) 'isSelected': true,
    if (keepsPresented) 'keepsPresented': true,
  };
}

class LiquidPopupButton extends StatefulWidget {
  const LiquidPopupButton({
    required this.items,
    this.onSelected,
    this.enabled = true,
    this.semanticLabel,
    this.buttonLabel,
    this.icon,
    this.iconPointSize,
    this.itemIconPointSize,
    this.size = 44,
    this.bare = false,
    this.isDark,
    this.placeholderBuilder,
    super.key,
  }) : assert(items.length > 0, 'At least one item is required');

  final List<LiquidPopupButtonEntry> items;

  /// Called after the dismiss delay when the menu item action should execute.
  final ValueChanged<String>? onSelected;

  final bool enabled;
  final String? semanticLabel;
  final String? buttonLabel;
  final double size;

  /// SF Symbol name (iOS only). Example: `ellipsis`.
  final String? icon;

  /// SF Symbol point size (iOS only).
  final double? iconPointSize;

  /// Point size for the ITEM icons inside the menu, as opposed to the button's
  /// own. Defaults to 17 on the native side, which matches a menu row's label;
  /// without it UIKit draws each symbol at its intrinsic size and the icons
  /// read as oversized beside the text.
  final double? itemIconPointSize;

  /// Bare mode: the native button is invisible and fills whatever box this
  /// widget is given (no glass circle, no glyph, no visual overflow). Overlay
  /// it on any Flutter content to make that content the trigger of a real
  /// UIMenu, which UIKit only presents from a native control.
  final bool bare;

  /// Whether to use dark mode appearance.
  ///
  /// When specified, overrides the system's user interface style on iOS.
  /// This ensures the native component matches Flutter's theme.
  final bool? isDark;

  /// Built in place of the native view while this route is covered by another.
  final WidgetBuilder? placeholderBuilder;

  @override
  State<LiquidPopupButton> createState() => _LiquidPopupButtonState();
}

class _LiquidPopupButtonState extends State<LiquidPopupButton> {
  bool _isHidden = false;

  Map<String, dynamic> get _params => {
    'items': widget.items.map((entry) => entry.toMap()).toList(),
    'enabled': widget.enabled,
    'size': widget.size,
    if (widget.bare) 'bare': true,
    if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
    if (widget.buttonLabel != null) 'buttonLabel': widget.buttonLabel,
    if (widget.icon != null) 'icon': widget.icon,
    if (widget.iconPointSize != null) 'iconPointSize': widget.iconPointSize,
    if (widget.itemIconPointSize != null) 'itemIconPointSize': widget.itemIconPointSize,
    if (widget.isDark != null) 'isDark': widget.isDark,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.bare) {
      // Fills the parent's box; no square host, no visual overflow.
      return RepaintBoundary(
        child: Visibility.maintain(
          visible: !_isHidden,
          child: LiquidPlatformView(
            viewType: 'liquid_popup_button',
            creationParams: _params,
            onMethodCall: _handleMethodCall,
            placeholderBuilder: widget.placeholderBuilder,
          ),
        ),
      );
    }
    const visualOverflow = 12.0;
    final hostSize = widget.size + (visualOverflow * 2);

    // RepaintBoundary isolates Platform View in separate layer,
    // helping with compositing glitches during route transitions
    return RepaintBoundary(
      child: Visibility.maintain(
        visible: !_isHidden,
        child: SizedBox.square(
          dimension: widget.size,
          child: OverflowBox(
            minWidth: hostSize,
            minHeight: hostSize,
            maxWidth: hostSize,
            maxHeight: hostSize,
            child: SizedBox.square(
              dimension: hostSize,
              child: LiquidPlatformView(
                viewType: 'liquid_popup_button',
                creationParams: _params,
                onMethodCall: _handleMethodCall,
                placeholderBuilder: widget.placeholderBuilder,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Delay before executing action to let UIMenu dismiss animation complete.
  static const _dismissDelay = Duration(milliseconds: 150);

  /// Delay before restoring visibility after navigation.
  static const _restoreDelay = Duration(milliseconds: 500);

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

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSelected') {
      final value = call.arguments as String?;
      if (value != null) {
        final entry = _findEntryByValue(widget.items, value);
        final causesNavigation = entry?.causesNavigation ?? false;

        // Hide immediately if this action causes navigation
        if (causesNavigation) {
          setState(() => _isHidden = true);
        }

        // Give UIMenu time to complete dismiss animation before executing action
        await Future.delayed(_dismissDelay);
        if (!mounted) return;
        widget.onSelected?.call(value);

        // Restore visibility after navigation completes (when user returns)
        if (causesNavigation) {
          await Future.delayed(_restoreDelay);
          if (mounted) {
            setState(() => _isHidden = false);
          }
        }
      }
    }
  }
}
