import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/home/components/seam_padding.dart';
import 'package:opentranscribe/view/widgets/delete_swipe.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

/// One record in the home list. There is no card and no border: a day's records
/// hang off a single hairline RAIL in the left gutter, each marked by a node on
/// the line. What separates two records is the node and the air around it; what
/// separates two DAYS is the rail stopping - a break in the ink, which reads at
/// a glance in a way a wider gap never does.
///
/// Swipe a row left to reveal Delete (see [DeleteSwipe]); only the text
/// column moves and it is clipped at the gutter, so the record slides UNDER the
/// rail rather than across it. A delete plays the swipe's exit first - the
/// whole slot (rail, node and day gap included, via [DeleteSwipe.frame]) fades
/// and closes before the row actually leaves the list.
class EntryRow extends StatelessWidget {
  const EntryRow({
    required this.entry,
    required this.last,
    required this.onTap,
    required this.openId,
    required this.onDelete,
    this.onDeleteStart,
    super.key,
  });

  final Entry entry;

  /// The day's last LIVING record (a dying successor is already gone for
  /// layout). The rail runs the full height of every row, gap included, so a
  /// day's records are strung on ONE continuous line; the last row simply has
  /// no gap, and the rail ends with its text.
  final bool last;
  final VoidCallback onTap;

  /// The one row currently swiped open, shared across the list.
  final ValueNotifier<String?> openId;
  final Future<void> Function(Entry) onDelete;

  /// A delete committed and its exit is about to play; the list uses this to
  /// close the surroundings (the neighbor's gap, an emptying day's title) in
  /// step with the slot instead of after it.
  final VoidCallback? onDeleteStart;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.entryList;
    final l10n = AppLocalizations.of(context)!;
    final excerpt = entry.readableText?.trim() ?? '';
    final title = entry.title;
    final leadStyle = title != null ? AppType.headline : AppType.body;

    return DeleteSwipe(
      id: entry.id,
      openId: openId,
      onTap: onTap,
      onDelete: () => onDelete(entry),
      onExitStart: onDeleteStart,
      label: l10n.delete,
      // Behind the record: the rail and its node are the list's structure, so
      // they hold still while the record slides. The swipe wraps only the text
      // column (right of the gutter), so the record never reaches the rail;
      // the frame ties rail, gutter and day gap to the row's exit.
      frame: (context, swipe) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: CustomPaint(
          painter: _RailPainter(
            railColor: tokens.railColor,
            nodeColor: tokens.nodeColor,
            railWidth: tokens.railWidth,
            nodeSize: tokens.nodeSize,
            nodeCenter: _firstLineCenter(leadStyle),
          ),
          // [last] FLIPS on a neighbor's delete or arrival, and the rail is
          // painted through this gap, so the line closes with it.
          child: SeamPadding(
            closing: last,
            padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.xxl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: tokens.railGutter),
                Expanded(child: swipe),
              ],
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.headline.copyWith(color: tokens.titleColor),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          Text(
            excerpt.isEmpty ? l10n.entryUntranscribed : excerpt,
            maxLines: tokens.excerptLines,
            overflow: TextOverflow.ellipsis,
            style: AppType.body.copyWith(
              color: excerpt.isEmpty ? tokens.metaColor : tokens.excerptColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${formatTime(entry.createdAt, localeTag(context))} · '
            '${formatDurationCompact(entry.duration)}',
            style: AppType.digits(AppType.footnote).copyWith(color: tokens.metaColor),
          ),
        ],
      ),
    );
  }

  /// Where the node sits: the optical middle of the row's FIRST line, so it
  /// marks that line rather than floating beside the block. Derived from the
  /// style the row actually leads with - a title sits higher than an excerpt,
  /// because its line box is tighter.
  static double _firstLineCenter(TextStyle style) => style.fontSize! * (style.height ?? 1.2) / 2;
}

/// The ids that ARRIVED between two home builds: entries present now that the
/// previous build had not seen. A null [previous] is the first build - the
/// whole journal is old news, nothing arrives - so it marks nothing. An id
/// that left and returned (a failed delete restoring its row) is an arrival
/// again: the returning row is the failure's only signal, and its unfold
/// masks exactly the reinsertion jump.
Set<String> newEntryIds(Set<String>? previous, List<Entry> current) {
  if (previous == null) return const {};
  return {
    for (final entry in current)
      if (!previous.contains(entry.id)) entry.id,
  };
}

/// The calendar days that ARRIVED between two home builds, feeding the day
/// splitter's unfold the same way [newEntryIds] feeds the rows': the first
/// entry of a new day brings its splitter with it, and an unanimated splitter
/// would jump the list by its full height. A null [previous] marks nothing.
Set<DateTime> newEntryDays(Set<DateTime>? previous, Set<DateTime> current) {
  if (previous == null) return const {};
  return current.difference(previous);
}

/// The days that LEFT between two home builds - [newEntryDays]'s mirror,
/// feeding the splitter's fold-out: deleting a day's only record must fold
/// the day's title away with it, not snap it off. A null [previous] marks
/// nothing.
Set<DateTime> departedEntryDays(Set<DateTime>? previous, Set<DateTime> current) {
  if (previous == null) return const {};
  return previous.difference(current);
}

/// Where each departing day's ghost splitter renders while it folds away:
/// slot i holds the ghosts sitting ABOVE section i, newest first, and the
/// extra last slot those older than every live day - so a ghost closes in
/// the exact seam its section vacated. [sectionDays] is newest first, like
/// the home list; the result has sectionDays.length + 1 slots.
List<List<DateTime>> departingSplitterSlots({
  required List<DateTime> sectionDays,
  required Set<DateTime> departing,
}) {
  final slots = [for (var i = 0; i <= sectionDays.length; i++) <DateTime>[]];
  final ordered = departing.toList()..sort((a, b) => b.compareTo(a));
  for (final day in ordered) {
    var i = 0;
    while (i < sectionDays.length && sectionDays[i].isAfter(day)) {
      i++;
    }
    slots[i].add(day);
  }
  return slots;
}

/// Whether every id in [ids] is mid-exit, which layout treats as already
/// gone: a day whose ids all pass folds its title, a row whose successors all
/// pass is the day's last living record, and a section whose predecessors all
/// pass leads the list - each closing in step with the exits, not after the
/// emit lands. Vacuously true for no ids, which is what makes an untouched
/// first section lead.
bool allDying(Iterable<String> ids, Set<String> dying) => ids.every(dying.contains);

/// The rail: one hairline down the gutter with a filled node on it. It runs the
/// painter's whole height, so consecutive rows draw one unbroken line.
class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.railColor,
    required this.nodeColor,
    required this.railWidth,
    required this.nodeSize,
    required this.nodeCenter,
  });

  final Color railColor;
  final Color nodeColor;
  final double railWidth;
  final double nodeSize;
  final double nodeCenter;

  @override
  void paint(Canvas canvas, Size size) {
    // The node is the widest thing in the gutter, so IT is what sits flush with
    // the screen's content margin; the rail runs down its middle.
    final x = nodeSize / 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = railColor
        ..strokeWidth = railWidth,
    );
    canvas.drawCircle(Offset(x, nodeCenter), nodeSize / 2, Paint()..color = nodeColor);
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.railColor != railColor ||
      old.nodeColor != nodeColor ||
      old.railWidth != railWidth ||
      old.nodeSize != nodeSize ||
      old.nodeCenter != nodeCenter;
}
