import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// The chrome that lets content scroll under a screen edge: a progressive
/// backdrop blur washed with [color], fully opaque down to [fadeFrom] (a
/// fraction of [height]) and easing to nothing below it. The material behind
/// the app's bars. Mount it as a Positioned overlay painted over the scrolling
/// content; it ignores pointers.
class EdgeFade extends StatelessWidget {
  const EdgeFade({
    required this.height,
    required this.color,
    required this.sigma,
    this.fadeFrom = 0.5,
    super.key,
  });

  final double height;
  final Color color;
  final double sigma;
  final double fadeFrom;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: ClipRect(
          child: ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Eased, not linear: a straight ramp reads as a visible edge.
              colors: const [
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0xB0000000),
                Color(0x00000000),
              ],
              stops: [0, fadeFrom, fadeFrom + 0.5 * (1 - fadeFrom), 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}
