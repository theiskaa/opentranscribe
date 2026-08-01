import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/dither_card.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
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
      !day.isBefore(r.weekStart) && day.isBefore(addDays(r.weekStart, 7));
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

/// Which weeks newly gained a written reflection between two history reads,
/// so home can give ONLY the just-arrived card an entrance. A regenerated week
/// (same weekStart, new generatedAt) is not new here: its arrival plays on the
/// reflections surfaces, not as a second entrance in the timeline. Pure, so
/// the diff is tested.
Set<DateTime> newlyReflectedWeeks(List<Reflection> previous, List<Reflection> current) {
  final before = {for (final r in previous) r.weekStart};
  return {
    for (final r in current)
      if (!before.contains(r.weekStart)) r.weekStart,
  };
}

/// The reflection at the top of a week in the home journal: a quiet bordered
/// panel with an entry row's anatomy - the week it covers as the strong title
/// ("Reflection of Jul 20 – 26"), the excerpt quiet under it - so it reads as
/// journal matter, not chrome. A silent week is a minimal marker instead. The
/// panel starts at the content margin, flush with the records' rail;
/// horizontal insets only, the list owns the vertical spacing around it.
class ReflectionHomeCard extends StatelessWidget {
  const ReflectionHomeCard({required this.reflection, required this.onTap, super.key});

  final Reflection reflection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    if (reflection.isSilent) {
      // The marker reads as text, so it lands on the records' text column.
      return Padding(
        padding: EdgeInsets.fromLTRB(theme.entryList.textColumnInset, 0, AppSpacing.xl, 0),
        child: _QuietWeekMarker(label: l10n.reflectionQuietWeek),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Touchable(
        onTap: onTap,
        child: DitherCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reflectionOfWeek(weekRangeLabel(reflection.weekStart, localeTag(context))),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headline.copyWith(color: theme.text),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  reflection.text!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: theme.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The silent week's one-line marker: a drawn bullet leading the localized
/// label, so the glyph and its spacing never live inside a translation.
class _QuietWeekMarker extends StatelessWidget {
  const _QuietWeekMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = AppType.footnote.copyWith(color: theme.textSecondary);
    return Row(
      children: [
        Text('·', style: style),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, style: style)),
      ],
    );
  }
}
