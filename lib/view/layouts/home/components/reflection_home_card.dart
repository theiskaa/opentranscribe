import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/dither_card.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// A card's identity in the home timeline: its period and start, so a day, its
/// week, and its month are distinct even when they share a start date.
typedef ReflectionCardKey = (ReflectionPeriod period, DateTime start);

/// [r]'s card identity. The one place the key is formed, so placement dedup and
/// entrance tracking can never key by different things.
ReflectionCardKey cardKeyOf(Reflection r) => (r.period, r.weekStart);

/// The reflections to show above the home timeline sections, keyed by section
/// index. Each enabled period places a card above the FIRST (most-recent)
/// section its range covers; more than one period can land on the same section,
/// so a section holds a LIST, ordered broad to narrow (month, week, day).
///
/// A reflection covers its period's range from the STORED start. This is
/// deliberately independent of the current locale's week boundary: an
/// app-language change can shift the first-day-of-week, but a reflection keeps
/// the period it was written for, so its card never silently drops out. A period
/// containing [today] (the still-open one) is never carded.
Map<int, List<Reflection>> reflectionCardsForSections({
  required List<DateTime> sectionDays,
  required List<Reflection> reflections,
  required DateTime today,
}) {
  final day0 = dateOnly(today);
  bool covers(Reflection r, DateTime day) => periodContains(r.weekStart, r.period, day);
  // Drop the open period (defensive: the service never reflects it anyway).
  final finished = [
    for (final r in reflections)
      if (!covers(r, day0)) r,
  ];

  final result = <int, List<Reflection>>{};
  final placed = <ReflectionCardKey>{};
  for (var i = 0; i < sectionDays.length; i++) {
    final day = dateOnly(sectionDays[i]);
    for (final r in finished) {
      final id = cardKeyOf(r);
      if (placed.contains(id)) continue;
      if (covers(r, day)) {
        (result[i] ??= []).add(r);
        placed.add(id);
      }
    }
  }
  // A month card sits above the week card sits above the day card, so the stack
  // reads outer to inner down to the day's own records. Relies on
  // ReflectionPeriod being declared narrow to broad (daily, weekly, monthly).
  for (final cards in result.values) {
    cards.sort((a, b) => b.period.index.compareTo(a.period.index));
  }
  return result;
}

/// Which cards newly gained a written reflection between two history reads, so
/// home can give ONLY the just-arrived card an entrance. A regenerated card
/// (same key, new generatedAt) is not new here: its arrival plays on the
/// reflections surfaces, not as a second entrance in the timeline. Pure, so the
/// diff is tested.
Set<ReflectionCardKey> newlyReflected(List<Reflection> previous, List<Reflection> current) {
  final before = {for (final r in previous) cardKeyOf(r)};
  return {
    for (final r in current)
      if (!before.contains(cardKeyOf(r))) cardKeyOf(r),
  };
}

/// The reflection at the top of a period in the home journal: a quiet bordered
/// panel with an entry row's anatomy - the period it covers as the strong title
/// ("Reflection of Jul 20 – 26"), the excerpt quiet under it - so it reads as
/// journal matter, not chrome. A DAILY card holds a single line (a day says
/// little); a week or a month keeps the fuller excerpt. A silent period is a
/// minimal marker instead. The panel starts at the content margin, flush with
/// the records' rail; horizontal insets only, the list owns the vertical
/// spacing around it.
class ReflectionHomeCard extends StatelessWidget {
  const ReflectionHomeCard({required this.reflection, required this.onTap, super.key});

  final Reflection reflection;
  final VoidCallback onTap;

  static String _quietLabel(AppLocalizations l10n, ReflectionPeriod period) => switch (period) {
    ReflectionPeriod.daily => l10n.reflectionQuietDay,
    ReflectionPeriod.weekly => l10n.reflectionQuietWeek,
    ReflectionPeriod.monthly => l10n.reflectionQuietMonth,
  };

  /// The numbered-calendar glyph that marks a card's period at a glance:
  /// 1.calendar for a day, 7.calendar for a week, the full calendar for a month.
  static IconData _periodIcon(ReflectionPeriod period) => switch (period) {
    ReflectionPeriod.daily => AppIcons.oneCalendar,
    ReflectionPeriod.weekly => AppIcons.sevenCalendar,
    ReflectionPeriod.monthly => AppIcons.calendar,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final period = reflection.period;
    if (reflection.isSilent) {
      // The marker reads as text, so it lands on the records' text column.
      return Padding(
        padding: EdgeInsets.fromLTRB(theme.entryList.textColumnInset, 0, AppSpacing.xl, 0),
        child: _QuietMarker(icon: _periodIcon(period), label: _quietLabel(l10n, period)),
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
                Row(
                  children: [
                    Icon(
                      _periodIcon(period),
                      size: AppType.headline.fontSize,
                      color: theme.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.reflectionOfWeek(
                          periodRangeLabel(period, reflection.weekStart, localeTag(context)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.headline.copyWith(color: theme.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  reflection.text!,
                  maxLines: period == ReflectionPeriod.daily ? 1 : 4,
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

/// The silent period's one-line marker: the period's calendar glyph leading the
/// localized label, so the glyph and its spacing never live inside a
/// translation and a quiet day/week/month still reads its period at a glance.
class _QuietMarker extends StatelessWidget {
  const _QuietMarker({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = AppType.footnote.copyWith(color: theme.textSecondary);
    return Row(
      children: [
        Icon(icon, size: AppType.footnote.fontSize, color: theme.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, style: style)),
      ],
    );
  }
}
