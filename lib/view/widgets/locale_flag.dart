import 'package:flutter/widgets.dart';

/// A flag emoji sized and optically centred for a chip or tile. Apple Color
/// Emoji draws the flag low and a touch left of its box, so a plain centred
/// [Text] leaves it sitting low-left. Do NOT set height 1 here: an emoji is
/// taller than a collapsed line box and anchors to the top-left of it, which
/// throws it into the tile's corner. Instead centre the natural glyph and lift
/// it up and right by a share of [size], so the nudge is a constant offset in
/// ems and holds at every chip size. One widget owns the offset so every flag
/// across the app lines up the same way.
///
/// Takes the resolved emoji (see `localeFlag`), not a locale tag.
class LocaleFlag extends StatelessWidget {
  const LocaleFlag(this.flag, {required this.size, super.key});

  /// The flag emoji glyph, e.g. from `localeFlag`.
  final String flag;

  /// The emoji font size.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: Offset(size * 0.04, -size * 0.05),
        child: Text(
          flag,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: size),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}
