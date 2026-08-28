import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/retranscribe_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/language_chips.dart';
import 'package:opentranscribe/view/layouts/settings/components/language_sheet.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_failure_sheet.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_failure_story.dart';
import 'package:opentranscribe/view/layouts/settings/components/retranscribe_sheet.dart';
import 'package:opentranscribe/view/layouts/settings/components/speaking_hero.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:transcriber/transcriber.dart';

/// The transcription screen as an answer to one question, what happens when I
/// hit record: the default language as a hero card, the other kept languages
/// as chips (a chip tap makes it the default), the engine picker, and the
/// footnotes. The whole library lives in the language sheet the hero and the
/// Add chip open.
class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  /// Debug-only: which failure kind the next section-label long-press stamps.
  int _debugFailureIndex = 0;

  /// Debug-only: stamps a rotating failure kind on the default row, so the
  /// hero (and the sheet's row) show it; tap through to view its sheet.
  /// Long-press the Speaking section label to cycle: cap, unsupported, stuck,
  /// generic, removeFailed. Cap fills its eviction list from the currently
  /// reserved languages, so install a second language first to see that
  /// picker populated. No effect in release (the gesture is never wired
  /// there).
  void _debugCycleFailure() {
    final cubit = context.read<SettingsCubit>();
    final rows = cubit.state.languages;
    if (rows.isEmpty) return;
    final target = (cubit.state.defaultLanguage ?? rows.first).tag;
    final reserved = [
      for (final r in rows)
        if (r.reserved) r.tag,
    ];
    final kinds = <LanguageFailure>[
      LanguageFailure(kind: LanguageFailureKind.capReached, reservedTags: reserved),
      const LanguageFailure(
        kind: LanguageFailureKind.installFailed,
        assetStatus: ModelAssetStatus.unsupported,
      ),
      const LanguageFailure(
        kind: LanguageFailureKind.installFailed,
        assetStatus: ModelAssetStatus.downloading,
      ),
      const LanguageFailure(kind: LanguageFailureKind.installFailed),
      const LanguageFailure(kind: LanguageFailureKind.removeFailed),
    ];
    cubit.debugStampFailure(target, kinds[_debugFailureIndex % kinds.length]);
    _debugFailureIndex++;
  }

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

  void _openLanguageSheet(BuildContext context) {
    if (!_onTop(context)) return;
    unawaited(showLanguageSheet(context, cubit: context.read<SettingsCubit>()));
  }

  /// The hero keeps its one promise: when the default is broken its tap tells
  /// that story (with the recovery), otherwise it opens the library. The Add
  /// chip stays a library door either way.
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

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          // Managing (install affordances, the slot count) exists only where
          // a real reservation concept does; max 0 also covers the
          // could-not-answer degrade, where offering actions would be lying.
          final canManage = state.reservationMax > 0;
          // Reservations, not ready models: a language mid-download (or one
          // whose download failed after reserving) holds a slot too.
          final reserved = state.languages.where((row) => row.reserved).length;
          final chips = chipLanguages(state.languages);
          return SettingsList(
            children: [
              // Breath under the bar before the first label; sm reads cramped
              // against the frosted edge, md doubles the label's own top pad.
              const SizedBox(height: 10),
              GestureDetector(
                // Opaque so the label's whole padded band takes the press,
                // not just the text ink.
                behavior: HitTestBehavior.opaque,
                onLongPress: kDebugMode ? _debugCycleFailure : null,
                child: SectionLabel(l10n.transcriptionSpeaking),
              ),
              _Melt(
                child: SpeakingHero(
                  state: state,
                  // By the state's own engine id, not the active row: mid-switch
                  // the readiness still describes the previous engine.
                  engineName: engineRows
                      .where((row) => row.descriptor.engineId == state.engineId)
                      .firstOrNull
                      ?.descriptor
                      .displayName,
                  onTap: () => _openHero(context, state),
                ),
              ),
              // The label only when something IS also ready; the Add chip
              // stays either way, as the library door a broken default's hero
              // (routing to its story) cannot be.
              _Melt(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                ),
              ),
              SectionLabel(l10n.transcriptionEngines),
              _Melt(
                child: SettingsCard(
                  children: [
                    for (final engineRow in engineRows)
                      _EngineRow(key: ValueKey(engineRow.descriptor.engineId), row: engineRow),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SettingsCard(children: [_RetranscribeRow()]),
              const SizedBox(height: AppSpacing.md),
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
                    if (state.managesModels) SectionInfo(l10n.transcriptionFootnote),
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

/// Seated under the picker because the picker defines it: everything the
/// active engine has not heard.
class _RetranscribeRow extends StatelessWidget {
  const _RetranscribeRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<RetranscribeCubit>().state;
    return SettingsBusyRow(
      icon: AppIcons.arrowCounterclockwise,
      label: l10n.retranscribeAllTitle,
      busy: state.isRunning,
      detail: state.runnable > 0 ? '${state.runnable}' : null,
      onTap: () {
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        unawaited(showRetranscribeSheet(context));
      },
    );
  }
}

/// One engine as the picker offers it: logo chip, name, the active marker, and
/// a quiet second line (the descriptor's blurb, or why a dimmed one cannot run
/// here). Tapping switches; tapping a dimmed row opens the fuller story
/// instead, and a switch refused mid-take says so.
class _EngineRow extends StatelessWidget {
  const _EngineRow({required this.row, super.key});

  final EngineRowState row;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return SelectableRow(
      label: row.descriptor.displayName,
      leading: AppIcon(
        row.descriptor.logo,
        size: 18,
        color: row.available ? theme.text : theme.textSecondary,
      ),
      selected: row.isActive,
      dimmed: !row.available,
      note: row.available ? row.descriptor.blurb(l10n) : _unavailableNote(l10n),
      onTap: () => _tap(context),
    );
  }

  // Exhaustive on purpose: a new unavailability kind must fail to compile
  // until it is worded, never silently borrow this one's words.
  String _unavailableNote(AppLocalizations l10n) => switch (row.unavailability!) {
    EngineUnavailability.needsNewerDevice => l10n.engineUnavailableNote,
  };

  String _unavailableBody(AppLocalizations l10n) => switch (row.unavailability!) {
    EngineUnavailability.needsNewerDevice => l10n.engineUnavailableBody(row.descriptor.displayName),
  };

  Future<void> _tap(BuildContext context) async {
    // Same one-sheet rule as the hero: a second pointer in the same frame
    // must not stack another sheet.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context)!;
    if (!row.available) {
      await showAppSheet<void>(
        context,
        builder: (context) => SheetMessage(
          icon: row.descriptor.logo,
          title: l10n.engineUnavailableTitle,
          body: _unavailableBody(l10n),
        ),
      );
      return;
    }
    final EnginePickOutcome outcome;
    try {
      outcome = await context.read<EnginesCubit>().pick(row.descriptor.engineId);
    } catch (_) {
      // The switch (or its revert) happened; only the stored choice is lost.
      // The rows above already say what is active; this says it will not hold.
      // Re-checked, not just mounted: the screen may have been covered or
      // popped during the pick, and this sheet belongs on it alone.
      if (!context.mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      await showAppSheet<void>(
        context,
        builder: (context) => SheetMessage(
          icon: AppIcons.internaldrive,
          title: l10n.engineNotSavedTitle,
          body: l10n.engineNotSavedBody,
        ),
      );
      return;
    }
    if (!context.mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final refusal = switch (outcome) {
      EnginePickOutcome.busy => (
        icon: AppIcons.micFill,
        title: l10n.engineBusyTitle,
        body: l10n.engineBusyBody,
      ),
      EnginePickOutcome.retranscribing => (
        icon: AppIcons.arrowCounterclockwise,
        title: l10n.engineRetranscribingTitle,
        body: l10n.engineRetranscribingBody,
      ),
      _ => null,
    };
    if (refusal == null) return;
    await showAppSheet<void>(
      context,
      builder: (context) =>
          SheetMessage(icon: refusal.icon, title: refusal.title, body: refusal.body),
    );
  }
}
