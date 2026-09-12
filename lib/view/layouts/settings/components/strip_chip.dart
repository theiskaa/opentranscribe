import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Whether a chip's download shows a spinner rather than its ring: no
/// fraction yet, or a preparing tail with none to show, is an indeterminate
/// wait, and an empty or full ring reads as stalled.
bool chipProgressSpins(double fraction, {bool preparing = false}) => fraction <= 0 || preparing;

/// One chip of the transcription screen's strips, the languages' and the
/// models': a surface squircle around whatever [child] says. A null [onTap]
/// leaves it a quiet, unpressable chip.
class StripChip extends StatelessWidget {
  const StripChip({required this.child, required this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  /// Between a chip's parts, off the spacing scale on purpose: sm reads airy.
  static const double innerGap = 6;

  /// Off the spacing scale on purpose: md-tall chips read as buttons.
  static const double _verticalPad = 9;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return Touchable(
      onTap: onTap,
      haptic: onTap != null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: _verticalPad),
        decoration: SuperellipseDecoration(
          borderRadius: AppRadius.chip,
          color: tokens.cardBackground,
        ),
        child: child,
      ),
    );
  }
}

/// A downloading chip's trailing mark: its ring, or a spinner while
/// [chipProgressSpins] says the wait has no fraction to show.
class StripChipProgress extends StatelessWidget {
  const StripChipProgress({required this.fraction, this.preparing = false, super.key});

  final double fraction;
  final bool preparing;

  static const double _size = 12;

  @override
  Widget build(BuildContext context) {
    final ink = context.theme.textSecondary;
    return chipProgressSpins(fraction, preparing: preparing)
        ? AppSpinner(size: _size, color: ink)
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
