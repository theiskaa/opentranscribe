import 'package:flutter/widgets.dart';
import 'package:opentranscribe/view/widgets/duo_style.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/layouts/home/components/week_calendar.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:flutter/rendering.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/period_math.dart';
import 'package:opentranscribe/core/utils/week.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/home/components/entry_row.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/dither_card.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:reflections/reflections.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/core/routes/routes.dart';

/// A card's identity in the home timeline: its period and start, so a day, its
/// week, and its month are distinct even when they share a start date.
typedef ReflectionCardKey = (ReflectionPeriod period, DateTime start);

/// [r]'s card identity. The one place the key is formed, so placement dedup and
/// entrance tracking can never key by different things.
ReflectionCardKey cardKeyOf(Reflection r) => (r.period, r.periodStart);

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
  bool covers(Reflection r, DateTime day) => periodContains(r.periodStart, r.period, day);
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

/// Cards whose section's rows are all dying and whose period covers no living
/// section's day: they fold WITH the exit instead of re-seating at the emit.
Set<ReflectionCardKey> unseatingCards({
  required Map<int, List<Reflection>> cards,
  required List<DateTime> sectionDays,
  required List<List<String>> sectionIds,
  required Set<String> dying,
}) {
  final living = [
    for (var i = 0; i < sectionDays.length; i++)
      if (!allDying(sectionIds[i], dying)) dateOnly(sectionDays[i]),
  ];
  final result = <ReflectionCardKey>{};
  for (final MapEntry(key: s, value: seated) in cards.entries) {
    if (!allDying(sectionIds[s], dying)) continue;
    for (final r in seated) {
      if (!living.any((day) => periodContains(r.periodStart, r.period, day))) {
        result.add(cardKeyOf(r));
      }
    }
  }
  return result;
}

/// A seated card and the day of the section it sits above.
typedef CardSeat = ({Reflection reflection, DateTime day});

/// Every seated card by key, in timeline order.
Map<ReflectionCardKey, CardSeat> cardSeats(
  Map<int, List<Reflection>> cards,
  List<DateTime> sectionDays,
) => {
  for (var i = 0; i < sectionDays.length; i++)
    for (final r in cards[i] ?? const <Reflection>[])
      cardKeyOf(r): (reflection: r, day: sectionDays[i]),
};

/// Cards seated last build with no seat now, by the day they sat above. A
/// card that merely re-seated is not departed.
Map<DateTime, List<Reflection>> departedCards(
  Map<ReflectionCardKey, CardSeat> previous,
  Map<ReflectionCardKey, CardSeat> current,
) {
  final result = <DateTime, List<Reflection>>{};
  for (final MapEntry(key: id, value: (:reflection, :day)) in previous.entries) {
    if (current.containsKey(id)) continue;
    (result[day] ??= []).add(reflection);
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
/// journal matter, not chrome. A DAILY card is the title alone (a day says
/// little, and its records sit right below); a week or a month keeps a short
/// two-line excerpt. A silent period is a minimal marker instead. The panel
/// starts at the content margin, flush with the records' rail; horizontal
/// insets only, the list owns the vertical spacing around it.
class ReflectionHomeCard extends StatefulWidget {
  const ReflectionHomeCard({required this.reflection, required this.onTap, super.key});

  final Reflection reflection;
  final VoidCallback onTap;

  @override
  State<ReflectionHomeCard> createState() => _ReflectionHomeCardState();
}

class _ReflectionHomeCardState extends State<ReflectionHomeCard> {
  bool _selected = false;
  bool _revealed = false;

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
    final reflection = widget.reflection;
    final period = reflection.period;
    final selected = PaneSelectionScope.isSelected(
      context,
      Uri(
        path: Routes.reflections,
        queryParameters: {'period': period.wire, 'week': reflection.periodKey},
      ),
    );
    final inner = duoJournalOf(context);
    if (!selected && PaneLayoutScope.maybeOf(context)?.layout.mode == PaneMode.split) {
      _revealed = false;
    }
    if (selected && !_revealed) {
      _revealed = true;
      final scroll = Scrollable.maybeOf(context)?.position;
      final line =
          AppTopBar.largeHeightOf(context) +
          AppSpacing.md +
          WeekCalendar.heightOf(context) +
          theme.topBar.fadeTail;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_selected || scroll == null) return;
        final box = context.findRenderObject();
        if (box == null) return;
        final offset = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset - line;
        scroll.jumpTo(offset.clamp(scroll.minScrollExtent, scroll.maxScrollExtent));
      });
    }
    _selected = selected;
    if (reflection.isSilent) {
      // The marker reads as text, so it lands on the records' text column.
      return Padding(
        padding: EdgeInsets.fromLTRB(theme.entryList.textColumnInset, 0, AppSpacing.xl, 0),
        child: _QuietMarker(icon: _periodIcon(period), label: reflectionQuietLabel(l10n, period)),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inner ? AppDuo.selectionInset : AppSpacing.xl),
      child: Semantics(
        selected: PaneLayoutScope.maybeOf(context)?.layout.mode == PaneMode.split ? selected : null,
        child: Touchable(
          onTap: () {
            if (inner) Haptics.selection();
            widget.onTap();
          },
          child: _ReflectionSurface(
            inner: inner,
            selected: selected,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Laid out at the glyph's own width, so the gap is exactly sm.
                      AppIcon(
                        _periodIcon(period),
                        size: AppType.headline.fontSize!,
                        color: theme.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.reflectionOfPeriod(
                            periodRangeLabel(period, reflection.periodStart, localeTag(context)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.headline.copyWith(color: theme.text),
                        ),
                      ),
                    ],
                  ),
                  // A day card is its title alone; a week or a month carries a
                  // short two-line excerpt beneath it.
                  if (period != ReflectionPeriod.daily) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      reflection.text!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(color: theme.textSecondary),
                    ),
                  ],
                ],
              ),
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
        AppIcon(icon, size: AppType.footnote.fontSize!, color: theme.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, style: style)),
      ],
    );
  }
}

class _ReflectionSurface extends StatelessWidget {
  const _ReflectionSurface({required this.inner, required this.selected, required this.child});

  final bool inner;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    if (!inner) {
      return DitherCard(
        background: selected ? theme.calendar.tileFill : null,
        border: selected ? theme.calendar.cursorBorder : null,
        child: child,
      );
    }
    return AnimatedContainer(
      duration: context.reduceMotion ? Duration.zero : theme.motion.selectionFade,
      curve: Curves.easeOut,
      decoration: SuperellipseDecoration(
        borderRadius: AppDuo.selectionRadius,
        color: selected ? theme.duo.selectionFill : theme.duo.surfaceElevated,
      ),
      child: child,
    );
  }
}
