import 'dart:math' show max;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';

/// A push that slides in from the trailing edge; popping mirrors it, so
/// navigation keeps a sense of direction. It also carries the native iOS edge
/// swipe-back: drag from the left edge to pop, interruptibly.
///
/// This is a hand-rolled [Page]/[PageRoute] rather than a go_router
/// `CustomTransitionPage` because the swipe gesture is not part of a transition:
/// Flutter welds it to `CupertinoPageRoute` and keeps the two gesture widgets
/// private. The gesture only drives the route's animation controller, and the
/// [SlideTransition] below is bound to that same controller, so re-authoring the
/// gesture (see [_BackGestureDetector]) drives our existing slide unchanged.
class SlidePage<T> extends Page<T> {
  const SlidePage({required this.child, super.key, super.name, super.arguments});

  final Widget child;

  // The route's duration getters have no context, so the motion is read here,
  // where there is one, and captured for the route's life.
  @override
  Route<T> createRoute(BuildContext context) => _SlidePageRoute<T>(this, context.motionNow);
}

class _SlidePageRoute<T> extends PageRoute<T> {
  _SlidePageRoute(SlidePage<T> page, this._motion) : super(settings: page);

  final AppMotion _motion;

  static final Animatable<Offset> _offset = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );
  // The eased form for a tap/programmatic push. During a drag the raw animation
  // is used instead, so the page tracks the finger 1:1 (Cupertino's linear flag).
  late final Animatable<Offset> _easedOffset = _offset.chain(
    CurveTween(curve: _motion.routeSlideCurve),
  );

  Widget get _child => (settings as SlidePage<T>).child;

  @override
  Duration get transitionDuration => _motion.routeSlide;

  @override
  Duration get reverseTransitionDuration => _motion.routeSlide;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  bool get barrierDismissible => false;

  // No dim on the page below: darkening a screen that isn't moving read as off.
  // The leading-edge shadow alone separates the two while this one slides over.
  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(scopesRoute: true, explicitChildNodes: true, child: _child);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Reduce Motion stills the travel and fades instead; the back swipe keeps
    // its 1:1 slide (direct manipulation, latch-held through the settle). Only
    // the animation objects swap between the modes: reshaping the tree when a
    // drag starts would re-inflate the detector and drop the live pointer.
    final still = context.reduceMotion && !popGestureInProgress;
    final edge = context.read<ThemeCubit>().state.resolved.navigation.edgeShadow;
    return FadeTransition(
      opacity: still ? animation : const AlwaysStoppedAnimation(1.0),
      child: SlideTransition(
        position: still
            ? const AlwaysStoppedAnimation(Offset.zero)
            : animation.drive(popGestureInProgress ? _offset : _easedOffset),
        // A soft shadow cast off the leading edge onto the page below, so the two
        // read as stacked rather than abutting. Strengthens as the page arrives.
        child: DecoratedBoxTransition(
          decoration: still
              ? const AlwaysStoppedAnimation<Decoration>(_EdgeShadowDecoration())
              : animation.drive(_EdgeShadowDecoration.tween(edge)),
          position: DecorationPosition.foreground,
          child: _BackGestureDetector<T>(
            enabledCallback: () => popGestureEnabled,
            onStartPopGesture: _startPopGesture,
            child: child,
          ),
        ),
      ),
    );
  }

  _BackGestureController<T> _startPopGesture() {
    return _BackGestureController<T>(
      navigator: navigator!,
      controller: controller!,
      getIsActive: () => isActive,
      getIsCurrent: () => isCurrent,
      settle: _motion.routeSwipeSettle,
      curve: _motion.routeSlideCurve,
    );
  }
}

// The left-edge grab area and the fling threshold, matching Cupertino's own:
// gesture geometry, not motion, so they stay off the theme.
const double _kBackGestureWidth = 20;
const double _kMinFlingVelocity = 1; // Screen widths per second.

/// A left-edge horizontal-drag detector that drives an interruptible pop.
///
/// Faithful port of Flutter's private `_CupertinoBackGestureDetector` (as of
/// 3.44): a translucent [Listener] over the leading edge feeds a horizontal
/// recognizer, and the recognizer hands drag input to a [_BackGestureController]
/// that moves the route's own animation.
class _BackGestureDetector<T> extends StatefulWidget {
  const _BackGestureDetector({
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
  });

  final Widget child;
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<_BackGestureController<T>> onStartPopGesture;

  @override
  State<_BackGestureDetector<T>> createState() => _BackGestureDetectorState<T>();
}

