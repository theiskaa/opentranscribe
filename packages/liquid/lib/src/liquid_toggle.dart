import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_platform_view.dart';

/// A native LiquidGlass toggle on iOS.
///
/// [value] is the source of truth: taps report through [onChanged], and a
/// change from outside (a row tap, a declined permission reverting the
/// setting) pushes the new value to the native control. The native side only
/// moves when the value actually differs, so a rebuild never disturbs a
/// settled switch.
class LiquidToggle extends StatefulWidget {
  const LiquidToggle({
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.accentColor,
    this.semanticLabel,
    this.isDark,
    this.placeholderBuilder,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Color? accentColor;
  final String? semanticLabel;

  /// Whether to use dark mode appearance.
  ///
  /// When specified, overrides the system's user interface style on iOS.
  /// This ensures the native component matches Flutter's theme.
  final bool? isDark;

  /// Built in place of the native view while this route is covered by another.
  final WidgetBuilder? placeholderBuilder;

  @override
  State<LiquidToggle> createState() => _LiquidToggleState();
}

class _LiquidToggleState extends State<LiquidToggle> {
  Map<String, dynamic> get _params => {
    'value': widget.value,
    'enabled': widget.enabled,
    if (widget.accentColor != null) 'accentColor': widget.accentColor!.toARGB32(),
    if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
    if (widget.isDark != null) 'isDark': widget.isDark,
  };

  @override
  Widget build(BuildContext context) {
    return LiquidPlatformView(
      viewType: 'liquid_toggle',
      creationParams: _params,
      onMethodCall: _handleMethodCall,
      placeholderBuilder: widget.placeholderBuilder,
    );
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onChanged') {
      final value = call.arguments as bool?;
      if (value != null) {
        widget.onChanged?.call(value);
      }
    }
  }
}
