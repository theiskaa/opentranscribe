import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// The dash page indicator: one segment per page, the active one filled and a
/// touch wider so position reads by shape as well as color.
class PageIndicator extends StatelessWidget {
  const PageIndicator({required this.count, required this.index, super.key});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.pageIndicator;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: theme.motion.pageDash,
            curve: Curves.easeOut,
            margin: EdgeInsets.symmetric(horizontal: tokens.gap / 2),
            width: tokens.dashWidth + (i == index ? tokens.activeBulge : 0),
            height: tokens.dashHeight,
            decoration: BoxDecoration(
              color: i == index ? tokens.active : tokens.inactive,
              borderRadius: BorderRadius.circular(tokens.dashHeight),
            ),
          ),
      ],
    );
  }
}
