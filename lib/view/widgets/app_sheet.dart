import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';

/// A bottom sheet that rises to half the screen, flush to the left, right, and
/// bottom edges with only its top corners rounded. Resolves to whatever the
/// content pops with, or null when dismissed by the scrim or a downward drag.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  final motion = context.motionNow;
  final barrier = context.themeNow.barrier;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: barrier,
    transitionDuration: motion.indicator,
    pageBuilder: (context, animation, secondaryAnimation) => _SheetBody(builder: builder),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: motion.indicatorCurve);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> with SingleTickerProviderStateMixin {
  static const double _dismissDrag = 120;
  static const double _flingVelocity = 700;
  static const double _radius = 28;

  late final AnimationController _offset = AnimationController(
    vsync: this,
    value: 0,
    upperBound: double.infinity,
  );

  void _onDragUpdate(DragUpdateDetails d) {
    _offset.value = (_offset.value + d.primaryDelta!).clamp(0.0, double.infinity);
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (_offset.value > _dismissDrag || velocity > _flingVelocity) {
      Navigator.of(context).pop();
    } else {
      _offset.animateBack(
        0,
        duration: context.motionNow.indicator,
        curve: context.motionNow.indicatorCurve,
      );
    }
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final height = MediaQuery.sizeOf(context).height * 0.5;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _offset.value), child: child),
        child: GestureDetector(
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(_radius)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(_radius)),
              child: Column(
                children: [
                  // The grabber, the one affordance that says this drags down.
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.hairline,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
                      ),
                      child: widget.builder(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
