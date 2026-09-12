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
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/language_chips.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_chips.dart';
import 'package:opentranscribe/view/layouts/settings/components/retranscribe_sheet.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/engine_picker.dart';
import 'package:opentranscribe/view/widgets/glass_icon_button.dart';
import 'package:opentranscribe/view/widgets/language_sheet.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/model_actions.dart';
import 'package:opentranscribe/view/widgets/model_card.dart';
import 'package:opentranscribe/view/widgets/model_failure_story.dart';
import 'package:opentranscribe/view/widgets/model_sheet.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/speaking_hero.dart';
import 'package:transcriber/transcriber.dart';

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
              Melt(child: EnginePicker(rows: engineRows)),
              SectionLabel(l10n.transcriptionSpeaking),
              Melt(
                child: SpeakingHero(
                  state: state,
                  selectedModel: choice ? selectedModel : null,
                  engineName: heroEngineName(engineRows, state, settled: settled),
                  onTap: () => openSpeakingHero(context, state),
                ),
              ),
              // The label only when something IS also ready; the Add chip
              // stays wherever the strip does, as the library door a broken
              // default's hero (routing to its story) cannot be.
              Melt(
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
                        onAdd: () => openLanguageSheet(context),
                      ),
                    ],
                  ],
                ),
              ),
              Melt(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (choice && selectedModel != null) ...[
                      SectionLabel(l10n.transcriptionModel),
                      ModelCard(
                        row: selectedModel,
                        acceleration: accelerationSwitch(context, models, shown: acceleration),
                        onOpen: () => openModelSheet(context),
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
                        onMore: () => openModelSheet(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Melt(
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
        if (!isTopRoute(context)) return;
        unawaited(showRetranscribeSheet(context));
      },
    );
  }
}
