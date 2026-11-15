import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_loader.dart';
import 'package:opentranscribe/view/widgets/export_l10n.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/morph_control.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// One export format: its mark, its name, and a line saying what the files
/// are. It exports in one tap and runs in place: the loader, the percent and
/// the cancel disc in its trailing seat, and the outcome in its own note line.
class ExportFormatRow extends StatelessWidget {
  const ExportFormatRow({
    required this.descriptor,
    required this.onTap,
    this.note,
    this.noteTone = NoteTone.quiet,
    this.running = false,
    this.waiting = false,
    this.fraction,
    this.onCancel,
    this.cancelSemanticLabel,
    super.key,
  }) : assert(onCancel == null || cancelSemanticLabel != null);

  final ExporterDescriptor descriptor;

  /// Null disables the row: its name and mark dim on the indicator clock, so
  /// a dead action never looks tappable. A running row has no tap either, but
  /// reports rather than dims.
  final VoidCallback? onTap;

  /// An outcome in place of the format's own line, inked by [noteTone].
  final String? note;
  final NoteTone noteTone;

  /// This row's export is under way: taps rest and the trailing seat opens.
  final bool running;

  /// The files are built and the share sheet waits on the user: the seat
  /// closes, since nothing is working any more.
  final bool waiting;

  /// How far the pack has come, 0 to 1; null while there is no measure,
  /// which is also when there is nothing to cancel.
  final double? fraction;

  final VoidCallback? onCancel;
  final String? cancelSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final copy = exportFormatCopy(AppLocalizations.of(context)!, descriptor.format);
    final theme = context.theme;
    final tokens = theme.settings;
    final tap = running ? null : onTap;
    final dimmed = onTap == null && !running;
    final duration = context.reduceMotion ? Duration.zero : theme.motion.indicator;
    return Touchable(
      onTap: tap,
      haptic: tap != null,
      child: Padding(
        padding: tokens.rowPadding,
        child: Row(
          children: [
            SettingsIconTile(
              // Faded whole rather than re-inked: a branded mark keeps
              // its own colors, so only its strength can follow the name.
              child: AnimatedOpacity(
                opacity: dimmed ? theme.button.disabledOpacity : 1,
                duration: duration,
                curve: theme.motion.indicatorCurve,
                child: ExporterLogo(descriptor),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SettingsLabelAndNote(
                // The format's own line is one line; an outcome is a
                // sentence and wraps.
                oneLine: note == null,
                note: note ?? copy.note,
                noteColor: noteToneInk(theme, noteTone),
                label: SettingsRowLabel(
                  copy.name,
                  color: dimmed ? theme.textSecondary : theme.text,
                  oneLine: true,
                ),
              ),
            ),
            _RunSeat(
              running: running && !waiting,
              fraction: fraction,
              onCancel: onCancel,
              cancelSemanticLabel: cancelSemanticLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// The trailing seat a running row opens: the loader throughout, joined by
/// the percent and the cancel disc while the pack has a measure. It widens on
/// the indicator motion, so the label column gives way rather than jumping.
class _RunSeat extends StatelessWidget {
  const _RunSeat({
    required this.running,
    required this.fraction,
    required this.onCancel,
    required this.cancelSemanticLabel,
  });

  final bool running;
  final double? fraction;
  final VoidCallback? onCancel;
  final String? cancelSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final motion = theme.motion;
    final duration = context.reduceMotion ? Duration.zero : motion.indicator;
    final fraction = this.fraction;
    final measured = running && fraction != null;
    final cancel = onCancel;
    return AnimatedSize(
      duration: duration,
      curve: motion.indicatorCurve,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: motion.indicatorCurve,
        switchOutCurve: motion.indicatorCurve.flipped,
        // Keyed by shape, not by percent: the figures change in place.
        child: !running
            ? const SizedBox.shrink(key: ValueKey(0))
            : Padding(
                key: ValueKey(measured ? 2 : 1),
                padding: const EdgeInsets.only(left: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLoader(size: AppIconSize.tile, color: theme.textSecondary),
                    if (measured) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatPercent(fraction, localeTag(context)),
                        style: AppType.digits(AppType.subhead).copyWith(color: theme.textSecondary),
                      ),
                      if (cancel != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        CancelDisc(semanticLabel: cancelSemanticLabel, onTap: cancel),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// A format's mark at chip size, for any row that puts one in a settings tile.
/// Each mark is normalized in its own asset, on a square canvas that pads it
/// to equal ink against the others, so this stays one square box for every
/// format instead of a table of per-mark sizes. A branded mark keeps its own
/// colors; a monochrome one paints in `currentColor`, which resolves to the
/// text ink here so it never sinks into a light or a dark card.
class ExporterLogo extends StatelessWidget {
  const ExporterLogo(this.descriptor, {super.key});

  final ExporterDescriptor descriptor;

  /// Chip size. Sits inside the row's icon tile with its own margin, and larger
  /// than the flag a language row puts there because a mark is line art, not a
  /// filled glyph.
  static const _size = 22.0;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      descriptor.logo,
      width: _size,
      height: _size,
      theme: SvgTheme(currentColor: context.theme.text),
    );
  }
}
