import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A plain cross-fade, for a screen that should NOT slide - one carrying
/// platform views, whose horizontal travel composites badly (the gallery).
class FadePage<T> extends CustomTransitionPage<T> {
  FadePage({required super.child, super.key, super.name})
    : super(
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}

/// A push that slides in from the trailing edge; popping mirrors it, so
/// navigation keeps a sense of direction.
class SlidePage<T> extends CustomTransitionPage<T> {
  SlidePage({required super.child, super.key, super.name})
    : super(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
}

/// A full-screen sheet rising from the bottom, for surfaces that sit on top of
/// the app rather than beside it. It leaves the instant it is asked to: the
/// rise DECELERATES (no slow ramp in, which is what reads as lag), and the
/// dismissal accelerates away.
class SlideUpPage<T> extends CustomTransitionPage<T> {
  SlideUpPage({required super.child, super.key, super.name})
    : super(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
          child: child,
        ),
      );
}
