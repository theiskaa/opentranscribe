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
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:transcriber/transcriber.dart';

/// What a card's action area means, folded in priority: a download in
/// flight, then a failure, then too heavy while absent, then present or not.
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

/// The two lines a card says about what a tier is good for.
String modelTierInfo(AppLocalizations l10n, ModelQuality quality) => switch (quality) {
  ModelQuality.basic => l10n.modelTierBasicInfo,
  ModelQuality.good => l10n.modelTierGoodInfo,
  ModelQuality.better => l10n.modelTierBetterInfo,
  ModelQuality.best => l10n.modelTierBestInfo,
  ModelQuality.top => l10n.modelTierTopInfo,
};

/// The models an engine offers, one card each: the name and size, two lines
/// on what the tier is for, and the action its state calls for: a download,
/// the download's own bar with a cancel, the mark of the one in use, or Use
/// and Remove on a present one.
class ModelCards extends StatelessWidget {
  const ModelCards({required this.rows, super.key});

  final List<ModelRowState> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _ModelTile(key: ValueKey(row.option.id), row: row),
        ],
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.row, super.key});

  final ModelRowState row;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;
    final face = modelRowFace(row);
    final dimmed = face == ModelRowFace.heavy;
    final motion = context.motionNow;
    final duration = context.reduceMotion ? Duration.zero : motion.indicator;
    // The ring glides between cards rather than jumping, like the theme
    // cards' selection.
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: row.selected ? theme.accent : tokens.cardBorder),
      duration: duration,
      curve: motion.indicatorCurve,
      builder: (context, ring, child) => DecoratedBox(
        decoration: SuperellipseDecoration(
          borderRadius: tokens.cardRadius,
          color: tokens.cardBackground,
          border: BorderSide(color: ring ?? tokens.cardBorder),
        ),
        child: child,
      ),
      child: Padding(
        padding: tokens.rowPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.option.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead.copyWith(
                      color: dimmed ? theme.textSecondary : theme.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.modelSizeAndQuality(
                    formatBytes(row.option.bytes, localeTag(context)),
                    modelQualityWord(l10n, row.option.quality),
                  ),
                  style: AppType.digits(AppType.footnote).copyWith(color: theme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              modelTierInfo(l10n, row.option.quality),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.footnote.copyWith(color: theme.textSecondary, height: 1.3),
            ),
            const SizedBox(height: AppSpacing.md),
            _ModelAction(row: row, face: face),
          ],
        ),
      ),
    );
  }
}

/// The card's bottom band: one control that stays in place and changes shape
/// as the model's state does, the App Store's own pattern. A Download pill
/// becomes the ring as bytes arrive, the ring becomes Use once the file is
/// whole, and Use becomes the In use mark on a pick; the pill morphs its
/// width and fill while the words inside fade. The band's other words (the
/// percent, Cancel, Remove, a failure) sit to its right.
class _ModelAction extends StatelessWidget {
  const _ModelAction({required this.row, required this.face});

  final ModelRowState row;
  final ModelRowFace face;

  /// The band's height, so a card never resizes when its face changes.
  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<SettingsCubit>();
    final id = row.option.id;
    if (face == ModelRowFace.heavy) {
      return SizedBox(
        height: _height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.modelTooHeavyNote,
            style: AppType.footnote.copyWith(color: theme.textSecondary),
          ),
        ),
      );
    }
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          _ControlPill(
            face: face,
            fraction: row.installFraction,
            onTap: switch (face) {
              ModelRowFace.download || ModelRowFace.failed => () => cubit.installModel(id),
              ModelRowFace.installed => () => _use(context),
              _ => null,
            },
          ),
          const SizedBox(width: AppSpacing.md),
          ...switch (face) {
            ModelRowFace.installing => [
              RollingText(
                text: '${((row.installFraction ?? 0).clamp(0.0, 1.0) * 100).round()}%',
                style: AppType.digits(AppType.footnote).copyWith(color: theme.textSecondary),
              ),
              const Spacer(),
              _TextAction(
                label: l10n.modelCancelDownload,
                onTap: () => cubit.cancelModelInstall(id),
              ),
            ],
            ModelRowFace.installed => [
              const Spacer(),
              _TextAction(label: l10n.modelRemove, onTap: () => _confirmRemove(context)),
            ],
            ModelRowFace.failed => [Expanded(child: _FailureLine(row: row))],
            _ => const <Widget>[],
          },
        ],
      ),
    );
  }

  Future<void> _use(BuildContext context) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<SettingsCubit>();
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

  Future<void> _confirmRemove(BuildContext context) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<SettingsCubit>();
    final size = formatBytes(row.option.bytes, localeTag(context));
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

