import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// The loading indicator: a Lottie "dots" loader (reeed's). One of the app's two
/// sanctioned loops (the other is the live waveform), so it appears only while
/// something is genuinely in flight.
///
/// The animation ships as two pre-baked assets, black dots and white; there is
/// no runtime tint. That is enough, because the app's whole palette is ink on a
/// page - the loader picks whichever of the two reads on the surface behind it,
/// from the requested [color]'s luminance (a dark colour wants black dots).
class AppSpinner extends StatelessWidget {
  const AppSpinner({this.size = 20, this.color, super.key});

  final double size;
  final Color? color;

  static const _white = 'assets/animations/dots_loader_white.json';
  static const _black = 'assets/animations/dots_loader_black.json';

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.theme.textSecondary;
    final asset = tint.computeLuminance() < 0.5 ? _black : _white;
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(asset, width: size, height: size, fit: BoxFit.contain),
    );
  }
}
