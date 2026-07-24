import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_icons.dart';

export 'package:opentranscribe/core/theming/app_icons.dart';

/// Renders one [AppIcons] glyph as text, the reeed way: a [Text] of the
/// codepoint, isolated from ambient text styling and text scaling. The subset
/// font is single-weight (regular), so there is no weight knob.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {this.size = 24, this.color, this.semanticsLabel, super.key});

  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      String.fromCharCode(icon.codePoint),
      semanticsLabel: semanticsLabel,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        inherit: false,
        fontFamily: icon.fontFamily,
        fontSize: size,
        color: color ?? IconTheme.of(context).color,
      ),
    );
  }
}
