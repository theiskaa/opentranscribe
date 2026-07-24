import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_platform_view.dart';

/// A native iOS glass-style icon button.
///
/// On iOS 26+, displays a LiquidGlass circular button with an SF Symbol icon.
/// On older iOS versions, displays a tinted circular button.
///
/// This button performs a single action on tap, unlike [LiquidPopupButton]
/// which shows a menu.
class LiquidIconButton extends StatefulWidget {
  const LiquidIconButton({
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.iconPointSize,
    this.iconWeight,
    this.size = 44,
    this.semanticLabel,
    this.isDark,
    this.tintColor,
    super.key,
  });

  /// SF Symbol name (e.g., `plus`, `trash`, `square.and.arrow.up`).
  final String icon;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// Whether the button is enabled.
  final bool enabled;

  /// SF Symbol point size. Defaults to 17 on native side.
  final double? iconPointSize;

  /// SF Symbol weight: `ultraLight`, `thin`, `light`, `regular`, `medium`,
  /// `semibold`, `bold`, `heavy` or `black`.
  ///
  /// Defaults to `semibold` on native side.
  final String? iconWeight;

  /// Button size in logical pixels. Defaults to 44.
  final double size;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// Whether to use dark mode appearance.
  ///
  /// When specified, overrides the system's user interface style on iOS.
  /// This ensures the native component matches Flutter's theme.
  final bool? isDark;

  /// Tint color for the SF Symbol icon.
  ///
  /// When null, the system label color is used.
  final Color? tintColor;

  @override
  State<LiquidIconButton> createState() => _LiquidIconButtonState();
}

class _LiquidIconButtonState extends State<LiquidIconButton> {
  Map<String, dynamic> get _params => {
    'icon': widget.icon,
    'enabled': widget.enabled,
    'size': widget.size,
    if (widget.iconPointSize != null) 'iconPointSize': widget.iconPointSize,
    if (widget.iconWeight != null) 'iconWeight': widget.iconWeight,
    if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
    if (widget.isDark != null) 'isDark': widget.isDark,
    if (widget.tintColor != null) 'tintColor': widget.tintColor!.toARGB32(),
  };

  @override
  Widget build(BuildContext context) {
    const visualOverflow = 12.0;
    final hostSize = widget.size + (visualOverflow * 2);

    return SizedBox.square(
      dimension: widget.size,
      child: OverflowBox(
        minWidth: hostSize,
        minHeight: hostSize,
        maxWidth: hostSize,
        maxHeight: hostSize,
        child: SizedBox.square(
          dimension: hostSize,
          child: LiquidPlatformView(
            viewType: 'liquid_icon_button',
            creationParams: _params,
            onMethodCall: _handleMethodCall,
          ),
        ),
      ),
    );
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onTap') {
      widget.onPressed?.call();
    }
  }
}
