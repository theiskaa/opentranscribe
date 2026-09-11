import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_control.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:transcriber/transcriber.dart';

String _qualityWord(AppLocalizations l10n, ModelQuality quality) => switch (quality) {
  ModelQuality.basic => l10n.modelQualityBasic,
  ModelQuality.good => l10n.modelQualityGood,
  ModelQuality.better => l10n.modelQualityBetter,
  ModelQuality.best => l10n.modelQualityBest,
  ModelQuality.top => l10n.modelQualityTop,
};

String _tierInfo(AppLocalizations l10n, ModelQuality quality) => switch (quality) {
  ModelQuality.basic => l10n.modelTierBasicInfo,
  ModelQuality.good => l10n.modelTierGoodInfo,
  ModelQuality.better => l10n.modelTierBetterInfo,
  ModelQuality.best => l10n.modelTierBestInfo,
  ModelQuality.top => l10n.modelTierTopInfo,
};

/// The title and body a failed download wears, by its reason.
(String, String) modelFailureWords(
  AppLocalizations l10n,
  ModelRowState row, {
  required String localeTag,
}) => switch (row.failure!) {
  ModelInstallReason.offline => (
    l10n.modelFailOfflineTitle,
    l10n.modelFailOfflineBody(row.option.displayName),
  ),
  ModelInstallReason.noSpace => (
    l10n.modelFailNoSpaceTitle,
    l10n.modelFailNoSpaceBody(formatBytes(row.option.bytes, localeTag)),
  ),
  ModelInstallReason.rejected || ModelInstallReason.cancelled => (
    l10n.modelFailRejectedTitle,
    l10n.modelFailRejectedBody(row.option.displayName),
  ),
  ModelInstallReason.loadFailed => (
    l10n.modelFailLoadTitle,
    l10n.modelFailLoadBody(row.option.displayName),
  ),
};

/// The models an engine offers, two cards a row: the name over its size and
/// what the tier is for, a quiet line carrying a failure or the too-large
/// note, and one [ModelControl] across the bottom. [accelerated] is the
/// engine's switch: on, a card's size counts the second file the switch adds.
class ModelCards extends StatelessWidget {
  const ModelCards({required this.rows, this.accelerated = false, super.key});

  final List<ModelRowState> rows;
  final bool accelerated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          // Measured, not free: a card's control hangs off a Spacer, which
          // needs a bounded height. Two cards then share the row's, so their
          // controls sit level, and an odd last one spans the width.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (j, row) in rows.skip(i).take(2).indexed) ...[
                  if (j > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ModelTile(
                      key: ValueKey(row.option.id),
                      row: row,
                      accelerated: accelerated,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.row, required this.accelerated, super.key});

  final ModelRowState row;
  final bool accelerated;

  /// Reserved on every card, held or not, so the cards' text lines up: the
  /// trash's touch target is taller than the name it sits beside.
  static const double _headerHeight = 32;

