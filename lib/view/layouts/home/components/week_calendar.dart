import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The week strip in the home chrome, always visible. The soft border marks
/// [cursorDay] (the day the scroll is viewing; today at rest) and the strip
/// pages itself to the cursor's week as the scroll crosses weeks. Tapping an
/// enabled day (one with records, or today) NAVIGATES: the screen scrolls the
/// list to that day. Empty past days and the future render dimmed and dead,
/// and the past is bounded: the strip scrolls back no further than a few days
/// before the earliest record.
class WeekCalendar extends StatefulWidget {
  const WeekCalendar({
    required this.entryDays,
    required this.firstEntryDay,
    required this.cursorDay,
    required this.onDayTap,
    required this.onVisibleWeekChanged,
    required this.homeTick,
    super.key,
  });

  /// Local midnights that have at least one entry.
  final Set<DateTime> entryDays;

  /// The earliest of [entryDays], or null when the journal is empty.
  final DateTime? firstEntryDay;

  /// The day the scroll is viewing (never null: today at rest).
  final DateTime cursorDay;
  final ValueChanged<DateTime> onDayTap;

  /// Fires with the visible week's first day as swipes land, so the bar's
  /// month can follow the strip.
  final ValueChanged<DateTime> onVisibleWeekChanged;

  /// Bumped on a title tap to page the strip back to today's week, even when
  /// the cursor never moved because the list was already at the top. A swiped
  /// strip has no other way home in that state.
  final int homeTick;

  /// The strip's rendered height, for layouts that slide content under it.
  static double heightOf(BuildContext context) => context.theme.calendar.cellHeight;

  @override
  State<WeekCalendar> createState() => _WeekCalendarState();
}

class _WeekCalendarState extends State<WeekCalendar> {
  /// How many empty days before the first record stay visible as context.
  static const _leadIn = 5;

  PageController? _controller;
  int _weekCount = 1;

