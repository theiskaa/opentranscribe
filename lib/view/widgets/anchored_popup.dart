import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';

/// Opens an anchored popup (the menu, the dropdown) over a transparent barrier
/// and resolves to the caller's pop value. The one shared transition: a fade,
/// plus a scale growing out of the trigger's near corner so the popup reads as
/// belonging to what was tapped; fade-only under Reduce Motion, the same
/// degrade the sheet uses.
Future<T?> showAnchoredPopup<T>(
  BuildContext context, {
  required Rect anchor,
  required WidgetBuilder builder,
}) {
  // One-shot read: this runs from tap handlers, where select is illegal.
  final motion = context.motionNow;
  final reduceMotion = context.reduceMotion;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: const Color(0x00000000),
    transitionDuration: motion.indicator,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: motion.indicatorCurve);
      if (reduceMotion) return FadeTransition(opacity: curved, child: child);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          alignment: anchor.center.dx > MediaQuery.sizeOf(context).width / 2
              ? Alignment.topRight
              : Alignment.topLeft,
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The popup's card surface: the superellipse, the surface colours, and the
/// soft drop shadow, shared by the menu and the dropdown so they cannot drift.
class PopupSurface extends StatelessWidget {
  const PopupSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      decoration: SuperellipseDecoration(
        borderRadius: AppRadius.card,
        color: theme.surface,
        border: BorderSide(color: theme.surfaceBorder),
        shadows: [
          BoxShadow(
            color: theme.shadow.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
