import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/retranscribe_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/language_chips.dart';
import 'package:opentranscribe/view/layouts/settings/components/engine_picker.dart';
import 'package:opentranscribe/view/layouts/settings/components/language_sheet.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_actions.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_card.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_chips.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_failure_sheet.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_failure_story.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_sheet.dart';
import 'package:opentranscribe/view/layouts/settings/components/retranscribe_sheet.dart';
import 'package:opentranscribe/view/layouts/settings/components/speaking_hero.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/glass_icon_button.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:transcriber/transcriber.dart';

/// What the screen shows of the model half. The two cubits reload apart
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

/// The transcription screen as an answer to one question, what happens when I
/// hit record: the engine picker on top, the default language as a hero card
/// over the other kept languages as chips (a chip tap makes it the default),
/// then under a model choice the model in use as a card over the other
/// downloaded models as chips, and the footnotes. The language library lives
/// in the sheet the hero and the Add chip open, the models in the one the
/// model card and its More chip open.
class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  @override
  void initState() {
    super.initState();
    // Model state can change while this screen is away (a first-use install
    // during transcription, a system purge); entering re-reads it. The rows
    // this screen makes claims about (reserved ones) then get the exact
    // per-language probe, which is what catches a stuck system download or a
    // model the system quietly removed. Bounded by the reservation cap; a
    // non-managed engine's whole-list refinement rides load() itself.
    final cubit = context.read<SettingsCubit>();
    unawaited(context.read<ModelsCubit>().load());
    unawaited(
      cubit.load().then((_) {
        // Only where a reservation concept exists (max > 0): platforms without
        // one mark every row reserved, and probing ~40 rows there buys nothing.
        final refineReserved = cubit.state.reservationMax > 0;
        for (final row in cubit.state.languages) {
          if ((refineReserved && row.reserved) || row.status == ModelAssetStatus.downloading) {
            unawaited(cubit.refreshLanguage(row.tag));
          }
        }
      }),
    );
  }

  /// Whether the screen is still the top route: two pointers landing on two
  /// sheet-opening surfaces in one frame would otherwise stack two sheets.
  bool _onTop(BuildContext context) => ModalRoute.of(context)?.isCurrent ?? true;

  /// The switch takes for the session either way; only a refused persist is
  /// worth a word.
  Future<void> _setAccelerated(BuildContext context, bool on) async {
    final cubit = context.read<ModelsCubit>();
    try {
      await cubit.setAccelerated(on);
    } catch (_) {
      if (!context.mounted || !_onTop(context)) return;
      final l10n = AppLocalizations.of(context)!;
      await showAppSheet<void>(
        context,
        builder: (context) => SheetMessage(
          icon: AppIcons.internaldrive,
          title: l10n.engineNotSavedTitle,
          body: l10n.accelerationNotSavedBody,
        ),
      );
    }
  }

  void _openModelSheet(BuildContext context) {
    if (!_onTop(context)) return;
    unawaited(showModelSheet(context, cubit: context.read<ModelsCubit>()));
  }

  void _openLanguageSheet(BuildContext context) {
    if (!_onTop(context)) return;
    unawaited(showLanguageSheet(context, cubit: context.read<SettingsCubit>()));
  }

  /// The hero keeps its one promise: when the default is broken its tap tells
  /// that story (with the recovery), otherwise it opens the library. The Add
  /// chip, wherever the strip shows, stays a library door either way.
  void _openHero(BuildContext context, SettingsState state) {
    if (!_onTop(context)) return;
    final cubit = context.read<SettingsCubit>();
    final row = state.defaultLanguage;
    if (row != null && rowHasFailureStory(row)) {
      unawaited(showModelFailureSheet(context, cubit: cubit, row: row));
      return;
    }
    unawaited(showLanguageSheet(context, cubit: cubit));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final engineRows = context.watch<EnginesCubit>().state.rows;
    final models = context.watch<ModelsCubit>().state;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      actions: [_RetranscribeAction(color: theme.topBar.iconColor)],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          // Managing (install affordances, the slot count) exists only where
          // a real reservation concept does; max 0 also covers the
          // could-not-answer degrade, where offering actions would be lying.
          final canManage = state.reservationMax > 0;
          final (:settled, :choice, :acceleration) = modelHalf(
            models,
            languagesEngineId: state.engineId,
          );
          // Reservations, not ready models: a language mid-download (or one
          // whose download failed after reserving) holds a slot too.
          final reserved = state.languages.where((row) => row.reserved).length;
          final chips = chipLanguages(state.languages, oneModelForAll: state.offersModelChoice);
          final defaultRow = state.defaultLanguage;
          final strip = languageStripShown(
            oneModelForAll: state.offersModelChoice,
            heroBroken: defaultRow != null && rowHasFailureStory(defaultRow),
          );
          final selectedModel = models.selectedModel;
          final modelChips = chipModels(models.models);
          return SettingsList(
            children: [
              // Breath under the bar before the control; sm reads cramped
              // against the frosted edge.
              const SizedBox(height: 10),
              _Melt(child: EnginePicker(rows: engineRows)),
              SectionLabel(l10n.transcriptionSpeaking),
              _Melt(
                child: SpeakingHero(
                  state: state,
                  selectedModel: choice ? selectedModel : null,
                  // By the state's own engine id, not the active row: mid-switch
                  // the readiness still describes the previous engine. Unnamed
                  // until the model half agrees, so no ready line lands early.
                  engineName: settled
                      ? engineRows
                            .where((row) => row.descriptor.engineId == state.engineId)
                            .firstOrNull
                            ?.descriptor
                            .displayName
                      : null,
                  onTap: () => _openHero(context, state),
                ),
              ),
              // The label only when something IS also ready; the Add chip
              // stays wherever the strip does, as the library door a broken
              // default's hero (routing to its story) cannot be.
              _Melt(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (strip) ...[
                      // Crossfaded, not just resized: AnimatedSize settles the
                      // child at final geometry immediately, so without the
                      // fade the label would pop in over the melting gap.
                      AnimatedSwitcher(
                        duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
                        layoutBuilder: meltStack,
                        child: chips.isNotEmpty
                            ? SectionLabel(l10n.transcriptionAlsoReady)
                            : const SizedBox(height: AppSpacing.xxl),
                      ),
                      LanguageChipStrip(
                        rows: chips,
                        // Same persist contract as the sheet's row tap: a
                        // refused write leaves the chip a chip, never an
                        // unhandled error.
                        onPick: (tag) async {
                          try {
                            await context.read<SettingsCubit>().setLocale(tag);
                          } catch (_) {}
                        },
                        onAdd: () => _openLanguageSheet(context),
                      ),
                    ],
                  ],
                ),
              ),
              _Melt(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (choice && selectedModel != null) ...[
                      SectionLabel(l10n.transcriptionModel),
                      ModelCard(
                        row: selectedModel,
                        acceleration: acceleration
                            ? (
                                on: models.accelerated,
                                footprint: accelerationFootprint(
                                  models.models,
                                  on: models.accelerated,
                                ),
                                onChanged: (on) => _setAccelerated(context, on),
                              )
                            : null,
                        onOpen: () => _openModelSheet(context),
                      ),
                      // The languages' rule: the label only over chips.
                      AnimatedSwitcher(
                        duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
                        layoutBuilder: meltStack,
                        child: modelChips.isNotEmpty
                            ? SectionLabel(l10n.transcriptionAlsoDownloaded)
                            : const SizedBox(height: AppSpacing.md),
                      ),
                      ModelChipStrip(
                        rows: modelChips,
                        onPick: (row) => unawaited(useModel(context, row)),
                        onMore: () => _openModelSheet(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _Melt(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.deviceLanguageUnsupported)
                      SectionInfo(
                        l10n.transcriptionDeviceLanguageFallback(localeDisplayName(state.localeId)),
                      ),
                    // Only on settled frames: mid-switch the count still describes
                    // the previous engine while the picker marks the new one.
                    if (canManage &&
                        engineRows.any(
                          (r) => r.isActive && r.descriptor.engineId == state.engineId,
                        ))
                      SectionInfo(l10n.transcriptionCap(reserved, state.reservationMax)),
                    if (choice &&
                        chipsNeedDownloadNote(models.models, accelerated: models.accelerated))
                      SectionInfo(l10n.transcriptionDownloadFootnote),
                    if (state.offersModelChoice)
                      SectionInfo(l10n.transcriptionModelFootnote)
                    else if (state.managesModels)
                      SectionInfo(l10n.transcriptionFootnote),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// An engine switch regrows half the screen at once (chips leave, slot lines
/// and footnotes land, statuses reword); each section rides its own resize
/// instead of snapping the whole page a frame. Instant under Reduce Motion.
class _Melt extends StatelessWidget {
  const _Melt({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    return AnimatedSize(
      duration: context.reduceMotion ? AppMotion.instant : motion.indicator,
      curve: motion.indicatorCurve,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// Re-transcribe the journal, in the bar where a screen's own action
/// belongs. A run in flight tints the glyph; its numbers live in the sheet.
class _RetranscribeAction extends StatelessWidget {
  const _RetranscribeAction({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final running = context.watch<RetranscribeCubit>().state.isRunning;
    return AppGlassIconButton(
      icon: AppIcons.arrowCounterclockwise,
      color: running ? context.theme.accent : color,
      semanticLabel: AppLocalizations.of(context)!.retranscribeAllTitle,
      onTap: () {
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        unawaited(showRetranscribeSheet(context));
      },
    );
  }
}
