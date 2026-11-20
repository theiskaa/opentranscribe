import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/view/widgets/day_face.dart';

void main() {
  test('the phone week cells keep their original height at default text size', () {
    expect(
      phoneDayHeight(minimum: 60, scaler: TextScaler.noScaling, ambient: AppType.body, dotSize: 4),
      60,
    );
  });

  test('the phone week cells fit both lines and their dot at the largest iOS text size', () {
    const scaler = TextScaler.linear(53 / 17);
    final height = phoneDayHeight(minimum: 60, scaler: scaler, ambient: AppType.body, dotSize: 4);
    expect(height, greaterThan(60));
    expect(
      height,
      duoTextMetrics(style: AppType.body.merge(AppType.caption), scaler: scaler).height +
          AppSpacing.xxs +
          duoTextMetrics(
            style: AppType.body.merge(AppType.digits(AppType.headline)),
            scaler: scaler,
          ).height +
          8,
    );
  });

  group('dayDotBottom (where a day strip draws its dot)', () {
    test('the dot sits midway between the number baseline and the cell bottom', () {
      final bottom = dayDotBottom(
        cell: 60,
        letterLine: 12 * 1.45,
        numberLine: 17 * 1.45,
        numberSize: 17,
        dot: 4,
      );
      expect(bottom, closeTo(5.128, 1e-3));
    });

    test(
      'a taller cell gives half its gain to the space under the words, and the dot rises by half of that',
      () {
        double at(double cell) =>
            dayDotBottom(cell: cell, letterLine: 17.4, numberLine: 24.65, numberSize: 17, dot: 4);
        expect(at(70) - at(60), closeTo(2.5, 1e-9));
      },
    );
  });
}
