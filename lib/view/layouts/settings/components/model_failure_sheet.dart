import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
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

/// The failure cases the sheet words, folded from the row's failure kind and
/// the asset's pre-install status. One surface, one honest story per case.
enum _FailureCase { cap, unsupported, stuck, removeFailed, generic }

_FailureCase _caseOf(LanguageModelState row) {
  final failure = row.failure;
  if (failure != null) {
    return switch (failure.kind) {
      LanguageFailureKind.capReached => _FailureCase.cap,
      LanguageFailureKind.removeFailed => _FailureCase.removeFailed,
      LanguageFailureKind.installFailed => switch (failure.assetStatus) {
        ModelAssetStatus.unsupported => _FailureCase.unsupported,
        ModelAssetStatus.downloading => _FailureCase.stuck,
        _ => _FailureCase.generic,
      },
    };
  }
  if (row.status == ModelAssetStatus.unsupported) return _FailureCase.unsupported;
  return _FailureCase.stuck;
}

/// Whether [row] carries a story this sheet can tell: a standing failure, an
/// unsupported language, or a system download stuck from an earlier attempt.
bool rowHasFailureStory(LanguageModelState row) =>
    row.failure != null ||
    row.status == ModelAssetStatus.unsupported ||
    (row.status == ModelAssetStatus.downloading && !row.installing);

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
    builder: (context) => _FailureContent(row: row),
  );
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
}

class _FailureContent extends StatelessWidget {
  const _FailureContent({required this.row});

  final LanguageModelState row;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final language = localeDisplayName(row.tag);
    final kind = _caseOf(row);

    final (icon, title, body) = switch (kind) {
      _FailureCase.cap => (AppIcons.globe, l10n.modelFailCapTitle, l10n.modelFailCapBody(language)),
      _FailureCase.unsupported => (
        AppIcons.globe,
        l10n.modelFailUnsupportedTitle,
        l10n.modelFailUnsupportedBody(language),
      ),
      _FailureCase.stuck => (
        AppIcons.icloud,
        l10n.modelFailStuckTitle,
        l10n.modelFailStuckBody(language),
      ),
      _FailureCase.removeFailed => (
        AppIcons.trash,
        l10n.modelFailRemoveTitle,
        l10n.modelFailRemoveBody(language),
      ),
      _FailureCase.generic => (
        AppIcons.icloud,
        l10n.modelFailGenericTitle,
        l10n.modelFailGenericBody(language),
      ),
    };

    // The cap case offers the languages holding the slots, minus this one.
    final evictable = kind == _FailureCase.cap
        ? [
            for (final tag in row.failure?.reservedTags ?? const <String>[])
              if (tag != row.tag) tag,
          ]
        : const <String>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: SuperellipseDecoration(
            borderRadius: AppRadius.chip,
            color: theme.settings.iconTileBackground,
          ),
          child: AppIcon(icon, size: 26, color: theme.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppType.title.copyWith(color: theme.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5),
        ),
        if (evictable.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          for (final (index, tag) in evictable.indexed) ...[
            if (index > 0)
              Padding(
                padding: EdgeInsets.only(left: theme.settings.dividerInset),
                child: Container(height: 1, color: theme.settings.dividerColor),
              ),
            _EvictRow(tag: tag, onTap: () => Navigator.of(context).pop(_Evict(tag))),
          ],
        ],
        if (kind == _FailureCase.stuck || kind == _FailureCase.generic) ...[
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: l10n.retry,
            onPressed: () => Navigator.of(context).pop(const _RetryInstall()),
          ),
        ],
        if (kind == _FailureCase.removeFailed) ...[
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: l10n.retry,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(const _RetryRemove()),
          ),
        ],
      ],
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
              child: Text(
                localeFlag(tag),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, height: 1),
                textScaler: TextScaler.noScaling,
              ),
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
