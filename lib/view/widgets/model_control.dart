import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:transcriber/transcriber.dart';

/// What a model's control means, folded in priority: a download in flight,
/// then a failure, then too heavy while absent, then present or not.
enum ModelRowFace { installing, failed, heavy, download, selected, installed }

ModelRowFace modelRowFace(ModelRowState row) {
  if (row.installing) return ModelRowFace.installing;
  if (row.failure != null) return ModelRowFace.failed;
  if (!row.installed) return row.heavy ? ModelRowFace.heavy : ModelRowFace.download;
  return row.selected ? ModelRowFace.selected : ModelRowFace.installed;
}

/// Whether a model offers its trash: never on the model in use (emptying the
/// seat runs start from is a trap), unless it would not open, when removing
/// it is the way out.
bool modelRowRemovable(ModelRowState row) => switch (modelRowFace(row)) {
  ModelRowFace.installed => true,
  ModelRowFace.failed => row.installed && row.failure == ModelInstallReason.loadFailed,
  _ => false,
};

/// What the bar reads while a download runs: how full it is, and the word in
/// it. The fill follows the shown percent rather than the raw fraction, so a
/// bar and its number never disagree.
({double fill, String label}) progressFace(
  AppLocalizations l10n, {
  required bool queued,
  required bool preparing,
  required double? fraction,
}) {
  if (queued) return (fill: 0, label: l10n.modelQueued);
  if (preparing) return (fill: 1, label: l10n.modelPreparing);
  final percent = percentOf(fraction);
  return (fill: percent / 100, label: '$percent%');
}

/// A pill face's words and glyph; the bar faces draw [progressFace] instead.
({IconData? icon, String text}) _pillWords(AppLocalizations l10n, ModelRowFace face) =>
    switch (face) {
      ModelRowFace.download ||
      ModelRowFace.heavy => (icon: AppIcons.icloud, text: l10n.modelDownload),
      ModelRowFace.failed => (icon: AppIcons.arrowCounterclockwise, text: l10n.retry),
      ModelRowFace.installed => (icon: null, text: l10n.modelUse),
      ModelRowFace.selected => (icon: AppIcons.checkmark, text: l10n.modelInUse),
      ModelRowFace.installing => throw ArgumentError.value(face, 'face', 'a bar, not a pill'),
    };

/// The words on every face; a bar's take tabular figures.
final TextStyle _labelStyle = AppType.footnote.copyWith(fontWeight: FontWeight.w600);

/// A model's control: one pill whose fill and words follow the face on
/// the indicator motion, and, while a download runs, the pill IS its progress
/// bar, filling from the left under a centred percent. The cancel disc rides
/// beside it in a seat that opens on the same motion, so the bar's width and
/// its words change together. One VoiceOver name carries the face and the
/// model, the percent folded in.
class ModelControl extends StatelessWidget {
  const ModelControl({
    required this.row,
    required this.face,
    required this.onTap,
    required this.onCancel,
    super.key,
  });

  /// The glyph beside a pill's words.
  static const double _glyphSize = 14;

  final ModelRowState row;
  final ModelRowFace face;

