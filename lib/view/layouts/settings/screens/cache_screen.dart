import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/cache_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Cache: what the kept recordings occupy, the keep-audio switch, and the one
/// bulk action against the reclaimable share. Owns a [CacheCubit] so the
/// numbers are re-measured on every open.
class CacheScreen extends StatelessWidget {
  const CacheScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CacheCubit(service: Deps.i.transcriptionService),
      child: const _CacheView(),
    );
  }
}

class _CacheView extends StatelessWidget {
  const _CacheView();

  Future<void> _confirmClear(BuildContext context, AudioUsage usage) async {
    final l10n = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final cache = context.read<CacheCubit>();
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.trash,
        title: l10n.cacheClearTitle,
        body: l10n.cacheClearBody(
          usage.reclaimableCount,
          formatBytes(usage.reclaimableBytes, locale),
        ),
        action: AppButton(
          label: l10n.cacheClearConfirm,
          variant: AppButtonVariant.danger,
          onPressed: () {
            // The house destructive-confirm weight, same as swipe-delete.
            Haptics.medium();
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );
    // Cancel is the sheet's dismiss; only an explicit confirm clears.
    if (confirmed ?? false) unawaited(cache.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final cache = context.watch<CacheCubit>().state;
    final settings = context.watch<SettingsCubit>().state;
    final usage = cache.usage;
    final clearable = usage != null && usage.reclaimableCount > 0 && !cache.clearing;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: SettingsList(
        children: [
          const SizedBox(height: 10),
          SectionInfo(l10n.cacheUsageInfo),
          _StorageCard(usage: usage, locale: locale),
          const SizedBox(height: AppSpacing.md),
          SettingsCard(
            children: [
              SettingsToggleRow(
                icon: AppIcons.micFill,
                label: l10n.cacheKeepAudio,
                value: settings.keepAudio,
                onChanged: (keep) => unawaited(context.read<SettingsCubit>().setKeepAudio(keep)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SectionInfo(l10n.cacheKeepAudioInfo),
          // A wider gap than the footer's own tail, so the paragraph reads as
          // the toggle group's footer, not the clear card's header.
          const SizedBox(height: AppSpacing.md),
          SettingsCard(
            children: [
              _ClearRow(
                label: l10n.cacheClear,
                detail: clearable ? formatBytes(usage.reclaimableBytes, locale) : null,
                clearing: cache.clearing,
                onTap: clearable ? () => unawaited(_confirmClear(context, usage)) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The storage story as one card: how much all kept audio weighs, how many
/// entries keep it, the reclaimable share as a bar, and that share as its own
/// row. The bar only exists when something IS reclaimable; an empty track
/// reads as a rendering mistake, not as information.
class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.usage, required this.locale});

  final AudioUsage? usage;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;
    final measured = usage;
    final showBar = measured != null && measured.reclaimableBytes > 0;
    // AnimatedSize: the bar mounting, the count line landing, and a clear
    // shrinking the card all resize smoothly instead of snapping a frame.
    return AnimatedSize(
      duration: context.reduceMotion ? AppMotion.instant : context.motionNow.indicator,
      curve: context.motionNow.indicatorCurve,
      alignment: Alignment.topCenter,
      child: SettingsCard(
        children: [
          // Header and bar as ONE child: the card divides between children, and
          // a divider hugging the bar would read as three broken strips.
          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14, 14, 14, showBar ? 0 : 14),
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
                      child: AppIcon(AppIcons.internaldrive, size: 22, color: theme.text),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // Ellipsis while the first sweep runs: zeros would
                            // read as "nothing stored".
                            measured == null ? '…' : formatBytes(measured.totalBytes, locale),
                            style: AppType.digits(AppType.headline).copyWith(color: theme.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // A space, not conditional: the line's height is
                            // reserved so the header never grows a frame after
                            // the first measure lands.
                            measured == null ? ' ' : l10n.cacheRecordingsCount(measured.totalCount),
                            style: AppType.footnote.copyWith(color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showBar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          Positioned.fill(child: ColoredBox(color: tokens.iconTileBackground)),
                          // Tweened so a changing share sweeps rather than jumps.
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              end: (measured.reclaimableBytes / measured.totalBytes).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                            duration: context.reduceMotion
                                ? Duration.zero
                                : context.motionNow.indicator,
                            curve: context.motionNow.indicatorCurve,
                            builder: (context, fraction, _) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: fraction,
                              heightFactor: 1,
                              child: ColoredBox(color: theme.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (measured != null)
            _ReclaimableRow(
              size: formatBytes(measured.reclaimableBytes, locale),
              highlighted: measured.reclaimableBytes > 0,
            ),
        ],
      ),
    );
  }
}

/// The reclaimable share as a row: what the clear action would free. The tile
/// tints accent while there is something to free, quiet otherwise.
class _ReclaimableRow extends StatelessWidget {
  const _ReclaimableRow({required this.size, required this.highlighted});

  final String size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;
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
              color: highlighted ? theme.accent.withValues(alpha: 0.14) : tokens.iconTileBackground,
            ),
            child: AppIcon(
              AppIcons.trash,
              size: 16,
              color: highlighted ? theme.accent : theme.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.cacheReclaimable, style: AppType.subhead.copyWith(color: theme.text)),
                const SizedBox(height: 2),
                Text(
                  l10n.cacheReclaimableInfo,
                  style: AppType.footnote.copyWith(color: theme.textSecondary),
                ),
              ],
            ),
          ),
          Text(size, style: AppType.digits(AppType.subhead).copyWith(color: theme.textSecondary)),
        ],
      ),
    );
  }
}

/// The destructive action as a row that says so: danger-tinted tile and label
/// while enabled, the dimmed [SelectableRow] treatment while there is nothing
/// to clear, a spinner while the purge runs.
class _ClearRow extends StatelessWidget {
  const _ClearRow({
    required this.label,
    required this.detail,
    required this.clearing,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final bool clearing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final enabled = onTap != null;
    return Touchable(
      onTap: onTap,
      haptic: enabled,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: tokens.iconTileSize,
              height: tokens.iconTileSize,
              alignment: Alignment.center,
              decoration: SuperellipseDecoration(
                borderRadius: tokens.iconTileRadius,
                color: enabled ? theme.danger.withValues(alpha: 0.14) : tokens.iconTileBackground,
              ),
              child: AppIcon(
                AppIcons.trash,
                size: 16,
                color: enabled ? theme.danger : theme.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppType.subhead.copyWith(
                  color: enabled ? theme.danger : theme.textSecondary,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
              child: clearing
                  ? AppSpinner(size: 16, color: theme.textSecondary)
                  : detail != null
                  ? Text(
                      detail!,
                      key: ValueKey(detail),
                      style: AppType.digits(AppType.subhead).copyWith(color: theme.textSecondary),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
