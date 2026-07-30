import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// The week label for a reflection: "Jul 20 - 26", or "Jun 30 - Jul 6" across a
/// month. The dash is an en dash (a range), not an em dash. Pure, so it is
/// tested directly.
String weekRangeLabel(DateTime weekStart, String locale) {
  final end = weekStart.add(const Duration(days: 6));
  final start = DateFormat.MMMd(locale).format(weekStart);
  final endText = weekStart.month == end.month
      ? DateFormat.d(locale).format(end)
      : DateFormat.MMMd(locale).format(end);
  return '$start – $endText';
}

/// One week in the Reflections history: its range label and a trailing menu
/// (Regenerate / Delete), over the reflection text or the "a quiet week" marker.
/// A regenerating row shows the spinner in place of its body.
class ReflectionRow extends StatelessWidget {
  const ReflectionRow({
    required this.reflection,
    required this.regenerating,
    required this.onRegenerate,
    required this.onDelete,
    required this.locale,
    super.key,
  });

  final Reflection reflection;
  final bool regenerating;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return SettingsCard(
      children: [
        Padding(
          // Tighter on the right: the 36px ellipsis button carries its own
          // padding, so it seats flush without doubling the inset.
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      weekRangeLabel(reflection.weekStart, locale),
                      style: AppType.footnote.copyWith(color: theme.textSecondary),
                    ),
                  ),
                  AppMenuButton(
                    icon: AppIcons.ellipsis,
                    size: 36,
                    iconSize: 18,
                    color: theme.textSecondary,
                    items: [
                      AppMenuItem(
                        id: 'regen',
                        label: l10n.reflectionRegenerate,
                        icon: AppIcons.arrowCounterclockwise,
                      ),
                      AppMenuItem(
                        id: 'delete',
                        label: l10n.reflectionDelete,
                        icon: AppIcons.trash,
                        destructive: true,
                      ),
                    ],
                    onSelected: (_) {},
                    onSelectedId: (id) => id == 'regen' ? onRegenerate() : onDelete(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (regenerating)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: AppSpinner(size: 22, color: theme.textSecondary),
                )
              else if (reflection.isSilent)
                Text(
                  l10n.reflectionQuietWeek,
                  style: AppType.body.copyWith(color: theme.textSecondary),
                )
              else
                Text(
                  reflection.text!,
                  style: AppType.body.copyWith(color: theme.text, height: 1.4),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
