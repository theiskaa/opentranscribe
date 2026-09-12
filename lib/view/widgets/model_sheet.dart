import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/model_actions.dart';
import 'package:opentranscribe/view/widgets/model_card.dart';
import 'package:opentranscribe/view/widgets/model_control.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Every model the engine offers in one sheet, each with its tier, what it is
/// for, and its control. Removing lives here, beside a model's name. A pick
/// closes the sheet like the language sheet's; a download keeps it open so
/// its bar can be watched.
Future<void> showModelSheet(BuildContext context, {required ModelsCubit cubit}) {
  return showAppSheet<void>(
    context,
    // Full-width cards, like the language sheet's.
    inset: AppSpacing.md,
    builder: (context) => BlocProvider.value(value: cubit, child: const _ModelList()),
  );
}

/// [showModelSheet] from a tap, while the route is still on top.
void openModelSheet(BuildContext context) {
  if (!isTopRoute(context)) return;
  unawaited(showModelSheet(context, cubit: context.read<ModelsCubit>()));
}

class _ModelList extends StatelessWidget {
  const _ModelList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final button = context.theme.button;
    final controlWidth = modelControlWidth(
      l10n,
      bandHeight: button.bandHeight,
      floor: button.bandMinWidth,
      ceiling: math.min(
        button.bandMaxWidth,
        MediaQuery.sizeOf(context).width * button.bandMaxShare,
      ),
      textScaler: MediaQuery.textScalerOf(context),
    );
    return BlocBuilder<ModelsCubit, ModelsState>(
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(l10n.transcriptionAllModels),
          // A card per model: rows in one card inside the sheet read as a
          // card within a card.
          for (final (i, row) in state.models.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            SettingsCard(
              key: ValueKey(row.option.id),
              children: [_SheetRow(row: row, controlWidth: controlWidth)],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (state.models.any((row) => row.installing))
            SectionInfo(l10n.transcriptionDownloadFootnote),
          SectionInfo(l10n.modelSheetFootnote),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.row, required this.controlWidth});

  final ModelRowState row;

  /// [modelControlWidth], one for every row so the controls line up.
  final double controlWidth;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final face = modelRowFace(row);
    final dimmed = face == ModelRowFace.heavy;
    return Padding(
      padding: theme.settings.rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
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
                        const SizedBox(width: AppSpacing.sm),
                        QualityDots(quality: row.option.quality),
                      ],
                    ),
                    SizedBox(height: theme.settings.noteGap),
                    if (face == ModelRowFace.failed)
                      _FailureLine(row: row)
                    else
                      Text(
                        modelLine(l10n, row, localeTag: localeTag(context)),
                        // Two: "too large for this iPhone" fits no phone on one.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.digits(
                          AppType.footnote,
                        ).copyWith(color: theme.textSecondary),
                      ),
                  ],
                ),
              ),
              if (modelRowRemovable(row))
                _RemoveButton(
                  modelName: row.option.displayName,
                  onTap: () => confirmRemoveModel(context, row),
                ),
              SizedBox(
                width: controlWidth,
                child: ModelControl(
                  row: row,
                  face: face,
                  onTap: switch (face) {
                    ModelRowFace.download ||
                    ModelRowFace.failed => () => installModel(context, row),
                    ModelRowFace.installed => () => unawaited(_use(context)),
                    ModelRowFace.heavy => () => explainHeavyModel(context, row),
                    _ => null,
                  },
                  onCancel: () => context.read<ModelsCubit>().cancelModelInstallById(row.option.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Full width under the header, so the tier's words are not squeezed
          // beside the control.
          Text(
            modelTierInfo(l10n, row.option.quality),
            style: AppType.note.copyWith(color: theme.textSecondary),
          ),
        ],
      ),
    );
  }

  /// The route is read before the pick: the sheet's elements outlive its pop
  /// through the exit transition, so mounted alone does not say it is up.
  Future<void> _use(BuildContext context) async {
    final route = ModalRoute.of(context);
    if (!await useModel(context, row)) return;
    if (context.mounted && (route?.isCurrent ?? false)) Navigator.of(context).pop();
  }
}

/// The quiet way to delete a model: a glyph beside its control, a separate
/// affordance from the control itself.
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
        child: SizedBox(
          width: theme.settings.trailingTargetWidth,
          height: theme.button.bandHeight,
          child: Center(
            child: AppIcon(
              AppIcons.trash,
              size: ModelControl.glyphSize,
              color: theme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A failed download's title in the row's line, tappable for the fuller story.
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
    if (!isTopRoute(context)) return;
    final l10n = AppLocalizations.of(context)!;
    final (title, body) = modelFailureWords(l10n, row, localeTag: localeTag(context));
    await showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(icon: AppIcons.icloud, title: title, body: body),
    );
  }
}
