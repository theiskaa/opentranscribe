import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';

void main() {
  const motion = AppMotion();

  test(
    "a pushed page slides for 300ms on Cupertino's curve and settles a dropped swipe in 350ms",
    () {
      expect(motion.routeSlide, const Duration(milliseconds: 300));
      expect(motion.routeSlideCurve, Curves.fastEaseInToSlowEaseOut);
      expect(motion.routeSwipeSettle, const Duration(milliseconds: 350));
    },
  );

  test('home arrives over half a second from 97% and steps back in a fifth', () {
    expect(motion.arrival, const Duration(milliseconds: 500));
    expect(motion.arrivalReverse, const Duration(milliseconds: 200));
    expect(motion.arrivalCurve, Curves.easeOutCubic);
    expect(motion.arrivalScale, 0.97);
  });

  test('the full-screen sheet decelerates in over 300ms and accelerates out in 260ms', () {
    expect(motion.fullSheetRise, const Duration(milliseconds: 300));
    expect(motion.fullSheetLeave, const Duration(milliseconds: 260));
    expect(motion.fullSheetRiseCurve, Curves.easeOutCubic);
    expect(motion.fullSheetLeaveCurve, Curves.easeInCubic);
  });
}
