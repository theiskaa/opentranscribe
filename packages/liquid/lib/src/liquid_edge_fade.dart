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
    this.isDark,
    this.fadeFrom = 0.5,
    this.placeholderBuilder,
    super.key,
  });

  final double height;

  /// Where the bar's content region ends (status inset plus rows, without the
  /// fade tail): the region the system effect treats as covered by the bar.
  final double chromeHeight;

  final Color color;

  /// Whether to use dark mode appearance.
  ///
  /// When specified, overrides the system's user interface style on iOS.
  /// This ensures the native component matches Flutter's theme.
  final bool? isDark;

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
          // The covered placeholder is typically a BackdropFilter fade, which
          // must never ride the settle beat over the live native view (see
          // [LiquidPlatformView.settleBuilder]); the wash ramp alone stands in
          // there, with the blur the native material's own.
          settleBuilder: (_) => _SettleWash(color: color, fadeFrom: fadeFrom),
          creationParams: {
            'color': color.toARGB32(),
            'fadeFrom': fadeFrom,
            'chromeHeight': chromeHeight,
            if (isDark != null) 'isDark': isDark,
          },
        ),
      ),
    );
  }
}

/// The wash ramp without any blur, mirroring the native GradientWashView (and
/// the drawn fade's mask): full [color] to [fadeFrom], eased to clear. Filter
/// free on purpose - it is the only stand-in safe to composite over the live
/// native view.
class _SettleWash extends StatelessWidget {
  const _SettleWash({required this.color, required this.fadeFrom});

  final Color color;
  final double fadeFrom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color,
            color,
            color.withValues(alpha: color.a * 0xB0 / 0xFF),
            color.withValues(alpha: 0),
          ],
          stops: [0, fadeFrom, fadeFrom + 0.5 * (1 - fadeFrom), 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
