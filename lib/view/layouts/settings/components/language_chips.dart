import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/strip_chip.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/model_failure_story.dart';

/// The rows that earn a chip: not the default (the hero carries it), ready or
/// mid-download, and never one wearing a failure story: a broken language (a
/// ready one with a refused remove included) must not sit one tap away from
/// becoming the default; its story lives in the sheet. Under an engine whose
/// one model serves every language nothing earns a chip: every language
/// would, and the sheet already offers them all.
List<LanguageModelState> chipLanguages(
  List<LanguageModelState> rows, {
  required bool oneModelForAll,
}) => [
  if (!oneModelForAll)
    for (final row in rows)
      if (!row.isDefault && (row.isReady || row.installing) && !rowHasFailureStory(row)) row,
];

/// Whether the chip strip shows at all. Under one model for every language
/// no language earns a chip and none needs adding, so a lone Add would only
/// repeat the hero, which opens the same sheet; it stays while a broken
/// default's hero tells its story instead of opening the library.
bool languageStripShown({required bool oneModelForAll, required bool heroBroken}) =>
    !oneModelForAll || heroBroken;

/// The kept languages minus the default, as a chip strip: tapping a chip makes
/// that language the default, a downloading chip carries its ring, and the
/// trailing Add chip opens the language sheet. The strip renders whatever
/// [rows] holds, so an empty set is just the Add chip.
class LanguageChipStrip extends StatelessWidget {
  const LanguageChipStrip({
    required this.rows,
    required this.onPick,
    required this.onAdd,
    super.key,
  });

  final List<LanguageModelState> rows;
  final ValueChanged<String> onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final row in rows)
          StripChip(
            key: ValueKey(row.tag),
            onTap: row.installing ? null : () => onPick(row.tag),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LocaleFlag(localeFlag(row.tag), size: 14),
                const SizedBox(width: StripChip.innerGap),
                Text(
                  localeDisplayName(row.tag),
                  // Dimmed while installing, like every disabled control: the
                  // dead press needs more than the ring to explain itself.
                  style: AppType.footnote.copyWith(
                    color: row.installing ? theme.textSecondary : theme.text,
                  ),
                ),
                if (row.installing) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StripChipProgress(fraction: row.installFraction!),
                ],
              ],
            ),
          ),
        StripChipMore(label: l10n.transcriptionAddLanguage, onTap: onAdd),
      ],
    );
  }
}
