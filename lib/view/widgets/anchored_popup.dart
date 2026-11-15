import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';

/// The left edge of a popup [width] wide grown from [anchor]: right edges
/// aligned, held [AppSpacing.md] inside the safe band of a window
/// [windowWidth] wide, so a side status column never covers it.
double popupLeft({
  required Rect anchor,
  required double width,
  required double windowWidth,
  required EdgeInsets padding,
  Rect? modal,
}) {
  final min = (modal?.left ?? padding.left) + AppSpacing.md;
  final max = (modal?.right ?? windowWidth - padding.right) - width - AppSpacing.md;
  return (anchor.right - width).clamp(min, math.max(min, max));
}

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
          alignment: popupOrigin(
            anchor: anchor,
            modal: PaneLayoutScope.maybeOf(context)?.cover == true
                ? Offset.zero & MediaQuery.sizeOf(context)
                : modalRectOf(context),
            window: MediaQuery.sizeOf(context),
          ),
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

Rect popupBounds(BuildContext context) {
  final modal = modalRectOf(context);
  final tracker = PaneLayoutScope.maybeOf(context);
  final media = tracker?.media ?? MediaQuery.of(context);
  return Rect.fromLTRB(
    modal.left,
    math.max(modal.top, media.padding.top),
    modal.right,
    math.min(modal.bottom, media.size.height - media.padding.bottom),
  );
}

Alignment popupOrigin({required Rect anchor, required Rect modal, required Size window}) {
  final x = anchor.center.dx > modal.center.dx ? modal.right : modal.left;
  return Alignment(2 * x / window.width - 1, 2 * modal.top / window.height - 1);
}
