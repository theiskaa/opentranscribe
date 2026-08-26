import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_failure_story.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// What the sheet resolved to: the recovery the user chose, executed AFTER the
/// sheet has closed so its work lands on the screen's rows, not under a modal.
sealed class _Reply {
  const _Reply();
}

final class _RetryInstall extends _Reply {
  const _RetryInstall();
}

final class _RetryRemove extends _Reply {
  const _RetryRemove();
}

final class _Evict extends _Reply {
  const _Evict(this.tag);

  final String tag;
}

/// Opens the failure explanation for [row] and runs the recovery the user
/// picks: retry the install, retry the removal, or (for the cap) remove a
/// chosen language and then retry the blocked install.
Future<void> showModelFailureSheet(
  BuildContext context, {
  required SettingsCubit cubit,
  required LanguageModelState row,
}) async {
  final reply = await showAppSheet<_Reply>(
    context,
    builder: (context) => _FailureContent(row: row, cubit: cubit),
  );
  // A refused write inside a recovery must not escape this fire-and-forget
  // flow as an unhandled error; the rows' failure stamps carry the story.
  try {
    switch (reply) {
      case null:
        break;
      case _RetryInstall():
        cubit.install(row.tag);
      case _RetryRemove():
        await cubit.remove(row.tag);
      case _Evict(tag: final tag):
        await cubit.evictAndInstall(tag, row.tag);
    }
  } catch (_) {}
}

/// The cap sheet's eviction offers: the tags snapshot from when the cap
/// fired, minus the blocked row itself, minus the current default (evicting
/// the language the user records in is the surprise the language sheet's own
/// trash rule refuses), and only those STILL holding a slot, so a slot freed
/// since cannot be "evicted" again into a false remove failure.
List<String> evictableLanguages(LanguageModelState row, SettingsState state) {
  final reservedNow = {
    for (final r in state.languages)
      if (r.reserved) r.tag,
  };
  return [
    for (final tag in row.failure?.reservedTags ?? const <String>[])
      if (tag != row.tag && tag != state.localeId && reservedNow.contains(tag)) tag,
  ];
}

class _FailureContent extends StatelessWidget {
  const _FailureContent({required this.row, required this.cubit});

  final LanguageModelState row;
  final SettingsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SettingsCubit, SettingsState>(
      bloc: cubit,
      builder: (context, state) {
        final kind = modelFailureCase(row, managed: state.managesModels);
        final (icon, title, body) = modelFailureStory(l10n, kind, localeDisplayName(row.tag));
        final evictable = kind == ModelFailureCase.cap
            ? evictableLanguages(row, state)
            : const <String>[];

        return SheetMessage(
          icon: icon,
          title: title,
          body: body,
          rows: [
            for (final (index, tag) in evictable.indexed) ...[
              if (index > 0)
                Padding(
                  padding: EdgeInsets.only(left: theme.settings.dividerInset),
                  child: Container(height: 1, color: theme.settings.dividerColor),
                ),
              _EvictRow(tag: tag, onTap: () => Navigator.of(context).pop(_Evict(tag))),
            ],
          ],
          action: switch (kind) {
            // Every offered slot-holder can stop qualifying while the failure
            // stands (freed, or become the default); the sheet must then
            // offer the retry itself, or the row wedges with no way out.
            ModelFailureCase.cap when evictable.isEmpty => AppButton(
              label: l10n.retry,
              onPressed: () => Navigator.of(context).pop(const _RetryInstall()),
            ),
            ModelFailureCase.stuck || ModelFailureCase.generic => AppButton(
              label: l10n.retry,
              onPressed: () => Navigator.of(context).pop(const _RetryInstall()),
            ),
            ModelFailureCase.removeFailed => AppButton(
              label: l10n.retry,
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.of(context).pop(const _RetryRemove()),
            ),
            _ => null,
          },
        );
      },
    );
  }
}

/// One language holding a slot: its flag, its name, and the trash mark that
/// says what a tap does. Tapping evicts it and retries the blocked install.
class _EvictRow extends StatelessWidget {
  const _EvictRow({required this.tag, required this.onTap});

  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    return Touchable(
      onTap: onTap,
      haptic: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: tokens.iconTileSize,
              height: tokens.iconTileSize,
              alignment: Alignment.center,
              decoration: SuperellipseDecoration(
                borderRadius: tokens.iconTileRadius,
                color: tokens.iconTileBackground,
              ),
              child: LocaleFlag(localeFlag(tag), size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                localeDisplayName(tag),
                overflow: TextOverflow.ellipsis,
                style: AppType.subhead.copyWith(color: theme.text),
              ),
            ),
            AppIcon(AppIcons.trash, size: 18, color: theme.danger),
          ],
        ),
      ),
    );
  }
}
