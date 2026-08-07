import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_platform_view.dart';

/// A native segmented control on iOS. On iOS 26 a `UISegmentedControl` adopts
/// Liquid Glass automatically, so this is the glass switcher; below it, it is
/// the plain system segmented control. It fills the size it is given, so wrap it
/// in a bounded box for a compact slot like a bar title.
///
/// [selectedIndex] is the source of truth: taps report through [onSelected], and
/// a change from outside (a deep-link landing on another segment) pushes the new
/// selection to the native control. The native side only moves when the index
/// actually differs, so a rebuild never disturbs a settled control.
class LiquidSegmentedControl extends StatefulWidget {
  const LiquidSegmentedControl({
    required this.segments,
    this.selectedIndex = 0,
    this.onSelected,
    this.enabled = true,
    this.selectedTintColor,
    this.labelColor,
    this.selectedLabelColor,
    this.semanticLabel,
    this.isDark,
    this.placeholderBuilder,
    super.key,
  }) : assert(segments.length > 0, 'Provide at least one segment');

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final bool enabled;

  /// The selected segment's background tint (iOS: `selectedSegmentTintColor`).
  final Color? selectedTintColor;

  /// The unselected label color.
  final Color? labelColor;

  /// The selected label color.
  final Color? selectedLabelColor;

  final String? semanticLabel;

  /// Overrides the native user-interface style so the control matches Flutter's
  /// theme rather than the system setting.
  final bool? isDark;

  /// Built in place of the native view while this route is covered by another.
  final WidgetBuilder? placeholderBuilder;

  @override
  State<LiquidSegmentedControl> createState() => _LiquidSegmentedControlState();
}

class _LiquidSegmentedControlState extends State<LiquidSegmentedControl> {
  Map<String, dynamic> get _params => {
    'segments': widget.segments,
    'selectedIndex': widget.selectedIndex,
    'enabled': widget.enabled,
    if (widget.selectedTintColor != null) 'selectedTintColor': widget.selectedTintColor!.toARGB32(),
    if (widget.labelColor != null) 'labelColor': widget.labelColor!.toARGB32(),
    if (widget.selectedLabelColor != null)
      'selectedLabelColor': widget.selectedLabelColor!.toARGB32(),
    if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
    if (widget.isDark != null) 'isDark': widget.isDark,
  };

  @override
  Widget build(BuildContext context) {
    return LiquidPlatformView(
      viewType: 'liquid_segmented_control',
      creationParams: _params,
      onMethodCall: _handleMethodCall,
      placeholderBuilder: widget.placeholderBuilder,
    );
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSelected') {
      final index = call.arguments as int?;
      if (index != null) widget.onSelected?.call(index);
    }
  }
}
