import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';

/// A bottom sheet sized to its content, flush to the screen's edges with only
/// its top corners rounded. It rises, settles, and leaves on
/// [AppMotion.sheetSpring], seeded with the finger's release velocity so a
/// drag and its settle read as one motion; Reduce Motion swaps the travel for
/// a scrim fade. Resolves to whatever the content pops with, or null when
/// dismissed by the scrim or a downward drag.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  final motion = context.motionNow;
  final barrier = context.themeNow.barrier;
  final reduce = context.reduceMotion;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: barrier,
    // The route only fades the scrim; the sheet drives its own travel and
    // rides this duration out when popped mid-flight. Under Reduce Motion the
    // sheet joins the fade instead of travelling.
    transitionDuration: motion.sheetScrim,
    pageBuilder: (context, animation, secondaryAnimation) => _SheetBody(builder: builder),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        reduce ? FadeTransition(opacity: animation, child: child) : child,
  );
}

/// The exit spring's target, past fully-offscreen on purpose: the route's
/// reverse can undercut a critically damped settle, and the overshoot buys
/// the last sliver of travel before the overlay goes.
const double _exitTarget = 1.1;

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> with SingleTickerProviderStateMixin {
  /// Vertical offset in fractions of the panel's own height: 0 resting, 1
  /// fully offscreen. Fractions, because the panel's height is unknown until
  /// layout and the entrance must start before the first frame.
  late final AnimationController _frac;

  final GlobalKey _panel = GlobalKey();
  Animation<double>? _routeAnimation;
  bool _entered = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _frac = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    if (context.reduceMotion) {
      _frac.value = 0;
    } else {
      _spring(to: 0);
    }
    // A scrim tap or a programmatic pop reverses the route; the sheet leaves
    // under its own spring when that happens.
    _routeAnimation = ModalRoute.of(context)?.animation;
    _routeAnimation?.addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse || _leaving || !mounted) return;
    _leaving = true;
    if (!context.reduceMotion) _spring(to: _exitTarget);
  }

  void _spring({required double to, double velocity = 0}) {
    // Floor the settle at 0, like the drag: a release velocity pointing up would
    // otherwise make the spring overshoot past its target into a negative
    // fraction, lifting the panel off the bottom edge and exposing the screen
    // behind it.
    _frac.animateWith(
      ClampedSimulation(
        SpringSimulation(context.motionNow.sheetSpring, _frac.value, to, velocity),
        xMin: 0,
      ),
    );
  }

  double? get _height => _panel.currentContext?.size?.height;

  void _onDragUpdate(DragUpdateDetails d) {
    final height = _height;
    if (_leaving || height == null) return;
    _frac.value = (_frac.value + d.primaryDelta! / height).clamp(0.0, double.infinity);
  }

  void _onDragEnd(DragEndDetails d) {
    final height = _height;
    if (_leaving || height == null) return;
    final sheet = context.themeNow.sheet;
    final velocity = d.primaryVelocity ?? 0;
    if (_frac.value * height > sheet.dismissDrag || velocity > sheet.flingVelocity) {
      // Pop now so the scrim fades while the sheet springs away at the
      // finger's speed: one gesture, both layers leaving together.
      _leaving = true;
      Navigator.of(context).pop();
      _spring(to: _exitTarget, velocity: velocity / height);
    } else {
      _spring(to: 0, velocity: velocity / height);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _frac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = context.theme.sheet;
    final radius = BorderRadius.vertical(top: Radius.circular(sheet.radius));
    final screenHeight = MediaQuery.sizeOf(context).height;
    // The panel rides above the keyboard: no framework scaffold insets for
    // the IME here, so a sheet holding a text field must do it itself.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedPadding(
        duration: context.reduceMotion ? Duration.zero : context.motionNow.sheetScrim,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboard),
        child: AnimatedBuilder(
          animation: _frac,
          builder: (context, child) =>
              FractionalTranslation(translation: Offset(0, _frac.value), child: child),
          child: GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: ConstrainedBox(
              key: _panel,
              constraints: BoxConstraints(
                // max, not a bare subtraction: clamp throws when the bounds
                // invert, and a rotation frame can report a keyboard inset
                // taller than the screen it was measured against.
                maxHeight: (screenHeight * sheet.maxHeightFraction).clamp(
                  0.0,
                  math.max(0.0, screenHeight - keyboard),
                ),
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: sheet.background, borderRadius: radius),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The grabber, the one affordance that says this drags down.
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                        child: Container(
                          width: sheet.grabberWidth,
                          height: sheet.grabberHeight,
                          decoration: BoxDecoration(
                            color: sheet.grabberColor,
                            borderRadius: BorderRadius.circular(sheet.grabberHeight / 2),
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.xxl,
                            AppSpacing.xxl,
                            AppSpacing.xxl,
                            MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
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
        ),
      ),
    );
  }
}
