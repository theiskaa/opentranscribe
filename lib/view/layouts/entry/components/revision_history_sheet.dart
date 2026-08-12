import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/word_diff.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/delete_swipe.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/seam_padding.dart';

/// Opens the entry's revision history, newest first, each revision carrying
/// its own change inline: what it did to the words before it, excerpted
/// around the change with the neighbouring lines fading out. Tapping a
/// revision returns it for restore (null when the sheet just closed); swiping
/// one deletes it from the history in place, the sheet tracking the live
/// entry. The restore fires AS the sheet leaves: the screen behind shows the
/// new head at once, while the departing sheet wears its frozen list.
Future<Revision?> showRevisionHistorySheet(BuildContext context, Entry entry) =>
    showAppSheet<Revision>(context, builder: (context) => _HistoryContent(entryId: entry.id));

/// The words for a revision's origin: who wrote it, an engine revision named
/// with its language so two runs in different tongues stay apart.
String _originLabel(Revision revision, AppLocalizations l10n) {
  if (revision.isHand) return l10n.editedMarker;
  final locale = revision.localeId;
  if (locale == null) return l10n.revisionTranscribed;
  return '${l10n.revisionTranscribed} \u00b7 ${localeDisplayName(locale)}';
}

/// No header: the tiles ARE the sheet, and the one explaining line above them
/// says what a tap does. Reads the LIVE entry off the cubit, so a swiped-away
/// revision leaves the list in place; the sheet excuses itself when the
/// history (or the entry) is gone.
class _HistoryContent extends StatefulWidget {
  const _HistoryContent({required this.entryId});

  final String entryId;

  @override
  State<_HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<_HistoryContent> {
  /// The one row allowed to sit swiped open, shared across the tiles.
  final ValueNotifier<String?> _openId = ValueNotifier<String?>(null);

  /// The tiles whose delete exits are playing, so the seam beside each can
  /// close in step with its collapsing slot instead of snapping after it. A
  /// set, because two fast swipes can have two exits in flight at once.
  final Set<String> _dying = {};

  /// Set once the pop below fires, so an emptied history cannot pop twice.
  bool _left = false;

  /// The list as last built while the sheet was the live route. A restore
  /// fires the moment the sheet pops, and the screen behind must show it at
  /// once; the sheet itself leaves wearing THIS snapshot, so its own list
  /// never reshuffles mid-flight.
  List<Revision>? _shown;

  @override
  void dispose() {
    _openId.dispose();
    super.dispose();
  }

  /// Stable ids for the DISPLAYED list, newest first. A repeated stamp+text
  /// (a fixed-clock or hand-built archive) gets an occurrence suffix, so two
  /// value-equal revisions can never collide as keys and crash the Column.
  List<String> _idsOf(List<Revision> displayed) {
    final seen = <String, int>{};
    return [
      for (final revision in displayed)
        () {
          final base = 'rev:${revision.at.microsecondsSinceEpoch}:${revision.text.hashCode}';
          final n = seen[base] = (seen[base] ?? 0) + 1;
          return n == 1 ? base : '$base:${n - 1}';
        }(),
    ];
  }

  Future<void> _delete(EntriesCubit cubit, Entry entry, Revision revision, String id) async {
    await cubit.deleteRevision(entry, revision);
    // A restore tap can freeze the departing sheet before this lands; the
    // frozen list must drop the row too, or its still-mounted DeleteSwipe
    // reads the survival as a refused removal and grows the deleted row
    // back mid-exit.
    final shown = _shown;
    final remaining = cubit.state.entries.where((e) => e.id == entry.id);
    final kept = remaining.isNotEmpty && (remaining.first.revisions?.contains(revision) ?? false);
    if (!kept && shown != null) {
      final index = shown.indexOf(revision);
      if (index >= 0) _shown = [...shown]..removeAt(index);
    }
    // Cleared only after the frame that removed the row, and only THIS id: a
    // second exit still in flight keeps its own seam closing.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() => _dying.remove(id));
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.watch<EntriesCubit>();
    final matches = cubit.state.entries.where((e) => e.id == widget.entryId);
    final entry = matches.isEmpty ? null : matches.first;
    final transcript = entry?.transcript;
    // A pristine entry still has a state worth showing: its original
    // transcription stands in as the lone current tile, inert until a first
    // change materializes the real stack. A SILENT transcript stands in as
    // nothing (the service's no-base rule), excusing the sheet below.
    final live =
        entry?.revisions ??
        [
          if (transcript != null && transcript.fullText.trim().isNotEmpty)
            Revision.ofTranscript(transcript),
        ];
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    final revisions = current ? live : (_shown ?? live);
    if (current) _shown = live;
    // Nothing left to show: the entry vanished with the sheet up. Excuse the
    // sheet rather than sitting on an empty list.
    if (entry == null || revisions.isEmpty) {
      _leave();
      return const SizedBox(width: double.infinity);
    }
    final displayed = revisions.reversed.toList();
    final ids = _idsOf(displayed);
    // A dying tile can leave the list by another delete's hand before its own
    // cleanup runs; a departed id must not haunt the seams for the sheet's
    // life.
    _dying.removeWhere((id) => !ids.contains(id));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.revisionHistoryBody,
          style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Every child is KEYED by its revision: a delete shifts every tile
        // below it one position up, and unkeyed elements would be torn down
        // and rebuilt fresh at their new indexes, flashing the survivors.
        for (final (i, revision) in displayed.indexed) ...[
          if (i > 0)
            // The seam between two tiles folds on the delete exit's own clock
            // when either side of it is leaving: the tile it precedes, or the
            // head above it whose departure makes this seam the top.
            _Seam(
              key: ValueKey('seam:${ids[i]}'),
              closing: _dying.contains(ids[i]) || (i == 1 && _dying.contains(ids[0])),
            ),
          if (displayed.length == 1 && !_dying.contains(ids[i]))
            // The last revision standing cannot be deleted, so the lone tile
            // offers no swipe; being the head, it has no restore tap either.
            // While its OWN exit is still in flight (both tiles swiped at
            // once) it stays a DeleteSwipe, so the refused removal reopens
            // the row instead of tearing it down mid-collapse.
            _RevisionTile(key: ValueKey(ids[i]), revision: revision, previous: null, current: true)
          else
            DeleteSwipe(
              key: ValueKey(ids[i]),
              id: ids[i],
              openId: _openId,
              // The head is the resting state, not a choice; every other tile
              // restores on tap, safe undialogued because a restore only
              // pushes.
              onTap: i == 0 ? () {} : () => Navigator.of(context).pop(revision),
              onDelete: () => _delete(cubit, entry, revision, ids[i]),
              onExitStart: () => setState(() => _dying.add(ids[i])),
              child: _RevisionTile(
                revision: revision,
                // Each revision narrates ITS change: the diff against the
                // words it replaced. The oldest replaced nothing, showing its
                // opening.
                previous: i + 1 < displayed.length ? displayed[i + 1] : null,
                current: i == 0,
              ),
            ),
        ],
      ],
    );
  }
}

