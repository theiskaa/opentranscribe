import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/layouts/reflections/components/period_children_logic.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The week page's seven days under its title: solid ink = that day holds a
/// daily reflection and drills to it, soft chip with a dot = transcribed
/// entries only (texture, inert), a whisper = nothing. The row renders
/// whatever the week's own page status, and with daily reflections off it
/// still reads the week's rhythm. Pure data in, one callback out.
class DayChipRow extends StatelessWidget {
  const DayChipRow({required this.days, required this.states, required this.onDayTap, super.key});

  /// The week's seven civil days, in locale order ([daysOfWeek]).
  final List<DateTime> days;

  /// One [DayChipState] per day, same order.
  final List<DayChipState> states;

  /// Fires with the tapped day; only [DayChipState.reflection] chips respond.
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.theme.calendar.cellHeight,
      child: Row(
        children: [
          for (final (index, day) in days.indexed)
            Expanded(
              child: _DayChip(day: day, state: states[index], onTap: onDayTap),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.state, required this.onTap});

  final DateTime day;
  final DayChipState state;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.calendar;
    final solid = state == DayChipState.reflection;
    final fill = switch (state) {
      DayChipState.reflection => tokens.chipInk,
      DayChipState.entries => tokens.tileFill,
      DayChipState.empty => tokens.tileFillMuted,
    };
    final letterColor = switch (state) {
      DayChipState.reflection => tokens.onChipInk.withValues(alpha: 0.7),
      DayChipState.entries => tokens.weekdayLabelColor,
      DayChipState.empty => tokens.disabledWeekdayLabelColor,
    };
    final numberColor = switch (state) {
      DayChipState.reflection => tokens.onChipInk,
      DayChipState.entries => tokens.dayNumberColor,
      DayChipState.empty => context.highContrast ? theme.textSecondary : tokens.disabledDayColor,
    };

    return Touchable(
      onTap: solid
          ? () {
              Haptics.selection();
              onTap(day);
            }
          : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.tileGap / 2),
        child: DecoratedBox(
          decoration: SuperellipseDecoration(borderRadius: tokens.tileRadius, color: fill),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat.E(localeTag(context)).format(day).substring(0, 1).toUpperCase(),
                style: AppType.caption.copyWith(color: letterColor),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${day.day}',
                style: AppType.digits(
                  TextStyle(fontSize: tokens.dayNumberSize, fontWeight: FontWeight.w600),
                ).copyWith(color: numberColor),
              ),
              const SizedBox(height: AppSpacing.xxs),
              SizedBox(
                height: tokens.dotSize,
                child: state == DayChipState.entries
                    ? Container(
                        width: tokens.dotSize,
                        height: tokens.dotSize,
                        decoration: BoxDecoration(color: tokens.todayDot, shape: BoxShape.circle),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
