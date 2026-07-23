import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// One journal entry in the list: when it was recorded, a text preview (or an
/// untranscribed hint), and its length.
class EntryTile extends StatelessWidget {
  const EntryTile({required this.entry, required this.onTap, this.busy = false, super.key});

  final Entry entry;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final preview = entry.transcript?.fullText.trim() ?? '';
    final hasText = preview.isNotEmpty;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_formatDate(entry.createdAt), style: AppText.caption(context)),
                ),
                if (busy)
                  const CupertinoActivityIndicator(radius: 7)
                else
                  Text(_formatDuration(entry.duration), style: AppText.caption(context)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasText ? preview : l10n.entryUntranscribed,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: hasText
                  ? AppText.body(context)
                  : AppText.body(context).copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime utc) => DateFormat.MMMd().add_jm().format(utc.toLocal());

String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
