import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/model_actions.dart';
import 'package:opentranscribe/view/widgets/model_card.dart';
import 'package:opentranscribe/view/widgets/model_control.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Every model the engine offers: the ones here in a card on top, then All
/// models for the rest, each with its tier and what it is for. A row's tap
/// is its one promise: use a model that is here (closing the sheet), fetch
/// one that is not, retry one that failed. Its trailing mark says where it
/// stands, and the trash beside a kept model is a separate affordance.
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

/// Whether [row] sits in the top card, with the models here: only once it is
/// here. A download runs in its place among the rest and moves up when it
/// lands.
bool modelIsYours(ModelRowState row) => row.installed;

/// What stands at the end of a model's row.
enum ModelSheetMark {
  /// The download's ring with a stop in it: a tap cancels.
  stop,

  /// A wait with nothing to show or stop (the Neural Engine's preparation).
  spinner,

  /// The model in use.
  check,

  /// A kept model that can go.
  trash,

  /// A download that failed, and a tap tries again.
  retry,

  /// Not here yet, and a tap fetches it.
  download,

  /// Nothing: a model this phone cannot hold.
  none,
}

ModelSheetMark modelSheetMark(ModelRowState row) => switch (modelRowFace(row)) {
  ModelRowFace.installing =>
    row.cancellable && !row.preparing ? ModelSheetMark.stop : ModelSheetMark.spinner,
  ModelRowFace.selected => ModelSheetMark.check,
  ModelRowFace.installed => ModelSheetMark.trash,
  // One that downloaded but will not open goes by the trash; the tap retries.
  ModelRowFace.failed => modelRowRemovable(row) ? ModelSheetMark.trash : ModelSheetMark.retry,
  ModelRowFace.download => ModelSheetMark.download,
  ModelRowFace.heavy => ModelSheetMark.none,
};

/// A model row's second line: where its download stands while one runs,
/// else [modelLine].
String modelSheetLine(AppLocalizations l10n, ModelRowState row, {required String localeTag}) {
  if (!row.installing) return modelLine(l10n, row, localeTag: localeTag);
  if (row.queued) return l10n.modelQueued;
  if (row.preparing) return l10n.modelPreparing;
  return '${l10n.transcriptionDownloading} · ${percentOf(row.installFraction)}%';
}

class _ModelList extends StatelessWidget {
  const _ModelList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The rows lead with no tile, so the dividers start with their words.
    final inset = context.theme.settings.rowPadding.left;
    return BlocBuilder<ModelsCubit, ModelsState>(
      builder: (context, state) {
        final yours = [
          for (final row in state.models)
            if (modelIsYours(row)) row,
        ];
        final others = [
          for (final row in state.models)
            if (!modelIsYours(row)) row,
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The sheet's grabber already gives the top its breath.
            const SizedBox(height: AppSpacing.xs),
            // The gap between the cards rides the top one's bottom, so a model
            // moving between them grows it with the resize instead of jumping.
            Melt(
              child: yours.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: EdgeInsets.only(bottom: others.isEmpty ? 0 : AppSpacing.xxl),
                      child: _Card(rows: yours, inset: inset),
                    ),
            ),
            Melt(
              child: others.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionLabel(l10n.transcriptionAllModels, top: 0),
                        _Card(rows: others, inset: inset),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.models.any((row) => row.installing))
              SectionInfo(l10n.transcriptionDownloadFootnote),
            SectionInfo(l10n.modelSheetFootnote),
          ],
        );
      },
    );
  }
}

/// A card of model rows.
class _Card extends StatelessWidget {
  const _Card({required this.rows, required this.inset});

  final List<ModelRowState> rows;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      dividerInset: inset,
      children: [for (final row in rows) _SheetRow(key: ValueKey(row.option.id), row: row)],
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.row, super.key});

  final ModelRowState row;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final face = modelRowFace(row);
    final selected = face == ModelRowFace.selected;
    final heavy = face == ModelRowFace.heavy;
    final installing = face == ModelRowFace.installing;
    // The check says which model is in use only to the eye; the flag says it
    // to VoiceOver.
    return Semantics(
      button: !installing,
      selected: selected,
      child: Touchable(
        onTap: () => unawaited(_tap(context, face)),
        haptic: !installing,
        child: Padding(
          padding: theme.settings.rowPadding,
          child: Row(
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
                              color: heavy ? theme.dimmedText : theme.text,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        QualityDots(quality: row.option.quality),
                      ],
                    ),
                    SizedBox(height: theme.settings.noteGap),
                    _Line(row: row),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      modelTierInfo(l10n, row.option.quality),
                      style: AppType.note.copyWith(
                        color: heavy ? theme.dimmedText : theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _Mark(row: row),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tap(BuildContext context, ModelRowFace face) async {
    if (!isTopRoute(context)) return;
    switch (face) {
      case ModelRowFace.selected:
        Navigator.of(context).pop();
      case ModelRowFace.installed:
        // The route is read before the pick: the sheet's elements outlive its
        // pop through the exit transition, so mounted alone does not say it
        // is up.
        final route = ModalRoute.of(context);
        if (!await useModel(context, row)) return;
        if (context.mounted && (route?.isCurrent ?? false)) Navigator.of(context).pop();
      case ModelRowFace.download:
        await installModel(context, row);
      case ModelRowFace.failed:
        await _retry(context);
      case ModelRowFace.heavy:
        await explainHeavyModel(context, row);
      case ModelRowFace.installing:
        return;
    }
  }

  /// A failed download's story, with the retry as its action.
  Future<void> _retry(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final (title, body) = modelFailureWords(l10n, row, localeTag: localeTag(context));
    final again = await showAppSheet<bool>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.icloud,
        title: title,
        body: body,
        action: AppButton(label: l10n.retry, onPressed: () => Navigator.of(context).pop(true)),
      ),
    );
    if ((again ?? false) && context.mounted) await installModel(context, row);
  }
}

