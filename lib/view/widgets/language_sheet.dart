import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/model_failure_line.dart';
import 'package:opentranscribe/view/widgets/model_failure_sheet.dart';
import 'package:opentranscribe/view/widgets/model_failure_story.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:transcriber/transcriber.dart';

/// [showLanguageSheet] from a tap, while the route is still on top.
void openLanguageSheet(BuildContext context) {
  if (!isTopRoute(context)) return;
  unawaited(showLanguageSheet(context, cubit: context.read<SettingsCubit>()));
}

/// The whole language library in one sheet: Your languages (the kept set;
/// tapping one makes it the default and closes the sheet, the remove
/// affordance lives here) over All languages (a tap downloads-and-keeps under
/// a managed engine; under dictation a ready row becomes the default and an
/// unready one tells the keyboard-settings story).
Future<void> showLanguageSheet(BuildContext context, {required SettingsCubit cubit}) {
  return showAppSheet<void>(
    context,
    // Tighter than a message sheet: these are full-width cards, and the
    // default inset reads as wasted margin around them.
    inset: AppSpacing.md,
    builder: (context) => BlocProvider.value(value: cubit, child: const _LanguageList()),
  );
}

/// Whether [row] sits in Yours rather than the library: the default is kept
/// honestly even when unready; beyond it a managed engine keeps whatever
/// holds a slot, and a readiness-probing one keeps what can transcribe now.
/// Under an engine whose one model serves every language, readiness says
/// nothing about the user, so only the default is theirs.
bool keptLanguage(
  LanguageModelState row, {
  required bool managesModels,
  required bool oneModelForAll,
}) => row.isDefault || (!oneModelForAll && (managesModels ? row.reserved : row.isReady));

/// Whether a sheet row offers a download: a managed engine with somewhere to
/// put one (a reservation cap, or one model for every language), and a
/// language that is neither ready nor unsupported. Under one model for all
/// only the default row installs; the download is the model's, not a
/// language's.
bool sheetRowInstalls(
  LanguageModelState row, {
  required bool managesModels,
  required int reservationMax,
  required bool oneModelForAll,
}) =>
    managesModels &&
    (reservationMax > 0 || oneModelForAll) &&
    !row.isReady &&
    row.status != ModelAssetStatus.unsupported &&
    (!oneModelForAll || row.isDefault);

/// Whether a tap makes the row the default: it can transcribe now, or, under
/// one model for every language, it is any supported language (readiness
/// there is the model's story, not the language's).
bool sheetRowPicks(LanguageModelState row, {required bool oneModelForAll}) =>
    row.isReady || (oneModelForAll && !row.isDefault && row.status != ModelAssetStatus.unsupported);

