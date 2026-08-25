import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// Home's arrival out of onboarding: a fade with a touch of scale, so the app
/// reads as coming forward to meet the user rather than snapping into place.
/// An initial route never animates, so a plain launch is untouched; this only
/// ever plays on the one swap that ends the first run.
class ArrivalPage<T> extends CustomTransitionPage<T> {
  ArrivalPage({required super.child, super.key, super.name})
    : super(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (context.reduceMotion) return FadeTransition(opacity: animation, child: child);
          final eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: eased,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1).animate(eased),
              child: child,
            ),
          );
        },
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (context.reduceMotion) return FadeTransition(opacity: animation, child: child);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
            child: child,
          );
        },
      );
}
