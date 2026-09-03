import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The dash page indicator: one segment per page, the active one filled and a
/// touch wider so position reads by shape as well as color. With [onTap] each
/// dash answers a tap with its index over a finger-sized hit area; the caller
/// decides which indices to honor.
class PageIndicator extends StatelessWidget {
  const PageIndicator({required this.count, required this.index, this.onTap, super.key});

  final int count;
  final int index;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final duration = context.reduceMotion ? AppMotion.instant : theme.motion.pageDash;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          _Dash(
            tokens: theme.pageIndicator,
            active: i == index,
            duration: duration,
            onTap: onTap == null ? null : () => onTap!(i),
          ),
      ],
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash({
    required this.tokens,
    required this.active,
    required this.duration,
    required this.onTap,
  });

  final PageIndicatorTheme tokens;
  final bool active;
  final Duration duration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dash = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      margin: EdgeInsets.symmetric(horizontal: tokens.gap / 2),
      width: tokens.dashWidth + (active ? tokens.activeBulge : 0),
      height: tokens.dashHeight,
      decoration: BoxDecoration(
        color: active ? tokens.active : tokens.inactive,
        borderRadius: BorderRadius.circular(tokens.dashHeight),
      ),
    );
    if (onTap == null) return dash;
    return Touchable(
      onTap: onTap,
      pressedOpacity: 1,
      child: SizedBox(
        height: tokens.hitHeight,
        child: Center(child: dash),
      ),
    );
  }
}
