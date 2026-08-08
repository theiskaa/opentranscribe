import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/exporter_descriptor.dart';

/// A format's mark at chip size, never tinted to the theme.
class ExporterLogo extends StatelessWidget {
  const ExporterLogo(this.descriptor, {this.size = 18, super.key});

  final ExporterDescriptor descriptor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(descriptor.logo, width: size, height: size);
  }
}
