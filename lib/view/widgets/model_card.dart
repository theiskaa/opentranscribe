import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/model_actions.dart';
import 'package:opentranscribe/view/widgets/model_control.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:transcriber/transcriber.dart';

/// What a surface shows of the model half. The two cubits reload apart
/// across an engine switch, so it shows only once the models describe the
/// engine the languages do ([languagesEngineId]).
({bool settled, bool choice, bool acceleration}) modelHalf(
  ModelsState models, {
  required String languagesEngineId,
}) {
  final settled = models.engineId == languagesEngineId;
  return (
    settled: settled,
    choice: settled && models.offersModelChoice,
    acceleration: settled && models.offersAcceleration,
  );
}

/// The Neural Engine switch as the model card wears it: its state, its line
/// ([accelerationFootprint]) and what a flip does.
typedef AccelerationSwitch = ({
  bool on,
  ({int bytes, bool uses}) footprint,
  ValueChanged<bool> onChanged,
});

/// [AccelerationSwitch] for [models], or null when [shown] is false (an
/// engine without one, or models describing another engine).
AccelerationSwitch? accelerationSwitch(
  BuildContext context,
  ModelsState models, {
  required bool shown,
}) => shown
    ? (
        on: models.accelerated,
        footprint: accelerationFootprint(models.models, on: models.accelerated),
        onChanged: (on) => setAcceleration(context, on),
      )
    : null;

String _qualityWord(AppLocalizations l10n, ModelQuality quality) => switch (quality) {
  ModelQuality.basic => l10n.modelQualityBasic,
  ModelQuality.good => l10n.modelQualityGood,
  ModelQuality.better => l10n.modelQualityBetter,
  ModelQuality.best => l10n.modelQualityBest,
  ModelQuality.top => l10n.modelQualityTop,
};

String modelTierInfo(AppLocalizations l10n, ModelQuality quality) => switch (quality) {
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

/// The quiet line under a model's name: why its download failed, that this
/// phone cannot hold it, that it is not here yet, or its size and tier. The
/// size is the model's own file; the Neural Engine's extra is the switch's
/// to say, so no number moves when the switch does.
String modelLine(AppLocalizations l10n, ModelRowState row, {required String localeTag}) {
  final size = formatBytes(row.option.bytes, localeTag);
  return switch (modelRowFace(row)) {
    ModelRowFace.failed => modelFailureWords(l10n, row, localeTag: localeTag).$1,
    ModelRowFace.heavy => l10n.modelTooHeavyNote,
    ModelRowFace.download => l10n.modelNotDownloaded(size),
    _ => l10n.modelSizeAndQuality(size, _qualityWord(l10n, row.option.quality)),
  };
}

/// Whether a running bar's wait is the Neural Engine's one-time preparation
/// rather than bytes that need the app open.
bool modelWaitIsPreparing(ModelRowState row, {required bool accelerated}) =>
    row.preparing && accelerated;

/// The words under a running bar: the preparation when that is the wait,
/// else that downloads need the app open.
String modelWaitNote(AppLocalizations l10n, ModelRowState row, {required bool accelerated}) =>
    modelWaitIsPreparing(row, accelerated: accelerated)
    ? l10n.modelPreparingNote
    : l10n.transcriptionDownloadFootnote;

/// What the Neural Engine switch's line says. On with every second file on
/// the phone, what they take (`uses`). Otherwise what it still adds: a file
/// for every model here or on its way that lacks one, or, with no model here
/// yet, the model in use's file. Never zero while a model can take one.
({int bytes, bool uses}) accelerationFootprint(List<ModelRowState> rows, {required bool on}) {
  int sum(bool Function(ModelRowState row) counts) =>
      rows.where(counts).fold(0, (total, row) => total + row.option.accelerationBytes);
  // Off, a row still marked accelerated is one the reload has not caught up
  // with: turning off removes every file, so it counts as missing.
  final missing = sum((row) => (row.installed || row.installing) && !(on && row.accelerated));
  final landed = sum((row) => row.accelerated);
  if (on && missing == 0 && landed > 0) return (bytes: landed, uses: true);
  if (missing > 0) return (bytes: missing, uses: false);
  final selected = rows.where((row) => row.selected).firstOrNull;
  return (bytes: selected?.option.accelerationBytes ?? 0, uses: false);
}

/// A model's tier as five dots filled from Basic to Top. Only a look: the
/// tier's words under the name are what VoiceOver reads.
class QualityDots extends StatelessWidget {
  const QualityDots({required this.quality, super.key});

  final ModelQuality quality;

  static const double _dot = 5;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final level in ModelQuality.values) ...[
            if (level.index > 0) const SizedBox(width: _gap),
            Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: level.index <= quality.index ? theme.text : theme.settings.cardBorder,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The model in use as a card like the language one above it: name and tier
/// over its line and what the tier is for, then the one thing it waits on
/// (its download, a retry, the running bar, a smaller model), and the Neural
/// Engine switch where the engine has one. The card taps into the model
/// sheet.
class ModelCard extends StatelessWidget {
  const ModelCard({required this.row, required this.acceleration, required this.onOpen, super.key});

  final ModelRowState row;

  /// The Neural Engine switch and its line ([accelerationFootprint]), or null
  /// under an engine without one.
  final AccelerationSwitch? acceleration;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final tag = localeTag(context);
    final line = modelLine(l10n, row, localeTag: tag);
    final switcher = acceleration;
    return SettingsCard(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Touchable(
              onTap: onOpen,
              haptic: true,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      // A pick swaps the whole face; the old one melts into
                      // the new like the language card's.
                      child: AnimatedSwitcher(
                        duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
                        layoutBuilder: meltStack,
                        child: _Face(key: ValueKey((row.option.id, line)), row: row, line: line),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      // Level with the name's cap height, not the card's edge.
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: AppIcon(
                        AppIcons.chevronForward,
                        size: theme.settings.heroChevronSize,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _Waiting(row: row, accelerated: switcher?.on ?? false, onOpen: onOpen),
          ],
        ),
        if (switcher != null)
          SettingsToggleRow(
            icon: AppIcons.sparkles,
            label: l10n.transcriptionAcceleration,
            note: switcher.footprint.uses
                ? l10n.transcriptionAccelerationUses(formatBytes(switcher.footprint.bytes, tag))
                : l10n.transcriptionAccelerationSize(formatBytes(switcher.footprint.bytes, tag)),
            value: switcher.on,
            onChanged: switcher.onChanged,
          ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.row, required this.line, super.key});

  final ModelRowState row;
  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                row.option.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.headline.copyWith(color: theme.text),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            QualityDots(quality: row.option.quality),
          ],
        ),
        SizedBox(height: theme.settings.noteGap),
        Text(
          line,
          // Two: "too large for this iPhone" fits no phone on one.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.digits(AppType.footnote).copyWith(color: theme.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          modelTierInfo(l10n, row.option.quality),
          style: AppType.note.copyWith(color: theme.textSecondary),
        ),
      ],
    );
  }
}

