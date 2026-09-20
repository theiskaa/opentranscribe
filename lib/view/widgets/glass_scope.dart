import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/utils/platform_caps.dart';

/// Where `AppToggle` and `AppSegmentedControl` may draw native glass. A drawn
/// bar fade cannot cover a platform view (the engine's blur over it turns
/// Liquid Glass into an opaque black rectangle), so content that scrolls under
/// one wraps its controls in a scope with [native] false and they take their
/// drawn faces. Only those two consult it; the other glass controls sit in or
/// over the bar, never under it.
class GlassScope extends InheritedWidget {
  const GlassScope({required this.native, required super.child, super.key});

  final bool native;

  /// Whether a control here may be native glass: the platform has it and no
  /// enclosing scope turned it off.
  static bool nativeOf(BuildContext context) =>
      PlatformCaps.nativeGlass &&
      (context.dependOnInheritedWidgetOfExactType<GlassScope>()?.native ?? true);

  @override
  bool updateShouldNotify(GlassScope oldWidget) => native != oldWidget.native;
}