class _BackGestureDetectorState<T> extends State<_BackGestureDetector<T>> {
  _BackGestureController<T>? _controller;
  late final HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    // If disposed mid-drag, release the navigator's user-gesture latch next frame.
    if (_controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller?.navigator.mounted ?? false) _controller?.navigator.didStopUserGesture();
        _controller = null;
      });
    }
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _controller = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _controller!.dragUpdate(_toLogical(details.primaryDelta! / context.size!.width));
  }

  void _handleDragEnd(DragEndDetails details) {
    _controller!.dragEnd(_toLogical(details.velocity.pixelsPerSecond.dx / context.size!.width));
    _controller = null;
  }

  void _handleDragCancel() {
    // Can fire without a matching start (paired with the "down" we ignore).
    _controller?.dragEnd(0);
    _controller = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) _recognizer.addPointer(event);
  }

  double _toLogical(double value) => switch (Directionality.of(context)) {
    TextDirection.rtl => -value,
    TextDirection.ltr => value,
  };

  @override
  Widget build(BuildContext context) {
    // Widen the grab area into the notch/safe-area inset on the leading side.
    final double edgeInset = switch (Directionality.of(context)) {
      TextDirection.rtl => MediaQuery.paddingOf(context).right,
      TextDirection.ltr => MediaQuery.paddingOf(context).left,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: max(edgeInset, _kBackGestureWidth),
          top: 0,
          bottom: 0,
          child: Listener(onPointerDown: _handlePointerDown, behavior: HitTestBehavior.translucent),
        ),
      ],
    );
  }
}

/// Drives an interruptible pop from drag input, working in logical coordinates
/// (0.0 = previous page, 1.0 = this page on top).
///
/// Faithful port of Flutter's private `_CupertinoBackGestureController` (3.44).
class _BackGestureController<T> {
  _BackGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsActive,
    required this.getIsCurrent,
    required this.settle,
    required this.curve,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;
  final ValueGetter<bool> getIsActive;
  final ValueGetter<bool> getIsCurrent;

  /// The full travel time of a released swipe, and its curve.
  final Duration settle;
  final Curve curve;

  void dragUpdate(double delta) => controller.value -= delta;

  void dragEnd(double velocity) {
    final bool isCurrent = getIsCurrent();
    final bool animateForward;

    if (!isCurrent) {
      // Already navigated away from (a programmatic pop landed mid-drag): the
      // direction follows whether the route is still on the stack, not the drag.
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      // Scale the drop by the distance left, not a fixed time: releasing near the
      // edge finishes at once instead of crawling the last sliver over the full
      // settle, and a long return still gets the whole duration. (Cupertino's own.)
      final remaining = (1 - controller.value).clamp(0.0, 1.0);
      controller.animateTo(1, duration: settle * remaining, curve: curve);
    } else {
      if (isCurrent) navigator.pop();
      // The pop may settle inline if already at the target.
      if (controller.isAnimating) {
        final remaining = controller.value.clamp(0.0, 1.0);
        controller.animateBack(0, duration: settle * remaining, curve: curve);
      }
    }

    if (controller.isAnimating) {
      // Hold the user-gesture latch until the settle finishes so the transition
      // curve is not swapped mid-flight.
      late final AnimationStatusListener onDone;
      onDone = (status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(onDone);
      };
      controller.addStatusListener(onDone);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

/// A gradient shadow painted just off the leading edge of a page, onto the page
/// below it. Port of Flutter's private `_CupertinoEdgeShadowDecoration`. [tween]
/// animates it in with the route: it starts drawing nothing and ends at [edge]
/// fading to transparent inward.
class _EdgeShadowDecoration extends Decoration {
  const _EdgeShadowDecoration([this.colors]);

  /// From the leading edge inward. Null means no shadow.
  final List<Color>? colors;

  static DecorationTween tween(Color edge) => DecorationTween(
    begin: const _EdgeShadowDecoration(),
    end: _EdgeShadowDecoration([edge, edge.withValues(alpha: 0)]),
  );

  @override
  _EdgeShadowDecoration lerpFrom(Decoration? a, double t) =>
      _lerp(a is _EdgeShadowDecoration ? a : null, this, t);

  @override
  _EdgeShadowDecoration lerpTo(Decoration? b, double t) =>
      _lerp(this, b is _EdgeShadowDecoration ? b : null, t);

  static _EdgeShadowDecoration _lerp(_EdgeShadowDecoration? a, _EdgeShadowDecoration? b, double t) {
    final from = a?.colors;
    final to = b?.colors;
    if (from == null && to == null) return const _EdgeShadowDecoration();
    final length = (to ?? from)!.length;
    const clear = Color(0x00000000);
    return _EdgeShadowDecoration([
      for (var i = 0; i < length; i++) Color.lerp(from?[i] ?? clear, to?[i] ?? clear, t)!,
    ]);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _EdgeShadowPainter(this);

  @override
  bool operator ==(Object other) =>
      other is _EdgeShadowDecoration && listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hashAll(colors ?? const []);
}

class _EdgeShadowPainter extends BoxPainter {
  _EdgeShadowPainter(this._decoration);

  final _EdgeShadowDecoration _decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final colors = _decoration.colors;
    if (colors == null) return;
    final size = configuration.size!;
    // One shaded rect, not a band per pixel: this repaints every frame of
    // every push and pop.
    final shadowWidth = 0.05 * size.width;
    final (double direction, double start) = switch (configuration.textDirection ??
        TextDirection.ltr) {
      TextDirection.rtl => (1, offset.dx + size.width),
      TextDirection.ltr => (-1, offset.dx),
    };
    final outer = start + direction * shadowWidth;
    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset(start, offset.dy), Offset(outer, offset.dy), colors, [
        for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
      ]);
    canvas.drawRect(
      Rect.fromPoints(Offset(start, offset.dy), Offset(outer, offset.dy + size.height)),
      paint,
    );
  }
}