/// What the card waits on, under its face: the download button, the failure
/// with its retry, the running bar with why it is slow, or, for a model this
/// phone cannot hold, the way to a smaller one. Nothing for a model that is
/// here and working, and the card closes up around it.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.row, required this.accelerated, required this.onOpen});

  final ModelRowState row;
  final bool accelerated;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final name = row.option.displayName;
    final face = modelRowFace(row);
    final note = AppType.note.copyWith(color: theme.textSecondary);
    final Widget? child = switch (face) {
      ModelRowFace.download => AppButton(
        label: l10n.modelDownloadSized(name, formatBytes(row.option.bytes, localeTag(context))),
        icon: AppIcons.icloud,
        onPressed: () => installModel(context, row),
      ),
      ModelRowFace.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(modelFailureWords(l10n, row, localeTag: localeTag(context)).$2, style: note),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.retry,
            icon: AppIcons.arrowCounterclockwise,
            onPressed: () => installModel(context, row),
          ),
        ],
      ),
      ModelRowFace.installing => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModelControl(
            row: row,
            face: face,
            onTap: null,
            onCancel: () => context.read<ModelsCubit>().cancelModelInstallById(row.option.id),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(modelWaitNote(l10n, row, accelerated: accelerated), style: note),
        ],
      ),
      ModelRowFace.heavy => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.modelTooHeavyBody(name), style: note),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.transcriptionMoreModels,
            variant: AppButtonVariant.secondary,
            onPressed: onOpen,
          ),
        ],
      ),
      ModelRowFace.selected || ModelRowFace.installed => null,
    };
    final motion = context.motionNow;
    return AnimatedSize(
      duration: context.reduceMotion ? Duration.zero : motion.indicator,
      curve: motion.indicatorCurve,
      alignment: Alignment.topCenter,
      child: child == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: child,
            ),
    );
  }
}
