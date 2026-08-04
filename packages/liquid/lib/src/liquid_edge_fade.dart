import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_platform_view.dart';

/// The native edge-fade material: the iOS 26 scroll-edge effect (the system
/// nav bar's progressive blur, radius easing to nothing) washed with [color]
/// down to [fadeFrom] (a fraction of [height]). Unlike a Flutter
/// BackdropFilter it blurs platform views scrolling under it, so native glass
/// controls can live in the content it covers. It never intercepts touches.
/// The blur's shape is the system's; only the wash follows [fadeFrom].
class LiquidEdgeFade extends StatelessWidget {
  const LiquidEdgeFade({
    required this.height,
    required this.chromeHeight,
    required this.color,
    required this.isDark,
    this.fadeFrom = 0.5,
    this.placeholderBuilder,
    super.key,
  });

  final double height;

  /// Where the bar's content region ends (status inset plus rows, without the
  /// fade tail): the region the system effect treats as covered by the bar.
  final double chromeHeight;

  final Color color;
  final bool isDark;
  final double fadeFrom;

  /// Shown while this route is covered by another, and carried over the native
  /// material's first frames after a return; pass the drawn fallback so the
  /// bar neither vanishes nor flashes during transitions.
  final WidgetBuilder? placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: LiquidPlatformView(
          viewType: 'liquid_edge_fade',
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          placeholderBuilder: placeholderBuilder,
          creationParams: {
            'color': color.toARGB32(),
            'fadeFrom': fadeFrom,
            'chromeHeight': chromeHeight,
            'isDark': isDark,
          },
        ),
      ),
    );
  }
}