/// The control itself: a pill whose width, fill, and words follow the face,
/// each on the indicator motion, so a state change is one shape moving
/// rather than one control replaced by another. The ring face is the pill at
/// its narrowest, holding only the ring.
class _ControlPill extends StatelessWidget {
  const _ControlPill({required this.face, required this.fraction, required this.onTap});

  final ModelRowFace face;
  final double? fraction;
  final VoidCallback? onTap;

  static const double _height = _ModelAction._height;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final button = theme.button;
    final l10n = AppLocalizations.of(context)!;
    final motion = context.motionNow;
    final duration = context.reduceMotion ? Duration.zero : motion.indicator;
    final fade = context.reduceMotion ? Duration.zero : theme.motion.crossfade;
    final (fill, border, ink) = switch (face) {
      ModelRowFace.installed => (button.background, button.background, button.foreground),
      // The toggle's own green: the one colour in the app that already means on.
      ModelRowFace.selected => (
        theme.settings.toggleActive.withValues(alpha: 0.14),
        theme.settings.toggleActive.withValues(alpha: 0.14),
        theme.settings.toggleActive,
      ),
      _ => (button.secondaryBackground, button.secondaryBorder, button.secondaryForeground),
    };
    final ring = face == ModelRowFace.installing;
    final content = switch (face) {
      ModelRowFace.installing => ProgressRing(fraction: fraction ?? 0, size: 18),
      ModelRowFace.download => _PillWords(
        icon: AppIcons.icloud,
        text: l10n.modelDownload,
        ink: ink,
      ),
      ModelRowFace.failed => _PillWords(
        icon: AppIcons.arrowCounterclockwise,
        text: l10n.retry,
        ink: ink,
      ),
      ModelRowFace.installed => _PillWords(text: l10n.modelUse, ink: ink),
      ModelRowFace.selected => _PillWords(
        icon: AppIcons.checkmark,
        text: l10n.modelInUse,
        ink: ink,
      ),
      ModelRowFace.heavy => const SizedBox.shrink(),
    };
    return Touchable(
      onTap: onTap,
      haptic: onTap != null,
      pressedScale: theme.motion.pressIconScale,
      child: AnimatedContainer(
        duration: duration,
        curve: motion.indicatorCurve,
        height: _height,
        padding: EdgeInsets.symmetric(horizontal: ring ? 7 : 14),
        decoration: SuperellipseDecoration(
          borderRadius: _height / 2,
          color: fill,
          border: BorderSide(color: border),
        ),
        child: AnimatedSize(
          duration: duration,
          curve: motion.indicatorCurve,
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: fade,
            layoutBuilder: meltStack,
            child: KeyedSubtree(
              key: ValueKey(face),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill's words: an optional glyph and the label, in the pill's ink.
class _PillWords extends StatelessWidget {
  const _PillWords({required this.text, required this.ink, this.icon});

  final String text;
  final Color ink;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[AppIcon(icon!, size: 13, color: ink), const SizedBox(width: 6)],
        Text(
          text,
          maxLines: 1,
          style: AppType.footnote.copyWith(color: ink, fontWeight: FontWeight.w600),
        ),
      ],
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
    final (title, _) = modelFailureWords(context, l10n, row);
    return Touchable(
      onTap: () => _story(context),
      child: Align(
        alignment: Alignment.centerLeft,
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
    final (title, body) = modelFailureWords(context, l10n, row);
    await showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(icon: AppIcons.icloud, title: title, body: body),
    );
  }
}

/// The title and body a failed download wears, by its reason.
(String, String) modelFailureWords(
  BuildContext context,
  AppLocalizations l10n,
  ModelRowState row,
) => switch (row.failure!) {
  ModelInstallReason.offline => (
    l10n.modelFailOfflineTitle,
    l10n.modelFailOfflineBody(row.option.displayName),
  ),
  ModelInstallReason.noSpace => (
    l10n.modelFailNoSpaceTitle,
    l10n.modelFailNoSpaceBody(formatBytes(row.option.bytes, localeTag(context))),
  ),
  ModelInstallReason.rejected || ModelInstallReason.cancelled => (
    l10n.modelFailRejectedTitle,
    l10n.modelFailRejectedBody(row.option.displayName),
  ),
};

/// A quiet text action at the card's edge: a word in the secondary ink,
/// with the row-sized touch target a bare label would lack.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Touchable(
      onTap: onTap,
      haptic: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Text(
          label,
          style: AppType.footnote.copyWith(color: theme.textSecondary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
