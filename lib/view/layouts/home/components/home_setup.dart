import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/engine_picker.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/model_card.dart';
import 'package:opentranscribe/view/widgets/model_failure_story.dart';
import 'package:opentranscribe/view/widgets/model_sheet.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/speaking_hero.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:transcriber/transcriber.dart';

/// The line closing the empty journal's setup.
enum HomeSetupLine {
  /// Recording works as set.
  record,

  /// The model the first entry needs is not here yet; a take fetches it.
  modelLands,

  /// The setup cannot write an entry as it stands.
  fixFirst,
}

/// What the empty journal's setup shows: the engine picker once it was
/// opened ([opened], by Change or by an earlier frame that needed it) or
/// while something waits or blocks, the model card's row while a model
/// choice's model is not usable yet (or once [opened]), and the closing line.
/// [choice] is [modelHalf]'s, so a mid-switch frame shows no model. Nothing
/// gates a recording: a waiting model installs on a take's first use, and a
/// blocked setup only says so.
({bool showsPicker, ModelRowState? modelCard, HomeSetupLine line}) homeSetupFace({
  required List<EngineRowState> engines,
  required SettingsState languages,
  required ModelsState models,
  required bool choice,
  required bool opened,
}) {
  final selected = choice ? models.selectedModel : null;
  // An installed model's other failures are its Neural Engine file's, and it
  // runs without one; only a file that would not open is the model's own.
  final wontOpen = selected?.failure == ModelInstallReason.loadFailed;
  final modelWaits = selected != null && (!selected.installed || wontOpen);
  // The card carries the failure and its retry, which should come before a
  // take that would meet it again.
  final modelBlocked =
      selected != null &&
      (wontOpen || (!selected.installed && (selected.failure != null || selected.heavy)));
  final row = languages.defaultLanguage;
  // Under one model for every language a row's troubles are the model's,
  // told by its card; only a language the model cannot hear blocks. Else a
  // managed engine fetches an unready language on the first take, and only
  // one without downloads is stuck on it.
  final languageBlocked =
      row != null &&
      (languages.offersModelChoice
          ? row.status == ModelAssetStatus.unsupported
          : rowHasFailureStory(row) || (!languages.managesModels && !row.isReady));
  final engineDown = engines.any((engine) => engine.isActive && !engine.available);
  final blocked = languageBlocked || engineDown || modelBlocked;
  return (
    showsPicker: opened || modelWaits || blocked,
    modelCard: opened || modelWaits ? selected : null,
    line: blocked
        ? HomeSetupLine.fixFirst
        : modelWaits
        ? HomeSetupLine.modelLands
        : HomeSetupLine.record,
  );
}

/// The empty journal's setup, made of the transcription screen's own pieces
/// so both say the same thing: the Speaking card, the engine that writes
/// with its Change link, the picker and the model card opening in place only
/// as far as [homeSetupFace] says, and the way to record.
class HomeSetup extends StatefulWidget {
  const HomeSetup({super.key});

  @override
  State<HomeSetup> createState() => _HomeSetupState();
}

class _HomeSetupState extends State<HomeSetup> {
  /// Latched once the picker shows, by Change or by a state that needed it:
  /// a pick that settles what opened it must not fold the control away
  /// under the finger while its ask is still in flight.
  bool _opened = false;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _reload);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// What the setup vouches for can change while the app is away (a system
  /// fetch landing, dictation removed in iOS Settings, a purge), and nothing
  /// says so; coming back re-reads it, as entering the transcription screen
  /// does there.
  void _reload() {
    unawaited(context.read<SettingsCubit>().load());
    unawaited(context.read<ModelsCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final engines = context.watch<EnginesCubit>().state.rows;
    final models = context.watch<ModelsCubit>().state;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final (:settled, :choice, :acceleration) = modelHalf(
          models,
          languagesEngineId: state.engineId,
        );
        final face = homeSetupFace(
          engines: engines,
          languages: state,
          models: models,
          choice: choice,
          opened: _opened,
        );
        // Kept for later frames only, so no rebuild is owed.
        _opened = face.showsPicker;
        final modelCard = face.modelCard;
        final line = switch (face.line) {
          HomeSetupLine.record => l10n.homeSetupRecord,
          HomeSetupLine.modelLands => l10n.homeSetupModelLands(modelCard?.option.displayName ?? ''),
          HomeSetupLine.fixFirst => l10n.homeSetupFixFirst,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Home's resting top already leaves the calendar its breath.
            SectionLabel(l10n.transcriptionSpeaking, top: AppSpacing.xs),
            Melt(
              child: SpeakingHero(
                state: state,
                selectedModel: choice ? models.selectedModel : null,
                engineName: heroEngineName(engines, state, settled: settled),
                onTap: () => openSpeakingHero(context, state),
              ),
            ),
            Melt(
              child: face.showsPicker
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.sm,
                        0,
                      ),
                      child: _ChangeEngine(onTap: () => setState(() => _opened = true)),
                    ),
            ),
            Melt(
              child: face.showsPicker
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: EnginePicker(rows: engines),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Melt(
              child: modelCard == null
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionLabel(l10n.transcriptionModel),
                        ModelCard(
                          row: modelCard,
                          acceleration: accelerationSwitch(context, models, shown: acceleration),
                          onOpen: () => openModelSheet(context),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xl, AppSpacing.sm, 0),
              child: AnimatedSwitcher(
                duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
                layoutBuilder: meltStack,
                child: Text(
                  line,
                  key: ValueKey(line),
                  style: AppType.note.copyWith(color: theme.textSecondary),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The one link that opens the picker while the defaults already work; the
/// Speaking card's ready line has named the engine.
class _ChangeEngine extends StatelessWidget {
  const _ChangeEngine({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        child: Touchable(
          onTap: onTap,
          haptic: true,
          child: Text(
            AppLocalizations.of(context)!.homeSetupChangeEngine,
            style: AppType.note.copyWith(color: theme.accent, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
