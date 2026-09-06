import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:transcriber/transcriber.dart';

/// What a row's trailing control and tap mean, folded in priority: a download
/// in flight, then a failure, then too heavy while absent, then present or not.
enum ModelRowFace { installing, failed, heavy, download, selected, installed }

ModelRowFace modelRowFace(ModelRowState row) {
  if (row.installing) return ModelRowFace.installing;
  if (row.failure != null) return ModelRowFace.failed;
  if (!row.installed) return row.heavy ? ModelRowFace.heavy : ModelRowFace.download;
  return row.selected ? ModelRowFace.selected : ModelRowFace.installed;
}

/// The quality word a picker shows for a tier.
String modelQualityWord(AppLocalizations l10n, ModelQuality quality) => switch (quality) {
  ModelQuality.basic => l10n.modelQualityBasic,
  ModelQuality.good => l10n.modelQualityGood,
  ModelQuality.better => l10n.modelQualityBetter,
  ModelQuality.best => l10n.modelQualityBest,
  ModelQuality.top => l10n.modelQualityTop,
};

/// The models an engine offers, one row each: name, size and quality, the
/// selected one marked, a download or its percent, and a trash on a present
/// model that is not the choice.
class ModelCard extends StatelessWidget {
  const ModelCard({required this.rows, super.key});

  final List<ModelRowState> rows;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [for (final row in rows) _ModelRow(key: ValueKey(row.option.id), row: row)],
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.row, super.key});

  final ModelRowState row;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;
    final face = modelRowFace(row);
    final dimmed = face == ModelRowFace.heavy;
    return Touchable(
      onTap: () => _tap(context, face),
      haptic: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Opacity(
              opacity: dimmed ? 0.45 : 1,
              child: Container(
                width: tokens.iconTileSize,
                height: tokens.iconTileSize,
                alignment: Alignment.center,
                decoration: SuperellipseDecoration(
                  borderRadius: tokens.iconTileRadius,
                  color: row.selected
                      ? theme.accent.withValues(alpha: 0.14)
                      : tokens.iconTileBackground,
                ),
                child: AppIcon(
                  AppIcons.internaldrive,
                  size: 16,
                  color: row.selected ? theme.accent : theme.text,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.option.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead.copyWith(
                      color: dimmed
                          ? theme.textSecondary
                          : (row.selected ? theme.accent : theme.text),
                      fontWeight: row.selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _note(context, l10n, face),
                    style: AppType.footnote.copyWith(color: theme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _trailing(context, face),
          ],
        ),
      ),
    );
  }

  String _size(BuildContext context) => formatBytes(row.option.bytes, localeTag(context));

  String _note(BuildContext context, AppLocalizations l10n, ModelRowFace face) => switch (face) {
    ModelRowFace.heavy => l10n.modelTooHeavyNote,
    ModelRowFace.failed => _failureStory(context, l10n).$1,
    _ => l10n.modelSizeAndQuality(_size(context), modelQualityWord(l10n, row.option.quality)),
  };

  Widget _trailing(BuildContext context, ModelRowFace face) {
    final theme = context.theme;
    return switch (face) {
      ModelRowFace.installing when row.installFraction! <= 0 => AppSpinner(color: theme.text),
      ModelRowFace.installing => ProgressRing(fraction: row.installFraction!, size: 20),
      ModelRowFace.failed => AppIcon(AppIcons.arrowCounterclockwise, size: 17, color: theme.accent),
      ModelRowFace.heavy => const SizedBox.shrink(),
      ModelRowFace.download => AppIcon(AppIcons.icloud, size: 18, color: theme.accent),
      ModelRowFace.selected => AppIcon(
        AppIcons.checkmark,
        size: 15,
        color: theme.settings.toggleActive,
      ),
      ModelRowFace.installed => Touchable(
        onTap: () => _confirmRemove(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: AppIcon(AppIcons.trash, size: 16, color: theme.textSecondary),
        ),
      ),
    };
  }

  Future<void> _tap(BuildContext context, ModelRowFace face) async {
    // One sheet at a time, like the rows around it.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<SettingsCubit>();
    switch (face) {
      case ModelRowFace.installing:
      case ModelRowFace.selected:
        return;
      case ModelRowFace.download:
        cubit.installModel(row.option.id);
      case ModelRowFace.heavy:
        await showAppSheet<void>(
          context,
          builder: (context) => SheetMessage(
            icon: AppIcons.internaldrive,
            title: l10n.modelTooHeavyTitle,
            body: l10n.modelTooHeavyBody(row.option.displayName),
          ),
        );
      case ModelRowFace.failed:
        final (title, body) = _failureStory(context, l10n);
        final retry = await showAppSheet<bool>(
          context,
          builder: (context) => SheetMessage(
            icon: AppIcons.icloud,
            title: title,
            body: body,
            action: AppButton(label: l10n.retry, onPressed: () => Navigator.of(context).pop(true)),
          ),
        );
        if (retry ?? false) cubit.installModel(row.option.id);
      case ModelRowFace.installed:
        try {
          await cubit.selectModel(row.option.id);
        } catch (_) {
          // The pick took for the session; only the stored choice is lost.
          if (!context.mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
          await showAppSheet<void>(
            context,
            builder: (context) => SheetMessage(
              icon: AppIcons.internaldrive,
              title: l10n.engineNotSavedTitle,
              body: l10n.modelNotSavedBody,
            ),
          );
        }
    }
  }

  (String, String) _failureStory(BuildContext context, AppLocalizations l10n) =>
      switch (row.failure!) {
        ModelInstallReason.offline => (
          l10n.modelFailOfflineTitle,
          l10n.modelFailOfflineBody(row.option.displayName),
        ),
        ModelInstallReason.noSpace => (
          l10n.modelFailNoSpaceTitle,
          l10n.modelFailNoSpaceBody(_size(context)),
        ),
        ModelInstallReason.rejected || ModelInstallReason.cancelled => (
          l10n.modelFailRejectedTitle,
          l10n.modelFailRejectedBody(row.option.displayName),
        ),
      };

  Future<void> _confirmRemove(BuildContext context) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<SettingsCubit>();
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.trash,
        title: l10n.modelRemoveTitle(row.option.displayName),
        body: l10n.modelRemoveBody(_size(context)),
        action: AppButton(
          label: l10n.modelRemoveConfirm,
          variant: AppButtonVariant.danger,
          onPressed: () {
            Haptics.medium();
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );
    if (!(confirmed ?? false)) return;
    final removed = await cubit.removeModel(row.option.id);
    // A refusal shows only while the file is really still there: a model that
    // vanished underneath reads as removed once the reload lands.
    final stillThere = cubit.state.models.any((r) => r.option.id == row.option.id && r.installed);
    if (removed || !stillThere) return;
    if (!context.mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    await showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.internaldrive,
        title: l10n.modelBusyTitle,
        body: l10n.modelBusyBody(row.option.displayName),
      ),
    );
  }
}
