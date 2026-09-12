import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_card.dart';
import 'package:opentranscribe/view/layouts/settings/components/strip_chip.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

/// The models that earn a chip under the model card: not the one in use (the
/// card carries it), here or on its way, and never one wearing a failure,
/// whose retry and story live in the sheet.
List<ModelRowState> chipModels(List<ModelRowState> rows) => [
  for (final row in rows)
    if (!row.selected && (row.installed || row.installing) && row.failure == null) row,
];

/// Whether the screen says downloads need the app open for the chips: while
/// a chip's model downloads and the card's bar is not already saying it for
/// the model in use (its preparation says something else).
bool chipsNeedDownloadNote(List<ModelRowState> rows, {required bool accelerated}) {
  final selected = rows.where((row) => row.selected).firstOrNull;
  final cardSaysIt =
      selected != null &&
      selected.installing &&
      !modelWaitIsPreparing(selected, accelerated: accelerated);
  return !cardSaysIt && chipModels(rows).any((row) => row.installing);
}

/// The other downloaded models as a chip strip, like the languages': a tap
/// makes that model the one in use, a downloading chip carries its ring, and
/// the trailing chip opens the model sheet. An empty set is just that chip.
class ModelChipStrip extends StatelessWidget {
  const ModelChipStrip({required this.rows, required this.onPick, required this.onMore, super.key});

  final List<ModelRowState> rows;
  final ValueChanged<ModelRowState> onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final tag = localeTag(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final row in rows)
          StripChip(
            key: ValueKey(row.option.id),
            onTap: row.installing ? null : () => onPick(row),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.option.displayName,
                  style: AppType.footnote.copyWith(
                    color: row.installing ? theme.textSecondary : theme.text,
                  ),
                ),
                const SizedBox(width: StripChip.innerGap),
                Text(
                  formatBytes(row.option.bytes, tag),
                  style: AppType.digits(AppType.footnote).copyWith(color: theme.textSecondary),
                ),
                if (row.installing) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StripChipProgress(fraction: row.installFraction!, preparing: row.preparing),
                ],
              ],
            ),
          ),
        StripChipMore(label: l10n.transcriptionMoreModels, onTap: onMore),
      ],
    );
  }
}
