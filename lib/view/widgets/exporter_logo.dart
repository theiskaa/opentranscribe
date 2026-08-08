import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';

/// A format's mark at chip size. Each mark is normalized in its own asset, on
/// a square canvas that pads it to equal ink against the others, so this stays
/// one square box for every format instead of a table of per-mark sizes. A
/// branded mark keeps its own colors; a monochrome one paints in
/// `currentColor`, which resolves to the label color here so it never sinks
/// into a light or a dark card.
class ExporterLogo extends StatelessWidget {
  const ExporterLogo(this.descriptor, {this.size = 22, super.key});

  final ExporterDescriptor descriptor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      descriptor.logo,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: context.theme.text),
    );
  }
}
