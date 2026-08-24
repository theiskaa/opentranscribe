import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

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
          _Chip(
            key: ValueKey(row.tag),
            onTap: row.installing ? null : () => onPick(row.tag),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LocaleFlag(localeFlag(row.tag), size: 14),
                const SizedBox(width: 6),
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
                  // Same rule as the sheet's trailing: no fraction yet means
                  // an indeterminate wait, and an empty ring reads as stalled.
                  if (row.installFraction! <= 0)
                    AppSpinner(size: 12, color: theme.textSecondary)
                  else
                    ProgressRing(fraction: row.installFraction!, size: 12),
                ],
              ],
            ),
          ),
        _Chip(
          onTap: onAdd,
          // A text plus, not a glyph: the vendored SF subset carries no plus,
          // and one character does not earn a font regeneration.
          child: Text(
            '+ ${l10n.transcriptionAddLanguage}',
            style: AppType.footnote.copyWith(color: theme.accent, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child, required this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return Touchable(
      onTap: onTap,
      haptic: onTap != null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 9),
        decoration: SuperellipseDecoration(
          borderRadius: AppRadius.chip,
          color: tokens.cardBackground,
        ),
        child: child,
      ),
    );
  }
}
