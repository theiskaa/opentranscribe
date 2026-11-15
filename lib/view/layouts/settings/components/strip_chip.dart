import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_loader.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Whether a chip's download shows a loader rather than its ring: no
/// fraction yet, or a preparing tail with none to show, is an indeterminate
/// wait, and an empty or full ring reads as stalled.
bool chipProgressWaits(double fraction, {bool preparing = false}) => fraction <= 0 || preparing;

/// One chip of the transcription screen's strips, the languages' and the
/// models': a surface squircle around whatever [child] says. A null [onTap]
/// leaves it a quiet, unpressable chip.
class StripChip extends StatelessWidget {
  const StripChip({required this.child, required this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  /// Between a chip's parts, off the spacing scale on purpose: sm reads airy.
  static const double innerGap = 6;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return Touchable(
      onTap: onTap,
      haptic: onTap != null,
      // One height for every chip whatever it holds (a flag's line is taller
      // than a word's); a minimum, so larger text still grows it.
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.chip),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: SuperellipseDecoration(
          borderRadius: AppRadius.chip,
          color: tokens.cardBackground,
        ),
        // Hugs its content sideways; a bare alignment would fill the strip.
        child: Center(widthFactor: 1, child: child),
      ),
    );
  }
}

/// A downloading chip's trailing mark: its ring, or a loader while
/// [chipProgressWaits] says the wait has no fraction to show.
class StripChipProgress extends StatelessWidget {
  const StripChipProgress({required this.fraction, this.preparing = false, super.key});

  final double fraction;
  final bool preparing;

  static const double _size = 12;

  @override
  Widget build(BuildContext context) {
    final ink = context.theme.textSecondary;
    return chipProgressWaits(fraction, preparing: preparing)
        ? AppLoader(size: _size, color: ink)
        : ProgressRing(fraction: fraction, size: _size);
  }
}

/// The strip's trailing door into its sheet: "+ [label]" in the accent.
class StripChipMore extends StatelessWidget {
  const StripChipMore({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return StripChip(
      onTap: onTap,
      // A text plus, not a glyph: the vendored SF subset carries no plus,
      // and one character does not earn a font regeneration.
      child: Text(
        '+ $label',
        style: AppType.footnote.copyWith(color: theme.accent, fontWeight: FontWeight.w600),
      ),
    );
  }
}
