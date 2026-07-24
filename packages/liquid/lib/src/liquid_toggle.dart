import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_platform_view.dart';

/// Declarative Flutter widget that renders a native LiquidGlass toggle on iOS.
class LiquidToggle extends StatefulWidget {
  const LiquidToggle({
    required this.initialValue,
    this.onChanged,
    this.enabled = true,
    this.accentColor,
    this.semanticLabel,
    this.isDark,
    super.key,
  });

  /// Initial toggle value applied once when the platform view is created.
  ///
  /// Subsequent rebuilds do not propagate value changes to the native control.
  final bool initialValue;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Color? accentColor;
  final String? semanticLabel;

  /// Whether to use dark mode appearance.
  ///
  /// When specified, overrides the system's user interface style on iOS.
  /// This ensures the native component matches Flutter's theme.
  final bool? isDark;

  @override
  State<LiquidToggle> createState() => _LiquidToggleState();
}

class _LiquidToggleState extends State<LiquidToggle> {
  late final bool _initialValue;

  @override
  void initState() {
    super.initState();
    _initialValue = widget.initialValue;
  }

  Map<String, dynamic> get _params => {
    'initialValue': _initialValue,
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
