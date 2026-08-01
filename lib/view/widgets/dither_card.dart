import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/view/widgets/dither_field.dart';

/// The reflection family's card surface: their ground and border, a dim
/// breath of dither in the bottom-right corner, [child] laid over it.
class DitherCard extends StatelessWidget {
  const DitherCard({required this.child, this.patch = const Size(150, 96), super.key});

  final Widget child;
  final Size patch;

  @override
  Widget build(BuildContext context) {
    final card = context.theme.reflectionCard;
    return DecoratedBox(
      decoration: SuperellipseDecoration(
        color: card.background,
        borderRadius: AppRadius.card,
        border: BorderSide(color: card.border),
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: Superellipse(radius: AppRadius.card)),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              width: patch.width,
              height: patch.height,
              child: IgnorePointer(child: DitherField(color: card.dither)),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
