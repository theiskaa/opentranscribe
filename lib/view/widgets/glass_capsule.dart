import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/superellipse.dart';

/// A small frosted pill floating over content: the top bar's material
/// (a translucent tint over a backdrop blur) cut to a capsule, with the
/// hairline border the drawn glass controls share. The blur is clipped to
/// the shape, so only the capsule frosts what scrolls beneath it.
class GlassCapsule extends StatelessWidget {
  const GlassCapsule({
    required this.height,
    required this.tint,
    required this.border,
    required this.sigma,
    required this.child,
    super.key,
  });

  final double height;
  final Color tint;
  final Color border;
  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      // Zero smoothness: the continuous corner would square the short ends
      // off; a scrubber pill wants true circular caps, like the native one.
      clipper: ShapeBorderClipper(shape: Superellipse(radius: height, smoothness: 0)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: SuperellipseDecoration(
            borderRadius: height,
            smoothness: 0,
            color: tint,
            border: BorderSide(color: border),
          ),
          // widthFactor 1: the pill hugs its content; a plain Center would
          // stretch it across whatever width the caller offers.
          child: SizedBox(
            height: height,
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}
