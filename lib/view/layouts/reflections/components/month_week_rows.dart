import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/layouts/reflections/components/period_children_logic.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The month page's contents block: one row per week, its range label on the
/// left and seven density dots on the right (full = a daily reflection, mid =
/// entries only, faint = nothing). Label ink strength is the tappable marker:
/// full [AppTheme.text] rows hold a stored weekly page and drill to it, muted
/// rows are texture. Pure data in, one callback out.
class MonthWeekRows extends StatelessWidget {
  const MonthWeekRows({required this.weeks, required this.onWeekTap, super.key});

  final List<MonthWeekRow> weeks;

  /// Fires with the STORED weekly start to land on ([MonthWeekRow.drillStart]).
  final ValueChanged<DateTime> onWeekTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final week in weeks) _WeekRow(week: week, onTap: onWeekTap)],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.week, required this.onTap});

  final MonthWeekRow week;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.calendar;
    final drillStart = week.drillStart;

    return Touchable(
      onTap: drillStart != null
          ? () {
              Haptics.selection();
              onTap(drillStart);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                weekRangeLabel(week.weekStart, localeTag(context)),
                style: AppType.subhead.copyWith(
                  color: drillStart != null ? theme.text : theme.textSecondary,
                ),
              ),
            ),
            for (final state in week.dayStates)
              Padding(
                padding: EdgeInsets.only(left: tokens.tileGap),
                child: Container(
                  width: tokens.dotSize,
                  height: tokens.dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (state) {
                      DayChipState.reflection => tokens.todayDot,
                      DayChipState.entries => tokens.dotEntries,
                      DayChipState.empty => tokens.dotEmpty,
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