/// The hairline between two tiles, folding on the delete exit's clock when a
/// neighbour is leaving so the list closes as one move, never a snap.
class _Seam extends StatelessWidget {
  const _Seam({required this.closing, super.key});

  final bool closing;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SeamPadding(
      closing: closing,
      padding: EdgeInsets.symmetric(vertical: closing ? 0 : AppSpacing.md),
      child: AnimatedOpacity(
        duration: context.reduceMotion
            ? Duration.zero
            : (closing ? theme.motion.swipeExit : theme.motion.expand),
        curve: closing ? AppMotion.swipeExitHeightCurve : Curves.easeOutCubic,
        opacity: closing ? 0 : 1,
        child: Container(height: 1, color: theme.hairline),
      ),
    );
  }
}

/// One revision: its origin, when it landed, and the change it made, inline.
class _RevisionTile extends StatelessWidget {
  const _RevisionTile({
    required this.revision,
    required this.previous,
    required this.current,
    super.key,
  });

  final Revision revision;
  final Revision? previous;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(_originLabel(revision, l10n), style: AppType.subhead.copyWith(color: theme.text)),
            if (current) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.revisionCurrent,
                style: AppType.footnote.copyWith(color: theme.textSecondary),
              ),
            ],
            const Spacer(),
            Text(
              '${shortDateLabel(revision.at.toLocal(), locale)}'
              ' \u00b7 ${formatTime(revision.at, locale)}',
              style: AppType.digits(AppType.footnote).copyWith(color: theme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // A neighbour's delete hands this tile a new predecessor, so its diff
        // re-renders at a new height in one frame; the size change eases here,
        // LOCALLY, while the panel just follows the content per frame. (A
        // sheet-level AnimatedSize double-animated the delete's own collapse.)
        AnimatedSize(
          duration: context.reduceMotion ? AppMotion.instant : theme.motion.expand,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _DiffExcerpt(spans: diffExcerpt(diffWords(previous?.text ?? '', revision.text))),
        ),
      ],
    );
  }
}

/// The change itself, excerpted. A short diff sits snug under its header; one
/// that overflows gets a three-line window with the edge lines dissolving
/// like the live transcript's, the change riding just past the leading
/// context so it lands mid-window.
class _DiffExcerpt extends StatelessWidget {
  const _DiffExcerpt({required this.spans});

  final List<DiffSpan> spans;

  static const int _maxLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    const style = AppType.footnote;
    final rich = TextSpan(
      children: [
        for (final span in spans)
          TextSpan(
            text: span.text,
            style: switch (span.kind) {
              DiffKind.equal => style.copyWith(color: theme.textSecondary),
              DiffKind.removed => style.copyWith(
                color: theme.diff.removed,
                backgroundColor: theme.diff.removedWash,
                decoration: TextDecoration.lineThrough,
                decorationColor: theme.diff.removed,
              ),
              DiffKind.added => style.copyWith(
                color: theme.diff.added,
                backgroundColor: theme.diff.addedWash,
              ),
            },
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measured, not assumed: only an overflowing excerpt earns the fixed
        // window and its fade; a one-line change stays one line tall.
        final painter = TextPainter(
          text: rich,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final lines = painter.computeLineMetrics().length;
        final lineHeight = painter.preferredLineHeight;
        painter.dispose();
        if (lines <= _maxLines) return Text.rich(rich);
        return SizedBox(
          height: lineHeight * _maxLines,
          child: ClipRect(
            child: ShaderMask(
              // dstIn: the gradient's alpha is what survives, so the window's
              // own first and last line melt instead of meeting a cut.
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x30000000),
                  Color(0xFF000000),
                  Color(0xFF000000),
                  Color(0x30000000),
                ],
                stops: [0, 0.32, 0.68, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Align(alignment: Alignment.topCenter, child: Text.rich(rich)),
            ),
          ),
        );
      },
    );
  }
}