  int get _bytes => row.option.bytes + (accelerated ? row.option.accelerationBytes : 0);

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<ModelsCubit>();
    final id = row.option.id;
    final face = modelRowFace(row);
    final dimmed = face == ModelRowFace.heavy;
    final motion = context.motionNow;
    final duration = context.reduceMotion ? Duration.zero : motion.indicator;
    // The edge glides between cards rather than jumping, like the theme
    // cards' selection.
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: row.selected ? theme.accent : tokens.cardBorder),
      duration: duration,
      curve: motion.indicatorCurve,
      builder: (context, edge, child) => DecoratedBox(
        decoration: SuperellipseDecoration(
          borderRadius: tokens.cardRadius,
          color: tokens.cardBackground,
          border: BorderSide(color: edge ?? tokens.cardBorder),
        ),
        child: child,
      ),
      child: Padding(
        padding: tokens.rowPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.option.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.subhead.copyWith(
                        color: dimmed ? theme.textSecondary : theme.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (modelRowRemovable(row))
                    _RemoveButton(
                      modelName: row.option.displayName,
                      onTap: () => _confirmRemove(context),
                    ),
                ],
              ),
            ),
            Text(
              l10n.modelSizeAndQuality(
                formatBytes(_bytes, localeTag(context)),
                _qualityWord(l10n, row.option.quality),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.digits(AppType.footnote).copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _tierInfo(l10n, row.option.quality),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppType.footnote.copyWith(color: theme.textSecondary, height: 1.3),
            ),
            // A card with slack pushes its control down; one without still
            // keeps this much air over it.
            const Spacer(),
            const SizedBox(height: AppSpacing.sm),
            _QuietLine(row: row, face: face),
            const SizedBox(height: AppSpacing.xs),
            ModelControl(
              row: row,
              face: face,
              onTap: switch (face) {
                ModelRowFace.download || ModelRowFace.failed => () => _install(context),
                ModelRowFace.installed => () => _use(context),
                ModelRowFace.heavy => () => _explainHeavy(context),
                _ => null,
              },
              onCancel: () => cubit.cancelModelInstallById(id),
            ),
          ],
        ),
      ),
    );
  }

  /// A refused retry is a model a run holds; the busy words say to wait.
  Future<void> _install(BuildContext context) async {
    final installing = await context.read<ModelsCubit>().installModelById(row.option.id);
    if (installing || !context.mounted) return;
    await _explainBusy(context);
  }

  Future<void> _explainBusy(BuildContext context) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    await showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.internaldrive,
        title: l10n.modelBusyTitle,
        body: l10n.modelBusyBody(row.option.displayName),
      ),
    );
  }

  Future<void> _use(BuildContext context) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<ModelsCubit>();
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

  Future<void> _explainHeavy(BuildContext context) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context)!;
    await showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.internaldrive,
        title: l10n.modelTooHeavyTitle,
        body: l10n.modelTooHeavyBody(row.option.displayName),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<ModelsCubit>();
    final held = row.option.bytes + (row.accelerated ? row.option.accelerationBytes : 0);
    final size = formatBytes(held, localeTag(context));
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.trash,
        title: l10n.modelRemoveTitle(row.option.displayName),
        body: l10n.modelRemoveBody(size),
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
    if (removed || !stillThere || !context.mounted) return;
    await _explainBusy(context);
  }
}

/// The line over the control: the reason over a failed download, the note
/// over a model too large. Nothing to say is no line, and the control sits
/// on the card's bottom edge either way.
class _QuietLine extends StatelessWidget {
  const _QuietLine({required this.row, required this.face});

  final ModelRowState row;
  final ModelRowFace face;

  /// The failure line's box.
  static const double height = 24;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return switch (face) {
      ModelRowFace.failed => SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _FailureLine(row: row),
        ),
      ),
      // Two lines: it says why the card's control will not run, and no phone
      // fits it on one.
      ModelRowFace.heavy => Text(
        l10n.modelTooHeavyNote,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppType.footnote.copyWith(color: theme.textSecondary, height: 1.3),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// The card's quiet way to delete a model: a glyph at the top corner, where
/// a card's own affordance belongs, not a word in the control's row.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.modelName, required this.onTap});

  final String modelName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.modelRemoveButton(modelName),
      onTap: onTap,
      excludeSemantics: true,
      child: Touchable(
        onTap: onTap,
        haptic: true,
        pressedScale: theme.motion.pressIconScale,
        // The glyph is small; its target is not, and it reaches into the
        // card's own padding rather than pushing the name aside.
        child: SizedBox(
          width: 44,
          height: _ModelTile._headerHeight,
          child: Center(child: AppIcon(AppIcons.trash, size: 14, color: theme.textSecondary)),
        ),
      ),
    );
  }
}

/// The failed download's words, tappable for the fuller story.
class _FailureLine extends StatelessWidget {
  const _FailureLine({required this.row});

  final ModelRowState row;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final (title, _) = modelFailureWords(l10n, row, localeTag: localeTag(context));
    return Semantics(
      button: true,
      label: title,
      onTap: () => _story(context),
      excludeSemantics: true,
      child: Touchable(
        onTap: () => _story(context),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.footnote.copyWith(color: theme.textSecondary),
        ),
      ),
    );
  }

  Future<void> _story(BuildContext context) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context)!;
    final (title, body) = modelFailureWords(l10n, row, localeTag: localeTag(context));
    await showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(icon: AppIcons.icloud, title: title, body: body),
    );
  }
}
