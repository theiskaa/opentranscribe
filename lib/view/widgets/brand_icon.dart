import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A vendored brand mark (GitHub, X), tinted like any row icon. These are not SF
/// Symbols, so they ride as single-path SVGs rather than through [AppIcons].
class BrandIcon extends StatelessWidget {
  const BrandIcon(this.asset, {this.size = 20, this.color, super.key});

  /// One of [github], [x].
  final String asset;
  final double size;
  final Color? color;

  static const github = 'assets/brand/github.svg';
  static const x = 'assets/brand/x.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
