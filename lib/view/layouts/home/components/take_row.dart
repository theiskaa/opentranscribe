import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/home/components/entry_row.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';

/// The take's place in the list while it is being transcribed: a record's rail
/// and node with a cloud of ink where its words will be. The cloud is not a
/// stand-in that gets swapped out; when the record lands it resolves INTO the
/// row, so the wait and the arrival are one movement.
///
/// [entry] is null until the record lands. The row is not tappable either way:
/// while the cloud is up there is nothing to open, and a tap landing mid-write
/// on a row that is still assembling would open a screen the reader did not
/// aim at. The settled row takes over from [EntryRow] on [onWritten].
class TakeRow extends StatelessWidget {
  const TakeRow({required this.entry, required this.last, required this.onWritten, super.key});

  final Entry? entry;

  /// The day's last living record; see [EntryRow.last].
  final bool last;

  /// The words are written and the row renders plain: the list can take it
  /// back as an ordinary record.
  final VoidCallback onWritten;

  /// How tall the waiting cloud stands, in body lines: a short record's
  /// excerpt and the meta line under it, so the ink looks like what it becomes.
  static const int _placeholderLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final entry = this.entry;
    return EntryRail(
      last: last,
      leadStyle: entry == null ? AppType.body : EntryRowBody.leadStyleOf(entry),
      child: Semantics(
        // The cloud says nothing on its own; the settled row reads itself out.
        label: entry == null ? l10n.takeTranscribing : null,
        child: InkReveal(
          phase: entry == null ? InkPhase.pending : InkPhase.write,
          color: theme.entryList.excerptColor,
          background: theme.screens.home,
          placeholderLines: _placeholderLines,
          onWriteFinished: onWritten,
          child: entry == null
              ? const SizedBox(width: double.infinity)
              : EntryRowBody(entry: entry),
        ),
      ),
    );
  }
}
