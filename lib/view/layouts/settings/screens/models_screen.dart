import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/utils/language_tags.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_failure_sheet.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_failure_story.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/delete_swipe.dart';
import 'package:opentranscribe/view/widgets/language_menu_button.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/model_failure_line.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Model management: the engine on top, then one row per language with its
/// install state, live download progress, honest failure states, and the
/// model it runs on (several engines will share this list one day). The
/// DEFAULT language is chosen here too: the globe on the bar (the same
/// adaptive menu the recorder carries), or touch and hold a row. Swipe a
/// language left to remove it, the same gesture entries speak.
class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  /// The one language row with its remove disc open, shared across the list.
  final ValueNotifier<String?> _openRemove = ValueNotifier<String?>(null);

  /// Debug-only: which failure kind the next engine-card long-press stamps.
  int _debugFailureIndex = 0;

  /// Debug-only: stamps a rotating failure kind on the default row, then tap
  /// that row to view its sheet (its title names the kind). Long-press the
  /// engine card to cycle: cap, unsupported, stuck, generic, removeFailed. Cap
  /// fills its eviction list from the currently reserved languages, so install
  /// a second language first to see that picker populated. No effect in
  /// release (the gesture is never wired there).
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
    // model the system quietly removed. Bounded by the reservation cap.
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

  @override
  void dispose() {
    _openRemove.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    // One engine today; the card and the per-row model name are where a second
    // one becomes visible when it ships.
    final engine = Deps.i.engineDescriptors.first;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      // The default-language choice, where the models live: the same globe
      // the recorder carries, setting the app default instead of a session.
      actions: const [_DefaultLanguageAction()],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          // Managing (install glyphs, remove, the slot line) exists only where
          // a real reservation concept does; max 0 also covers the
          // could-not-answer degrade, where offering actions would be lying.
          final canManage = state.reservationMax > 0;
          // Reservations, not ready models: a language mid-download (or one
          // whose download failed after reserving) holds a slot too.
          final reserved = state.languages.where((row) => row.reserved).length;
          // Sorted for reading, not by the engine's tag order: what you can
          // use now on top (the default first), then major languages first.
          final rows = [...state.languages]
            ..sort((a, b) {
              if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
              if (a.isReady != b.isReady) return a.isReady ? -1 : 1;
              return languageTagCompare(a.tag, b.tag);
            });
          final hints = [
            if (state.deviceLanguageUnsupported)
              l10n.transcriptionDeviceLanguageFallback(localeDisplayName(state.localeId)),
            if (rows.isNotEmpty) l10n.transcriptionDefaultHint,
            if (canManage && reserved > 0) l10n.transcriptionRemoveHint,
          ];
          return NotificationListener<ScrollStartNotification>(
            // Scrolling closes an open remove disc, the same contract the
            // home list keeps: the disc belongs to the row under the finger.
            onNotification: (_) {
              _openRemove.value = null;
              return false;
            },
            child: SettingsList(
              children: [
                const SizedBox(height: 10),
                SectionInfo(l10n.transcriptionInfo),
                // Debug: long-press the engine card to stamp a rotating
                // failure kind on the default row, then tap the row to view
                // its sheet. Never wired in release.
                GestureDetector(
                  onLongPress: kDebugMode ? _debugCycleFailure : null,
                  child: _EngineCard(
                    engine: engine,
                    slotLine: canManage
                        ? l10n.transcriptionCap(reserved, state.reservationMax)
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SectionLabel(l10n.transcriptionLanguages),
                SettingsCard(
                  children: [
                    for (final row in rows)
                      _LanguageRow(
                        // Keyed by language: after a removal's rebuild the swipe
                        // state must follow its row (or die with it), never be
                        // recycled onto whichever row lands in this slot.
                        key: ValueKey(row.tag),
                        row: row,
                        canManage: canManage,
                        openRemove: _openRemove,
                        modelName: engine.displayName,
                      ),
                  ],
                ),
                if (hints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, AppSpacing.md, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (index, hint) in hints.indexed) ...[
                          if (index > 0) const SizedBox(height: AppSpacing.xs),
                          Text(hint, style: AppType.footnote.copyWith(color: theme.textSecondary)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The bar's default-language switch: every usable language, the default
/// checked; picking one sets the app default.
class _DefaultLanguageAction extends StatelessWidget {
  const _DefaultLanguageAction();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final settings = context.watch<SettingsCubit>().state;
    return LanguageMenuButton(
      current: settings.localeId,
      tags: settings.selectableLanguageTags(),
      color: theme.topBar.iconColor,
      onPick: (tag) => context.read<SettingsCubit>().setLocale(tag),
    );
  }
}

/// The engine as a card: its logo, name, and the slot line when the platform
/// caps how many languages the app may hold ready.
class _EngineCard extends StatelessWidget {
  const _EngineCard({required this.engine, required this.slotLine});

  final EngineDescriptor engine;
  final String? slotLine;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: SuperellipseDecoration(
                  borderRadius: tokens.iconTileRadius + 2,
                  color: tokens.iconTileBackground,
                ),
                child: AppIcon(engine.logo, size: 22, color: theme.text),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(engine.displayName, style: AppType.headline.copyWith(color: theme.text)),
                    if (slotLine != null) ...[
                      const SizedBox(height: 2),
                      Text(slotLine!, style: AppType.footnote.copyWith(color: theme.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One language: flag chip (accent-tinted for the default), native name with a
/// Default tag, the model it runs on (or its failure line), and the model
/// control on the trailing edge. Reserved rows swipe left to remove.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.row,
    required this.canManage,
    required this.openRemove,
    required this.modelName,
    super.key,
  });

  final LanguageModelState row;

  /// Whether a real reservation concept exists (see the builder above); off,
  /// no remove and no install affordances are offered.
  final bool canManage;

  final ValueNotifier<String?> openRemove;

  /// The engine serving this language, named per row because future builds
  /// will mix models in one list.
  final String modelName;

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    final cubit = context.read<SettingsCubit>();
    final unsupported = row.status == ModelAssetStatus.unsupported;
    // Hold = make default, everywhere the language could work. Tap stays
    // free of meaning here on purpose (the settings picker is the primary
    // chooser); hold is the power move for someone already managing models -
    // EXCEPT on a row with a failure story, where tap opens the explanation.
    final makeDefault = unsupported || row.isDefault
        ? null
        : () => unawaited(cubit.setLocale(row.tag));
    final explain = rowHasFailureStory(row)
        ? () => unawaited(showModelFailureSheet(context, cubit: cubit, row: row))
        : null;
    // Removing an unsupported-but-reserved language stays allowed: freeing a
    // slot held by a broken language is the cap-recovery path itself.
    if (!canManage || !row.reserved) {
      return Touchable(onTap: explain, onLongPress: makeDefault, child: content);
    }
    return DeleteSwipe(
      id: row.tag,
      openId: openRemove,
      // A tap closes an open disc (handled inside); on a settled row it opens
      // the failure story when there is one.
      onTap: explain ?? () {},
      onLongPress: makeDefault,
      onDelete: () => unawaited(_removeAndSettle(context, cubit)),
      // Tighter than the default: releasing a language is undoable (install
      // it again), so demanding the pill be dragged across nearly the whole
      // row reads as more work than the action deserves.
      commitReveal: 1.6,
      child: content,
    );
  }

  /// Removes the language, then releases the open swipe EITHER WAY: a refused
  /// removal keeps the row, and a row keeping its red disc open forever is the
  /// bug this screen used to have. The failure line says what happened.
  Future<void> _removeAndSettle(BuildContext context, SettingsCubit cubit) async {
    await cubit.remove(row.tag);
    // The screen may have been popped during the round trip, taking the
    // notifier down with it; a dead row has no disc left to release.
    if (context.mounted) openRemove.value = null;
  }

  Widget _content(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;
    final unsupported = row.status == ModelAssetStatus.unsupported;
    final active = row.isDefault && !unsupported;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: tokens.iconTileSize,
            height: tokens.iconTileSize,
            alignment: Alignment.center,
            decoration: SuperellipseDecoration(
              borderRadius: tokens.iconTileRadius,
              color: active ? theme.accent.withValues(alpha: 0.14) : tokens.iconTileBackground,
            ),
            // height: 1 collapses the line leading a flag emoji otherwise
            // carries below its glyph (same fix as the picker rows).
            child: Text(
              localeFlag(row.tag),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, height: 1),
              textScaler: TextScaler.noScaling,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        localeDisplayName(row.tag),
                        overflow: TextOverflow.ellipsis,
                        style: AppType.subhead.copyWith(
                          color: unsupported ? theme.textSecondary : theme.text,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (row.isDefault) ...[
                      const SizedBox(width: AppSpacing.sm),
                      // A word, not a color: which language is the default
                      // must survive every theme and read at a glance.
                      Text(
                        l10n.transcriptionDefaultTag,
                        style: AppType.caption.copyWith(
                          color: theme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (row.installing)
                  _DownloadingLine(fraction: row.installFraction!)
                else
                  Text(
                    _subLine(l10n),
                    style: AppType.footnote.copyWith(color: theme.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Trailing(row: row, canManage: canManage),
        ],
      ),
    );
  }

  /// The quiet line under the name: a failure worded by kind and by the
  /// asset's pre-install state, a language the platform cannot serve, a system
  /// download still pending from an earlier attempt, and otherwise the model
  /// this language runs on.
  String _subLine(AppLocalizations l10n) {
    final failure = modelFailureLine(l10n, row);
    if (failure != null) return failure;
    if (row.status == ModelAssetStatus.unsupported) return l10n.transcriptionErrorUnsupported;
    if (row.status == ModelAssetStatus.downloading && !row.installing) {
      return l10n.transcriptionErrorStuck;
    }
    return modelName;
  }
}

/// The model control for one row. Every state answers the same question, "can
/// I use this language right now": ready (checkmark), downloading (fraction
/// ring), failed or stuck (retry), downloadable (download), unsupported or
/// unknowable (nothing).
class _Trailing extends StatelessWidget {
  const _Trailing({required this.row, required this.canManage});

  final LanguageModelState row;
  final bool canManage;

  /// One footprint for every state ([_Glyph]'s 22px icon plus its padding), so
  /// the ring, spinner, and checkmark share the glyphs' exact center instead of
  /// hugging the row's edge a few pixels further right.
  static const double _slot = 30;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // Crossfaded between states, so a finishing download melts into its
    // checkmark instead of teleporting.
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
      child: SizedBox(
        key: ValueKey(_stateName),
        width: _slot,
        height: _slot,
        // OverflowBox, not Center: a glyph is a Text, and the wide symbols
        // (icloud) exceed their font size, so a tight slot would make the
        // Text clip them at its right edge. Centered at natural size, the
        // extra width paints harmlessly over the row's padding. The minimums
        // must be loosened too: OverflowBox keeps the slot's tight minWidth
        // otherwise, which stretched narrow glyphs (the checkmark) into a
        // 30-wide left-drawing Text and pushed their ink off-center.
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: _control(context, theme),
        ),
      ),
    );
  }

  /// The state the control is in, keying the crossfade: fraction changes keep
  /// the ring, state changes swap the child.
  String get _stateName {
    if (row.installing) return row.installFraction! <= 0 ? 'waiting' : 'downloading';
    if (_installFailed || _stuck) return 'retry';
    if (row.isReady) return 'ready';
    if (row.status == ModelAssetStatus.unsupported || !canManage) return 'none';
    return 'downloadable';
  }

  /// An install-side failure; a refused removal keeps the ready checkmark
  /// (the language still works), its story lives in the sub-line and sheet.
  bool get _installFailed =>
      row.failure != null && row.failure!.kind != LanguageFailureKind.removeFailed;

  bool get _stuck => row.status == ModelAssetStatus.downloading && !row.installing;

  Widget _control(BuildContext context, AppTheme theme) {
    if (row.installing) {
      final fraction = row.installFraction!;
      // Before the first real fraction there is nothing honest to draw as
      // progress; the spinner is the sanctioned wait-with-no-known-end. Tinted
      // by the INK color, not textSecondary: the spinner picks its black or
      // white dots by the tint's luminance, and dark mode's mid-gray secondary
      // sits under the threshold, which chose black dots on a dark surface.
      if (fraction <= 0) return AppSpinner(size: 22, color: theme.text);
      return ProgressRing(fraction: fraction);
    }
    if (_installFailed || _stuck) {
      // Retry IS the sanctioned recovery for a failure AND for a system
      // download stuck from an earlier attempt (re-issuing an install request
      // is safe and never duplicates a download).
      return _Glyph(
        icon: AppIcons.arrowCounterclockwise,
        color: theme.accent,
        onTap: () => context.read<SettingsCubit>().install(row.tag),
      );
    }
    if (row.isReady) {
      return AppIcon(AppIcons.checkmark, size: 16, color: theme.settings.toggleActive);
    }
    if (row.status == ModelAssetStatus.unsupported || !canManage) {
      // No affordance where none can act honestly: unsupported has nothing to
      // offer, and without a reservation concept (pre-26, degraded engines)
      // non-default rows' readiness is unknown, so a download glyph would be
      // a perpetual no-op.
      return const SizedBox.shrink();
    }
    // Downloadable, or installed system-wide but not yet usable by this app
    // (the same tap reserves it; that path completes without a download).
    return _Glyph(
      icon: AppIcons.icloud,
      color: theme.accent,
      onTap: () => context.read<SettingsCubit>().install(row.tag),
    );
  }
}

/// The downloading row's sub-line: "Downloading · 42%", the percent rolling
/// odometer-style as fractions land, so progress reads in words right where
/// the eye already is instead of only in a 22px ring.
class _DownloadingLine extends StatelessWidget {
  const _DownloadingLine({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final style = AppType.footnote.copyWith(color: theme.textSecondary);
    final percent = (fraction.clamp(0.0, 1.0) * 100).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${l10n.transcriptionDownloading} · ', style: style),
        RollingText(
          text: '$percent%',
          style: AppType.digits(AppType.footnote).copyWith(color: theme.textSecondary),
          // Quiet secondary text: every changed digit moves together.
          stagger: Duration.zero,
        ),
      ],
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Touchable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: AppIcon(icon, size: 22, color: color),
      ),
    );
  }
}
