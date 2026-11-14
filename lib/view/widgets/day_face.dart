import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

/// How far above the cell's bottom a day's dot sits: midway between the
/// number's baseline and the bottom, so it takes no room from the centred
/// letter and number.
double dayDotBottom({
  required double cell,
  required double letterLine,
  required double numberLine,
  required double numberSize,
  required double dot,
}) {
  final below = (cell - (letterLine + AppSpacing.xxs + numberLine)) / 2;
  final baselineFromBottom = below + numberLine / 2 - baselineEm * numberSize;
  return (baselineFromBottom - dot) / 2;
}

/// SF Pro's baseline below the middle of an evenly-led line, in ems: half of
/// the iOS system font's ascent (0.952) less its descent (0.241).
const double baselineEm = 0.3555;

/// A day's face in a week strip, the home calendar's and the reflections'
/// alike: the weekday letter over the day number, centred in the cell, and a
/// dot under them when [dot] is set.
class DayFace extends StatelessWidget {
  const DayFace({
    required this.day,
    required this.letterColor,
    required this.numberColor,
    this.dot,
    super.key,
  });

  final DateTime day;
  final Color letterColor;
  final Color numberColor;

  /// The dot's colour, or null for no dot.
  final Color? dot;

  static const _letter = AppType.caption;
  static final _number = AppType.digits(AppType.headline);

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.calendar;
    final scaler = MediaQuery.textScalerOf(context);
    final ambient = DefaultTextStyle.of(context).style;
    double line(TextStyle style) =>
        scaler.scale(style.fontSize!) * AppType.lineHeightOf(style, ambient);
    final dot = this.dot;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              // The locale's own narrow weekday: a first letter reads 周 for
              // every day in Chinese.
              DateFormat('EEEEE', localeTag(context)).format(day).toUpperCase(),
              style: _letter.copyWith(color: letterColor),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text('${day.day}', style: _number.copyWith(color: numberColor)),
          ],
        ),
        if (dot != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: dayDotBottom(
              cell: tokens.cellHeight,
              letterLine: line(_letter),
              numberLine: line(_number),
              numberSize: scaler.scale(_number.fontSize!),
              dot: tokens.dotSize,
            ),
            child: Center(
              child: Container(
                width: tokens.dotSize,
                height: tokens.dotSize,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ),
          ),
      ],
    );
  }
}