  /// The first day of the current locale's week containing [day].
  DateTime _weekStart(DateTime day) {
    // intl: FIRSTDAYOFWEEK is 0-based Monday; DateTime.weekday is 1-based Monday.
    final first = DateFormat().dateSymbols.FIRSTDAYOFWEEK + 1;
    final delta = (day.weekday - first + 7) % 7;
    return DateTime(day.year, day.month, day.day - delta);
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The earliest day the strip may show.
  DateTime get _minimumDay {
    final anchor = widget.firstEntryDay ?? _today;
    return DateTime(anchor.year, anchor.month, anchor.day - _leadIn);
  }

  void _configurePages() {
    final currentStart = _weekStart(_today);
    final minimumStart = _weekStart(_minimumDay);
    final count = currentStart.difference(minimumStart).inDays ~/ 7 + 1;
    if (count == _weekCount && _controller != null) return;
    final old = _controller;
    // A count change remaps page indices; keep the VIEWED WEEK stable by
    // translating it into the new numbering.
    var initial = count - 1;
    if (old != null && old.hasClients) {
      final viewed = _startOfPage(old.page?.round() ?? (_weekCount - 1));
      final weeksBack = currentStart.difference(viewed).inDays ~/ 7;
      initial = (count - 1 - weeksBack).clamp(0, count - 1);
    }
    _weekCount = count;
    _controller = PageController(initialPage: initial);
    if (old != null) {
      // The PageView in the tree still holds the old controller until it
      // rebuilds; disposing mid-build would detach a dead ChangeNotifier.
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  DateTime _startOfPage(int page) {
    final currentStart = _weekStart(_today);
    return DateTime(
      currentStart.year,
      currentStart.month,
      currentStart.day - 7 * (_weekCount - 1 - page),
    );
  }

  int _pageOfWeek(DateTime weekStart) {
    final currentStart = _weekStart(_today);
    final weeksBack = currentStart.difference(weekStart).inDays ~/ 7;
    return (_weekCount - 1 - weeksBack).clamp(0, _weekCount - 1);
  }

  @override
  void didUpdateWidget(WeekCalendar old) {
    super.didUpdateWidget(old);
    // A title tap sends the strip home to today's week even when the cursor
    // did not move (the list was already at the top), which the cursor-driven
    // path below would miss. Fast: it answers a touch, not a scroll.
    if (old.homeTick != widget.homeTick) {
      _slideToPage(_weekCount - 1, fast: true);
      return;
    }
    // The strip follows the cursor across weeks, straight to the final week.
    if (old.cursorDay == widget.cursorDay) return;
    _slideToPage(_pageOfWeek(_weekStart(widget.cursorDay)));
  }

  /// Slides the strip to [target], honouring Reduce Motion, and reports the
  /// month of the week we are heading to as the slide STARTS rather than when
  /// onPageChanged lands. A no-op when already there. [fast] is the tap
  /// answer's clock, quicker than the scroll-following slide's.
  void _slideToPage(int target, {bool fast = false}) {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    if (target == controller.page?.round()) return;
    if (context.reduceMotion) {
      controller.jumpToPage(target);
    } else {
      final motion = context.motionNow;
      controller.animateToPage(
        target,
        duration: fast ? motion.weekHome : motion.weekSlide,
        curve: Curves.easeOutCubic,
      );
    }
    // Post-frame because this may run inside a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisibleWeekChanged(_startOfPage(target));
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _configurePages();

    return SizedBox(
      height: WeekCalendar.heightOf(context),
      child: PageView.builder(
        controller: _controller,
        itemCount: _weekCount,
        onPageChanged: (page) => widget.onVisibleWeekChanged(_startOfPage(page)),
        itemBuilder: (context, page) {
          final start = _startOfPage(page);
          final days = [
            for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i),
          ];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _WeekRow(
              days: days,
              entryDays: widget.entryDays,
              today: _today,
              cursorDay: widget.cursorDay,
              onTap: (day) {
                Haptics.selection();
                widget.onDayTap(day);
              },
            ),
          );
        },
      ),
    );
  }
}

/// One week: a row of day tiles. The cursor is each tile's OWN border, lit in
/// place - a shape sliding across discrete tiles would cross the gaps and the
/// tiles between, which reads wrong for this shape language.
class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.days,
    required this.entryDays,
    required this.today,
    required this.cursorDay,
    required this.onTap,
  });

  final List<DateTime> days;
  final Set<DateTime> entryDays;
  final DateTime today;
  final DateTime cursorDay;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: _DayTile(
              day: day,
              hasEntries: entryDays.contains(day),
              isToday: day == today,
              isCursor: day == cursorDay,
              onTap: onTap,
            ),
          ),
      ],
    );
  }
}

/// One day: the weekday letter and the day number over a soft chip (a whisper
/// when the day holds nothing), today's dot beneath. The viewed day's soft
/// border fades up around whichever tile the scroll is reading.
class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.hasEntries,
    required this.isToday,
    required this.isCursor,
    required this.onTap,
  });

  final DateTime day;
  final bool hasEntries;
  final bool isToday;
  final bool isCursor;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.calendar;
    // Days with records navigate, and today always does, records or not; only
    // the empty past and the future are inert.
    final enabled = hasEntries || isToday;
    final numberColor = enabled ? tokens.dayNumberColor : tokens.disabledDayColor;
    final letterColor = enabled
        ? tokens.weekdayLabelColor
        : tokens.weekdayLabelColor.withValues(alpha: 0.5);
    final restingFill = enabled ? tokens.tileFill : tokens.tileFillMuted;

    return Touchable(
      onTap: enabled ? () => onTap(day) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.tileGap / 2),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: isCursor ? 1 : 0),
          duration: theme.motion.crossfade,
          curve: Curves.easeOut,
          builder: (context, t, child) => DecoratedBox(
            decoration: SuperellipseDecoration(
              borderRadius: tokens.tileRadius,
              color: restingFill,
              border: BorderSide(color: Color.lerp(null, tokens.cursorBorder, t)!),
            ),
            child: child,
          ),
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
                child: isToday
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
