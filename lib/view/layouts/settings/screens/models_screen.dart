import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/delete_swipe.dart';
import 'package:opentranscribe/view/widgets/language_menu_button.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
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
          // use now on top (the default first), then everything else by name.
          final rows = [...state.languages]
            ..sort((a, b) {
              if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
              if (a.isReady != b.isReady) return a.isReady ? -1 : 1;
              return localeDisplayName(
                a.tag,
              ).toLowerCase().compareTo(localeDisplayName(b.tag).toLowerCase());
            });
          final hints = [
            if (rows.isNotEmpty) l10n.transcriptionDefaultHint,
            if (canManage && reserved > 0) l10n.transcriptionRemoveHint,
          ];
          return SettingsList(
            children: [
              const SizedBox(height: 10),
              SectionInfo(l10n.transcriptionInfo),
              _EngineCard(
                engine: engine,
                slotLine: canManage ? l10n.transcriptionCap(reserved, state.reservationMax) : null,
              ),
              const SizedBox(height: AppSpacing.md),
              SectionLabel(l10n.transcriptionLanguages),
              SettingsCard(
                children: [
                  for (final row in rows)
                    _LanguageRow(
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
    // chooser); hold is the power move for someone already managing models.
    final makeDefault = unsupported || row.isDefault
        ? null
        : () => unawaited(cubit.setLocale(row.tag));
    // Removing an unsupported-but-reserved language stays allowed: freeing a
    // slot held by a broken language is the cap-recovery path itself.
    if (!canManage || !row.reserved) {
      return Touchable(onTap: null, onLongPress: makeDefault, child: content);
    }
    return DeleteSwipe(
      id: row.tag,
      openId: openRemove,
      // A tap's only job is closing an open disc, handled inside.
      onTap: () {},
      onLongPress: makeDefault,
      onDelete: () => unawaited(cubit.remove(row.tag)),
      child: content,
    );
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
                Text(_subLine(l10n), style: AppType.footnote.copyWith(color: theme.textSecondary)),
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
    final failure = row.failure;
    if (failure != null) {
      return switch (failure.kind) {
        LanguageFailureKind.capReached => l10n.transcriptionErrorCap,
        LanguageFailureKind.installFailed => switch (failure.assetStatus) {
          ModelAssetStatus.unsupported => l10n.transcriptionErrorUnsupported,
          ModelAssetStatus.downloading => l10n.transcriptionErrorStuck,
          _ => l10n.transcriptionErrorGeneric,
        },
      };
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    if (row.installing) {
      return ProgressRing(fraction: row.installFraction!);
    }
    if (row.failure != null || (row.status == ModelAssetStatus.downloading && !row.installing)) {
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
