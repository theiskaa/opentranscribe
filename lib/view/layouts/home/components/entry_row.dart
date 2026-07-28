import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
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
    super.key,
  });

  final Entry entry;

  /// The day's last record. The rail runs the full height of every row, gap
  /// included, so a day's records are strung on ONE continuous line; the last
  /// row simply has no gap, and the rail ends with its text.
  final bool last;
  final VoidCallback onTap;

  /// The one row currently swiped open, shared across the list.
  final ValueNotifier<String?> openId;
  final Future<void> Function(Entry) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.entryList;
    final l10n = AppLocalizations.of(context)!;
    final excerpt = entry.transcript?.fullText.trim() ?? '';
    final title = entry.title;
    final leadStyle = title != null ? AppType.headline : AppType.body;

    return DeleteSwipe(
      id: entry.id,
      openId: openId,
      onTap: onTap,
      onDelete: () => onDelete(entry),
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
          child: Padding(
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
            '${formatTime(entry.createdAt)} · '
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
