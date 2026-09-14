import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/routes/routes.dart';
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
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// What the app keeps on the phone, by the three kinds the storage bar draws:
/// transcribed audio (the share a clear frees), audio not transcribed yet,
/// and downloaded models. Doubles, so a change can be drawn part way.
typedef StorageFigures = ({
  double clearable,
  double clearableCount,
  double kept,
  double keptCount,
  double models,
});

/// [usage] and [modelBytes] as the storage card's kinds. The kept share is
/// what the reclaimable share leaves of the total.
StorageFigures storageFigures(AudioUsage usage, {required int modelBytes}) => (
  clearable: usage.reclaimableBytes.toDouble(),
  clearableCount: usage.reclaimableCount.toDouble(),
  kept: (usage.totalBytes - usage.reclaimableBytes).clamp(0, usage.totalBytes).toDouble(),
  keptCount: (usage.totalCount - usage.reclaimableCount).clamp(0, usage.totalCount).toDouble(),
  models: modelBytes.toDouble(),
);

/// Everything the card totals.
double storageTotal(StorageFigures figures) => figures.clearable + figures.kept + figures.models;

/// The figures [t] of the way from [a] to [b].
StorageFigures lerpStorage(StorageFigures a, StorageFigures b, double t) => (
  clearable: lerpDouble(a.clearable, b.clearable, t)!,
  clearableCount: lerpDouble(a.clearableCount, b.clearableCount, t)!,
  kept: lerpDouble(a.kept, b.kept, t)!,
  keptCount: lerpDouble(a.keptCount, b.keptCount, t)!,
  models: lerpDouble(a.models, b.models, t)!,
);

/// Each kind's share of the bar, strongest first.
typedef StorageShares = ({double clearable, double kept, double models});

/// Each kind's share of the bar, zero across an empty phone.
StorageShares storageShares(StorageFigures figures) {
  final total = storageTotal(figures);
  if (total <= 0) return (clearable: 0, kept: 0, models: 0);
  return (
    clearable: figures.clearable / total,
    kept: figures.kept / total,
    models: figures.models / total,
  );
}

/// Each share's width across a bar [width] wide, with [gap] between the
/// kinds that show. A share under a pixel draws nothing (zero) and opens no
/// gap, so a sliver never leaves a double gap behind it.
List<double> storageBarWidths(List<double> shares, {required double width, required double gap}) {
  final shown = shares.where((share) => share * width >= 1).length;
  if (shown == 0) return [for (final _ in shares) 0];
  final room = width - gap * (shown - 1);
  return [for (final share in shares) share * width >= 1 ? share * room : 0];
}

/// What stands where the clear pill does: the pill while there is something
/// to clear, a spinner while a clear runs, what the last clear freed once
/// nothing is left, else that nothing is.
enum ClearFace { clear, clearing, freed, nothing }

ClearFace clearFace(CacheState state) {
  if (state.clearing) return ClearFace.clearing;
  if ((state.usage?.reclaimableCount ?? 0) > 0) return ClearFace.clear;
  if ((state.freedBytes ?? 0) > 0) return ClearFace.freed;
  return ClearFace.nothing;
}

/// Cache: everything the app keeps on the phone as one bar, a row per kind
/// with the clear on the row it frees, and the keep-audio switch saying what
/// it does as it is set. Owns a [CacheCubit] so the numbers are re-measured
/// on every open.
class CacheScreen extends StatelessWidget {
  const CacheScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          CacheCubit(service: Deps.i.transcriptionService, modelBytes: Deps.i.modelBytes),
      child: const _CacheView(),
    );
  }
}

class _CacheView extends StatelessWidget {
  const _CacheView();