class _LanguageList extends StatelessWidget {
  const _LanguageList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final canManage = state.reservationMax > 0;
        bool kept(LanguageModelState row) => keptLanguage(
          row,
          managesModels: state.managesModels,
          oneModelForAll: state.offersModelChoice,
        );
        bool installs(LanguageModelState row) => sheetRowInstalls(
          row,
          managesModels: state.managesModels,
          reservationMax: state.reservationMax,
          oneModelForAll: state.offersModelChoice,
        );
        bool picks(LanguageModelState row) =>
            sheetRowPicks(row, oneModelForAll: state.offersModelChoice);
        final yours = [
          for (final row in state.languages)
            if (kept(row)) row,
        ];
        final others = [
          for (final row in state.languages)
            if (!kept(row)) row,
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (yours.isNotEmpty) ...[
              SectionLabel(l10n.transcriptionYourLanguages),
              SettingsCard(
                children: [
                  for (final row in yours)
                    _SheetRow(
                      key: ValueKey(row.tag),
                      row: row,
                      managesModels: state.managesModels,
                      canManage: canManage,
                      installs: installs(row),
                      picks: picks(row),
                    ),
                ],
              ),
            ],
            if (others.isNotEmpty) ...[
              SectionLabel(l10n.transcriptionAllLanguages),
              SettingsCard(
                children: [
                  for (final row in others)
                    _SheetRow(
                      key: ValueKey(row.tag),
                      row: row,
                      managesModels: state.managesModels,
                      canManage: canManage,
                      installs: installs(row),
                      picks: picks(row),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One language in the sheet. The tap is the row's one promise: make it the
/// default when it can transcribe now (closing the sheet), start its download
/// when it only needs one, and tell its story when something stands in the
/// way. The trailing control carries the row's own state; the trash on a kept
/// row is deliberately a separate affordance from the tap.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.row,
    required this.managesModels,
    required this.canManage,
    required this.installs,
    required this.picks,
    super.key,
  });

  final LanguageModelState row;
  final bool managesModels;
  final bool canManage;
  final bool installs;
  final bool picks;

  bool get _unready => row.status == ModelAssetStatus.unsupported;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;
    final subLine = _subLine(l10n);
    return Touchable(
      onTap: () => _tap(context),
      haptic: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Opacity(
              opacity: _unready ? 0.45 : 1,
              child: Container(
                width: tokens.iconTileSize,
                height: tokens.iconTileSize,
                alignment: Alignment.center,
                decoration: SuperellipseDecoration(
                  borderRadius: tokens.iconTileRadius,
                  color: row.isDefault && !_unready
                      ? theme.accent.withValues(alpha: 0.14)
                      : tokens.iconTileBackground,
                ),
                child: LocaleFlag(localeFlag(row.tag), size: 18),
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
                            color: _unready ? theme.textSecondary : theme.text,
                            fontWeight: row.isDefault ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (row.isDefault) ...[
                        const SizedBox(width: AppSpacing.sm),
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
                  if (subLine != null) ...[
                    const SizedBox(height: 2),
                    Text(subLine, style: AppType.footnote.copyWith(color: theme.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _trailing(context, theme),
          ],
        ),
      ),
    );
  }

  /// A quiet line only when the row has something to say; an idle ready row
  /// stays one line tall.
  String? _subLine(AppLocalizations l10n) =>
      row.installing ? null : modelTroubleLine(l10n, row, managesModels: managesModels);

  bool get _installFailed =>
      row.failure != null && row.failure!.kind != LanguageFailureKind.removeFailed;

  bool get _stuck => row.status == ModelAssetStatus.downloading && !row.installing;

  Widget _trailing(BuildContext context, AppTheme theme) {
    if (row.installing) {
      final fraction = row.installFraction!;
      if (fraction <= 0) return AppSpinner(color: theme.text);
      return ProgressRing(fraction: fraction, size: 20);
    }
    if (row.isDefault && row.isReady) {
      return AppIcon(AppIcons.checkmark, size: 15, color: theme.settings.toggleActive);
    }
    // Every held slot can be freed here, ready or broken: freeing a slot a
    // broken language holds is the cap-recovery path itself. The default is
    // the exception; its checkmark says it is in use (change it first). The
    // row tap still tells a broken row's story, with its own retry.
    if (canManage && row.reserved && !row.isDefault) {
      return Touchable(
        // A refused write must stay a quiet no-op here, like every other
        // fire-and-forget persist; the row's failure stamp tells the story.
        onTap: () => context.read<SettingsCubit>().remove(row.tag).ignore(),
        haptic: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: AppIcon(AppIcons.trash, size: 16, color: theme.textSecondary),
        ),
      );
    }
    if (_installFailed || _stuck) {
      return AppIcon(AppIcons.arrowCounterclockwise, size: 17, color: theme.accent);
    }
    if (!installs) return const SizedBox.shrink();
    return AppIcon(AppIcons.icloud, size: 18, color: theme.accent);
  }

  Future<void> _tap(BuildContext context) async {
    if (!isTopRoute(context)) return;
    final cubit = context.read<SettingsCubit>();
    if (rowHasFailureStory(row)) {
      unawaited(showModelFailureSheet(context, cubit: cubit, row: row));
      return;
    }
    if (row.installing) return;
    if (picks) {
      if (row.isDefault) {
        Navigator.of(context).pop();
        return;
      }
      // Awaited so a refused persist keeps the sheet open with the row
      // unchanged, instead of closing over a silently lost choice. The route
      // check keeps a second in-flight tap from popping the screen under the
      // sheet: the sheet's elements outlive its pop through the exit
      // transition, so mounted alone does not say the sheet is still up.
      final route = ModalRoute.of(context);
      try {
        await cubit.setLocale(row.tag);
      } catch (_) {
        return;
      }
      if (context.mounted && (route?.isCurrent ?? false)) Navigator.of(context).pop();
      return;
    }
    if (installs) cubit.install(row.tag);
  }
}