  /// What the pill does, or null for a face that only reports.
  final VoidCallback? onTap;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Pill(row: row, face: face, onTap: onTap),
        ),
        _CancelSeat(
          shown: row.cancellable && !row.preparing,
          modelName: row.option.displayName,
          onTap: onCancel,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.row, required this.face, required this.onTap});

  final ModelRowState row;
  final ModelRowFace face;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final button = theme.button;
    final l10n = AppLocalizations.of(context)!;
    final motion = context.motionNow;
    final duration = context.reduceMotion ? Duration.zero : motion.indicator;
    final name = row.option.displayName;
    // The solid fill goes to what fetches: a model already here is one quiet
    // tap from use, and must not outshout a download in the same list.
    final (fill, border, ink) = switch (face) {
      ModelRowFace.download ||
      ModelRowFace.failed => (button.background, button.background, button.foreground),
      // The toggle's green already means on.
      ModelRowFace.selected => (
        theme.settings.toggleActive.withValues(alpha: 0.14),
        theme.settings.toggleActive.withValues(alpha: 0.14),
        theme.settings.toggleActive,
      ),
      _ => (button.secondaryBackground, button.secondaryBorder, button.secondaryForeground),
    };
    final semanticLabel = switch (face) {
      ModelRowFace.installing when row.queued => l10n.modelQueuedLabel(name),
      ModelRowFace.installing when row.preparing => l10n.modelPreparingLabel(name),
      ModelRowFace.installing => l10n.modelDownloadingLabel(name, percentOf(row.installFraction)),
      ModelRowFace.download => l10n.modelDownloadButton(name),
      ModelRowFace.failed => l10n.modelRetryButton(name),
      ModelRowFace.installed => l10n.modelUseButton(name),
      ModelRowFace.selected => l10n.modelInUseLabel(name),
      ModelRowFace.heavy => l10n.modelTooHeavyLabel(name),
    };
    final content = switch (face) {
      // One bar across the whole download, so its sweep runs from the queue
      // through the percent into the preparing tail.
      ModelRowFace.installing => _ProgressBar(
        face: progressFace(
          l10n,
          queued: row.queued,
          preparing: row.preparing,
          fraction: row.installFraction,
        ),
        fill: button.background,
        trackInk: button.secondaryForeground,
        fillInk: button.foreground,
      ),
      _ => _PillWords(
        words: _pillWords(l10n, face),
        ink: face == ModelRowFace.heavy ? theme.textSecondary : ink,
      ),
    };
    return Semantics(
      button: onTap != null,
      // A face that only reports is a state, not a disabled button.
      enabled: onTap != null ? true : null,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Touchable(
        onTap: onTap,
        haptic: onTap != null,
        pressedScale: theme.motion.pressIconScale,
        child: AnimatedContainer(
          duration: duration,
          curve: motion.indicatorCurve,
          height: button.bandHeight,
          decoration: SuperellipseDecoration(
            borderRadius: button.bandHeight / 2,
            color: fill,
            border: BorderSide(color: border),
          ),
          // The words ride the same duration and curve as the fill and the
          // cancel's seat, so a face change moves as one.
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: motion.indicatorCurve,
            switchOutCurve: motion.indicatorCurve,
            layoutBuilder: meltStack,
            child: KeyedSubtree(
              key: ValueKey(face),
              // The bar paints its own fill edge to edge; every other face is
              // words inside the pill's inset.
              child: face == ModelRowFace.installing
                  ? content
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Center(child: content),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The download as the control itself: the pill fills from the left as the
/// bytes land, its word centred and legible over both halves (the same text
/// twice, the filled copy clipped to the sweep).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.face,
    required this.fill,
    required this.trackInk,
    required this.fillInk,
  });

  final ({double fill, String label}) face;
  final Color fill;
  final Color trackInk;
  final Color fillInk;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: face.fill.clamp(0.0, 1.0)),
      duration: context.reduceMotion ? Duration.zero : theme.motion.indicator,
      curve: theme.motion.indicatorCurve,
      builder: (context, value, _) => ClipPath(
        clipper: ShapeBorderClipper(shape: Superellipse(radius: theme.button.bandHeight / 2)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BarWords(label: face.label, ink: trackInk),
            ClipRect(
              clipper: _Sweep(value),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: fill),
                  _BarWords(label: face.label, ink: fillInk),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarWords extends StatelessWidget {
  const _BarWords({required this.label, required this.ink});

  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppType.digits(_labelStyle).copyWith(color: ink),
        ),
      ),
    );
  }
}

/// Keeps the left [fraction] of the bar, the sweep a filling one makes.
class _Sweep extends CustomClipper<Rect> {
  const _Sweep(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_Sweep old) => old.fraction != fraction;
}

/// The cancel's seat beside the bar: it opens and closes on the pill's own
/// motion, so the bar's width and its words change together rather than the
/// disc popping in and shoving the bar aside.
class _CancelSeat extends StatelessWidget {
  const _CancelSeat({required this.shown, required this.modelName, required this.onTap});

  final bool shown;
  final String modelName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final motion = context.motionNow;
    final size = theme.button.bandHeight;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: shown ? 1 : 0),
      duration: context.reduceMotion ? Duration.zero : motion.indicator,
      curve: motion.indicatorCurve,
      builder: (context, open, child) => SizedBox(
        width: (size + AppSpacing.sm) * open,
        height: size,
        // The disc keeps its own size while the seat narrows, and shrinks
        // from the seat's own edge rather than sliding over the bar.
        child: OverflowBox(
          minWidth: size,
          maxWidth: size,
          minHeight: size,
          maxHeight: size,
          alignment: Alignment.centerRight,
          child: Transform.scale(
            scale: open,
            alignment: Alignment.centerRight,
            // A closed seat is not a control: its disc leaves the semantics
            // tree with it.
            child: ExcludeSemantics(excluding: !shown, child: child),
          ),
        ),
      ),
      child: _CancelButton(modelName: modelName, onTap: onTap),
    );
  }
}

/// Stops the download the bar is showing: a danger-tinted disc beside it,
/// the same height as the bar so the pair reads as one control.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.modelName, required this.onTap});

  final String modelName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final size = theme.button.bandHeight;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.modelCancelDownloadButton(modelName),
      onTap: onTap,
      excludeSemantics: true,
      child: Touchable(
        onTap: onTap,
        haptic: true,
        pressedScale: theme.motion.pressIconScale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.danger.withValues(alpha: 0.14),
          ),
          child: Center(
            child: AppIcon(AppIcons.xmark, size: ModelControl._glyphSize, color: theme.danger),
          ),
        ),
      ),
    );
  }
}

/// A pill's words: an optional glyph and the label, in the pill's ink.
class _PillWords extends StatelessWidget {
  const _PillWords({required this.words, required this.ink});

  final ({IconData? icon, String text}) words;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final icon = words.icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          AppIcon(icon, size: ModelControl._glyphSize, color: ink),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            words.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle.copyWith(color: ink),
          ),
        ),
      ],
    );
  }
}