/// The line under a model's name ([modelSheetLine]). A new state rolls in
/// from below as the old one leaves; while bytes land only the percent
/// moves, digit by digit.
class _Line extends StatelessWidget {
  const _Line({required this.row});

  final ModelRowState row;

  /// Where a new line starts its roll in, in its own heights.
  static const Offset _enterFrom = Offset(0, 0.4);

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final motion = context.motionNow;
    final style = AppType.digits(AppType.footnote).copyWith(color: theme.textSecondary);
    final counting = row.installing && !row.queued && !row.preparing;
    final line = modelSheetLine(l10n, row, localeTag: localeTag(context));
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : motion.indicator,
      switchInCurve: motion.indicatorCurve,
      switchOutCurve: motion.indicatorCurve,
      layoutBuilder: meltStack,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: _enterFrom, end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: counting
          ? Row(
              key: const ValueKey('counting'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${l10n.transcriptionDownloading} · ', style: style),
                RollingText(
                  text: '${percentOf(row.installFraction)}%',
                  style: style,
                  // Quiet secondary text: every changed digit moves together.
                  stagger: Duration.zero,
                ),
              ],
            )
          : Text(
              line,
              key: ValueKey(line),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
    );
  }
}

/// The row's trailing mark ([modelSheetMark]) in one fixed column, so the
/// check, the trash, the download and the stop all stand on the same line.
/// A change of mark swaps like an SF Symbol's replace: the old one shrinks
/// away as the new one grows in, in place. The stop and the trash are their
/// own targets, apart from the row's tap.
class _Mark extends StatelessWidget {
  const _Mark({required this.row});

  final ModelRowState row;

  /// One size for every glyph, so none sits heavier in the column.
  static const double _glyph = 17;

  /// The download arrow's circle and the stop ring share one diameter, so a
  /// download reads as that circle filling.
  static const double _circle = 21;

  /// How small a mark shrinks to on its way out, and grows from on its way in.
  static const double _replaceScale = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final motion = context.motionNow;
    final name = row.option.displayName;
    final mark = modelSheetMark(row);
    final Widget glyph = switch (mark) {
      ModelSheetMark.stop => _StopRing(
        fraction: row.queued ? 0 : row.installFraction ?? 0,
        size: _circle,
      ),
      ModelSheetMark.spinner => AppSpinner(color: theme.text),
      ModelSheetMark.check => AppIcon(
        AppIcons.checkmark,
        size: _glyph,
        color: theme.settings.toggleActive,
      ),
      ModelSheetMark.trash => AppIcon(AppIcons.trash, size: _glyph, color: theme.textSecondary),
      ModelSheetMark.retry => AppIcon(
        AppIcons.arrowCounterclockwise,
        size: _glyph,
        color: theme.accent,
      ),
      ModelSheetMark.download => AppIcon(
        AppIcons.arrowDownCircle,
        size: _circle,
        color: theme.accent,
      ),
      ModelSheetMark.none => const SizedBox.shrink(),
    };
    // A picture of the row's state, which its words and flags already say.
    final seat = ExcludeSemantics(
      child: SizedBox.square(
        dimension: theme.settings.trailingTargetWidth,
        child: AnimatedSwitcher(
          duration: context.reduceMotion ? Duration.zero : motion.indicator,
          switchInCurve: motion.indicatorCurve,
          switchOutCurve: motion.indicatorCurve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: _replaceScale, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: Center(key: ValueKey(mark), child: glyph),
        ),
      ),
    );
    return switch (mark) {
      ModelSheetMark.stop => _Target(
        label: l10n.modelCancelDownloadButton(name),
        onTap: () => context.read<ModelsCubit>().cancelModelInstallById(row.option.id),
        child: seat,
      ),
      ModelSheetMark.trash => _Target(
        label: l10n.modelRemoveButton(name),
        onTap: () => unawaited(confirmRemoveModel(context, row)),
        child: seat,
      ),
      _ => seat,
    };
  }
}

/// A trailing mark with a target of its own: the whole seat takes the tap.
class _Target extends StatelessWidget {
  const _Target({required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Touchable(
        onTap: onTap,
        haptic: true,
        pressedScale: context.theme.motion.pressIconScale,
        child: child,
      ),
    );
  }
}

/// The App Store's download mark: the ring filling around a stop square.
class _StopRing extends StatelessWidget {
  const _StopRing({required this.fraction, required this.size});

  final double fraction;
  final double size;

  static const double _stroke = 2;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final stop = size / 3;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ProgressRing(fraction: fraction, size: size, strokeWidth: _stroke),
          Container(
            width: stop,
            height: stop,
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: BorderRadius.circular(stop / 4),
            ),
          ),
        ],
      ),
    );
  }
}