  Future<void> _confirmClear(BuildContext context, AudioUsage usage) async {
    if (!isTopRoute(context)) return;
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
    final cache = context.watch<CacheCubit>().state;
    final keepAudio = context.watch<SettingsCubit>().state.keepAudio;
    final usage = cache.usage;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: SettingsList(
        children: [
          const SizedBox(height: AppSpacing.sm),
          // The rows landing with the first measure, and the models row
          // coming or going, resize the card instead of snapping it.
          Melt(
            child: _StorageCard(
              figures: usage == null
                  ? null
                  : storageFigures(usage, modelBytes: cache.modelBytes ?? 0),
              clear: _ClearSeat(
                face: clearFace(cache),
                freedBytes: cache.freedBytes ?? 0,
                onClear: usage == null ? null : () => unawaited(_confirmClear(context, usage)),
              ),
              onModels: () {
                if (!isTopRoute(context)) return;
                final cache = context.read<CacheCubit>();
                // Models come and go over there without an entry changing, so
                // coming back re-measures.
                unawaited(
                  context.pushNamed(Routes.settingsModelsName).then((_) {
                    if (!cache.isClosed) unawaited(cache.load());
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // The two notes can wrap to different heights.
          Melt(
            child: SettingsCard(
              children: [
                SettingsToggleRow(
                  icon: AppIcons.waveform,
                  label: l10n.cacheKeepAudio,
                  note: keepAudio ? l10n.cacheKeepOnNote : l10n.cacheKeepOffNote,
                  value: keepAudio,
                  onChanged: (keep) => unawaited(context.read<SettingsCubit>().setKeepAudio(keep)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionInfo(l10n.cachePendingNote),
        ],
      ),
    );
  }
}

/// The storage story as one card: the total over a bar in three shades, then
/// a row per shade. The numbers and the bar read one spring
/// ([AppMotion.storageSpring]) from the figures on screen to the new, so a
/// clear drains its share while the total counts down with it. The first
/// measure only grows the bar in; its numbers land as they are.
class _StorageCard extends StatefulWidget {
  const _StorageCard({required this.figures, required this.clear, required this.onModels});

  /// Null until the first measure lands.
  final StorageFigures? figures;
  final Widget clear;
  final VoidCallback onModels;

  @override
  State<_StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends State<_StorageCard> with TickerProviderStateMixin {
  /// How far from [_from] to [_to] the card is drawn, 0 to 1.
  late final AnimationController _travel = AnimationController.unbounded(vsync: this, value: 1);

  /// How much of its length the bar has grown into, 0 to 1: once, on the
  /// first measure. Apart from [_travel], because shares of figures growing
  /// from nothing are the same shares all the way.
  late final AnimationController _grow = AnimationController.unbounded(
    vsync: this,
    value: widget.figures == null ? 0 : 1,
  );

  StorageFigures? _from;
  StorageFigures? _to;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.figures;
  }

  @override
  void didUpdateWidget(_StorageCard old) {
    super.didUpdateWidget(old);
    final figures = widget.figures;
    if (figures == null || figures == _to) return;
    final shown = _shown;
    _to = figures;
    if (shown == null) {
      // The first measure: its numbers land as they are; only the bar grows.
      _from = figures;
      _run(_grow);
      return;
    }
    _from = shown;
    _run(_travel);
  }

  /// Runs [controller] from 0 to 1 on the storage spring, or lands it at
  /// once under Reduce Motion.
  void _run(AnimationController controller) {
    if (context.reduceMotion) {
      controller.value = 1;
      return;
    }
    controller.animateWith(
      // Exactly on the new figures, or a freed share would stay a few bytes.
      SpringSimulation(context.motionNow.storageSpring, 0, 1, 0, snapToEnd: true),
    );
  }

  @override
  void dispose() {
    _travel.dispose();
    _grow.dispose();
    super.dispose();
  }

  StorageFigures? get _shown {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return null;
    return lerpStorage(from, to, _travel.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final shades = theme.settings.storageShades;
    return AnimatedBuilder(
      animation: Listenable.merge([_travel, _grow]),
      builder: (context, _) {
        final numbers = _shown;
        String size(double bytes) => formatBytes(bytes.round(), locale);
        return SettingsCard(
          children: [
            Padding(
              // The rows' own sides, so the total and bar line up with the tiles.
              padding: EdgeInsets.fromLTRB(
                theme.settings.rowPadding.left,
                AppSpacing.lg,
                theme.settings.rowPadding.right,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.cacheOnThisPhone,
                    style: AppType.footnote.copyWith(color: theme.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    // Ellipsis while the first sweep runs: zeros would read
                    // as "nothing stored".
                    numbers == null ? '…' : size(storageTotal(numbers)),
                    style: AppType.digits(AppType.display).copyWith(color: theme.text),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _StorageBar(
                    shares: numbers == null ? null : storageShares(numbers),
                    fill: _grow.value,
                  ),
                ],
              ),
            ),
            if (numbers != null) ...[
              _KindRow(
                shade: shades.clearable,
                label: l10n.cacheTranscribedAudio,
                line: l10n.cacheKindLine(size(numbers.clearable), numbers.clearableCount.round()),
                trailing: widget.clear,
              ),
              _KindRow(
                shade: shades.kept,
                label: l10n.cachePendingAudio,
                line: l10n.cacheKindLine(size(numbers.kept), numbers.keptCount.round()),
              ),
              if (numbers.models > 0)
                _KindRow(
                  shade: shades.models,
                  label: l10n.cacheModels,
                  line: l10n.cacheModelsLine(size(numbers.models)),
                  onTap: widget.onModels,
                ),
            ],
          ],
        );
      },
    );
  }
}

/// The bar: each kind's share in its shade, a hairline gap between the kinds
/// that have any, over an empty track. The kinds take [fill] of the length
/// between them; nothing but the track until [shares] are measured.
class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.shares, required this.fill});

  final StorageShares? shares;
  final double fill;

  static const double _height = 10;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    final shades = tokens.storageShades;
    final colors = [shades.clearable, shades.kept, shades.models];
    return ClipRRect(
      borderRadius: BorderRadius.circular(_height / 2),
      child: SizedBox(
        height: _height,
        child: ColoredBox(
          color: tokens.iconTileBackground,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final measured = shares;
              if (measured == null) return const SizedBox.expand();
              final widths = storageBarWidths(
                [
                  for (final share in [measured.clearable, measured.kept, measured.models])
                    share * fill,
                ],
                width: constraints.maxWidth,
                gap: _gap,
              );
              final parts = [
                for (final (i, width) in widths.indexed)
                  if (width > 0) (width, colors[i]),
              ];
              return Row(
                children: [
                  for (final (i, (width, color)) in parts.indexed) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    SizedBox(
                      width: width,
                      child: ColoredBox(color: color),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One kind of storage: its shade in a tile, its name over its size and
/// count, and what stands beside it; a row with [onTap] leads somewhere.
class _KindRow extends StatelessWidget {
  const _KindRow({
    required this.shade,
    required this.label,
    required this.line,
    this.trailing,
    this.onTap,
  });

  final Color shade;
  final String label;
  final String line;
  final Widget? trailing;
  final VoidCallback? onTap;

  static const double _swatch = 12;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final tap = onTap;
    final row = Padding(
      padding: tokens.rowPadding,
      child: Row(
        children: [
          SettingsIconTile(
            child: Container(
              width: _swatch,
              height: _swatch,
              decoration: SuperellipseDecoration(borderRadius: _swatch / 4, color: shade),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SettingsLabelAndNote(
              label: Text(label, style: AppType.subhead.copyWith(color: theme.text)),
              note: line,
              tabular: true,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.md), trailing!],
          if (tap != null)
            AppIcon(AppIcons.chevronForward, size: tokens.chevronSize, color: theme.textSecondary),
        ],
      ),
    );
    return tap == null ? row : Touchable(onTap: tap, haptic: true, child: row);
  }
}

/// Where the clear lives, on the row it frees: see [clearFace].
class _ClearSeat extends StatelessWidget {
  const _ClearSeat({required this.face, required this.freedBytes, required this.onClear});

  final ClearFace face;
  final int freedBytes;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final quiet = AppType.footnote.copyWith(color: theme.textSecondary);
    final motion = context.motionNow;
    final duration = context.reduceMotion ? Duration.zero : motion.indicator;
    final Widget seat = switch (face) {
      ClearFace.clear => _ClearPill(label: l10n.cacheClearAction, onTap: onClear),
      ClearFace.clearing => AppSpinner(size: 16, color: theme.textSecondary),
      ClearFace.freed => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.checkmark, size: 14, color: theme.settings.toggleActive),
          const SizedBox(width: AppSpacing.xs),
          Text(
            l10n.cacheFreed(formatBytes(freedBytes, localeTag(context))),
            style: AppType.digits(
              AppType.footnote,
            ).copyWith(color: theme.settings.toggleActive, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      ClearFace.nothing => Text(l10n.cacheNothingToClear, style: quiet),
    };
    // The seat's width eases as its face changes, so the label beside it
    // reflows once instead of jumping; the faces swap like the model sheet's
    // marks, the old shrinking away as the new grows in.
    return AnimatedSize(
      duration: context.reduceMotion ? AppMotion.instant : motion.indicator,
      curve: motion.indicatorCurve,
      alignment: AlignmentDirectional.centerEnd,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: motion.indicatorCurve,
        switchOutCurve: motion.indicatorCurve,
        layoutBuilder: (current, previous) =>
            Stack(alignment: AlignmentDirectional.centerEnd, children: [...previous, ?current]),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: _replaceScale, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(face), child: seat),
      ),
    );
  }

  /// How small a face shrinks to on its way out, and grows from on its way in.
  static const double _replaceScale = 0.5;
}

/// The clear itself: a danger-tinted pill, quiet enough to sit in a row, that
/// asks before it deletes anything.
class _ClearPill extends StatelessWidget {
  const _ClearPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final height = theme.button.bandHeight;
    return Semantics(
      button: true,
      child: Touchable(
        onTap: onTap,
        haptic: true,
        pressedScale: theme.motion.pressIconScale,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: SuperellipseDecoration(
            borderRadius: height / 2,
            color: theme.settings.dangerIconTint,
          ),
          child: Text(
            label,
            style: AppType.footnote.copyWith(color: theme.danger, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
