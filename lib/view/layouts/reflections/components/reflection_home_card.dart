import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The reflection to show above the FIRST (most-recent) section of each finished
/// week in the home timeline, keyed by section index.
///
/// A reflection covers the 7 days [weekStart, weekStart+7); a section is matched
/// by whether its day falls in that range, using the STORED weekStart. This is
/// deliberately independent of the current locale's week boundary: an
/// app-language change can shift the first-day-of-week, but a reflection keeps
/// the week it was written for, so its card never silently drops out. A week
/// containing [today] (the open week) is never carded.
Map<int, Reflection> reflectionCardsForSections({
  required List<DateTime> sectionDays,
  required List<Reflection> reflections,
  required DateTime today,
}) {
  final day0 = dateOnly(today);
  bool covers(Reflection r, DateTime day) =>
      !day.isBefore(r.weekStart) && day.isBefore(r.weekStart.add(const Duration(days: 7)));
  // Drop the open week (defensive: the service never reflects it anyway).
  final finished = [
    for (final r in reflections)
      if (!covers(r, day0)) r,
  ];

  final result = <int, Reflection>{};
  final placed = <DateTime>{};
  for (var i = 0; i < sectionDays.length; i++) {
    final day = dateOnly(sectionDays[i]);
    for (final r in finished) {
      if (placed.contains(r.weekStart)) continue;
      if (covers(r, day)) {
        result[i] = r;
        placed.add(r.weekStart);
        break;
      }
    }
  }
  return result;
}

/// The reflection at the top of a week in the home journal: a written reflection
/// is a quiet surface card, tappable through to the Reflections screen; a silent
/// week is a minimal marker instead. Horizontal insets only; the list owns the
/// vertical spacing around it.
class ReflectionHomeCard extends StatelessWidget {
  const ReflectionHomeCard({required this.reflection, required this.onTap, super.key});

  final Reflection reflection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    // Land on the records' text column, aligned with the day splitter.
    return Padding(
      padding: EdgeInsets.fromLTRB(theme.entryList.textColumnInset, 0, AppSpacing.xl, 0),
      child: reflection.isSilent
          ? Text(
              '·  ${l10n.reflectionQuietWeek}',
              style: AppType.footnote.copyWith(color: theme.textSecondary),
            )
          : Touchable(
              onTap: onTap,
              child: DecoratedBox(
                decoration: SuperellipseDecoration(
                  borderRadius: AppRadius.card,
                  color: theme.surface,
                  border: BorderSide(color: theme.surfaceBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reflectionsTitle.toUpperCase(),
                        style: AppType.eyebrow.copyWith(color: theme.accent),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        reflection.text!,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(color: theme.text, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
