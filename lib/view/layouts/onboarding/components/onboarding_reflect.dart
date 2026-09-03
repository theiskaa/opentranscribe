import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_page.dart';
import 'package:opentranscribe/view/widgets/dither_card.dart';
import 'package:opentranscribe/view/widgets/dither_field.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

/// The ISO 8601 week number of [day]: the week holding its Thursday. Civil-day
/// arithmetic throughout, so a DST change between January and [day] cannot
/// shave the count by a day and slip the number by a week.
int isoWeekNumber(DateTime day) {
  final thursday = addDays(day, DateTime.thursday - day.weekday);
  return daysBetween(DateTime(thursday.year), thursday) ~/ 7 + 1;
}

/// The second page: your week, read back. Four days of entries as home lists
/// them, and beneath them the reflection card they became. Still: the page is
/// a fact about the app, not a performance of it.
class OnboardingReflect extends StatelessWidget {
  const OnboardingReflect({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OnboardingPage(
      scene: const _ReflectScene(),
      title: l10n.onboardingReflectTitle,
      body: l10n.onboardingReflectBody,
    );
  }
}

/// The days the four excerpts fall on, as offsets into the shown week.
const _dayOffsets = [0, 1, 3, 6];

class _ReflectScene extends StatelessWidget {
  const _ReflectScene();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    // Last week, on the locale's own first day, so the rows read as a real
    // week that has closed.
    final weekStart = addDays(startOfWeek(DateTime.now(), localeId: locale), -7);
    final excerpts = [
      l10n.onboardingReflectDay1,
      l10n.onboardingReflectDay2,
      l10n.onboardingReflectDay3,
      l10n.onboardingReflectDay4,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, text) in excerpts.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _DayRow(day: DateFormat.E(locale).format(addDays(weekStart, _dayOffsets[i])), text: text),
        ],
        const SizedBox(height: AppSpacing.lg),
        DitherCard(
          corner: DitherCorner.topRight,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Numbered from the week's middle: a Sunday-first week starts
                  // in the ISO week before the one its other six days are in.
                  l10n.onboardingReflectWeek(isoWeekNumber(addDays(weekStart, 3))).toUpperCase(),
                  style: AppType.eyebrow.copyWith(color: theme.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.onboardingReflectNote,
                  style: AppType.body.copyWith(color: theme.text, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One day of the week as home lists it: the weekday in the meta column, the
/// entry's first line beside it.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.text});

  final String day;
  final String text;

  /// The meta column's width: room for the widest three-letter weekday.
  static const _dayColumn = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: _dayColumn,
          child: Text(day, style: AppType.footnote.copyWith(color: theme.textSecondary)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.subhead.copyWith(color: theme.text),
          ),
        ),
      ],
    );
  }
}
