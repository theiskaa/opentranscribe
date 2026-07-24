import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The recorder's controls: four circles of one size, split into what you do
/// to the take and what ENDS it. Close, restart and pause group at the left;
/// complete sits alone on the right behind a short rule, because it is the only
/// one of the four that cannot be undone by tapping again. Circles because this
/// is a machine you operate, not a form you submit, and every way out of the
/// screen is here, under the thumb - which is why the top bar carries nothing
/// but the clock.
class RecorderControls extends StatelessWidget {
  const RecorderControls({
    required this.paused,
    required this.saving,
    required this.onClose,
    required this.onRestart,
    required this.onComplete,
    required this.onTogglePause,
    super.key,
  });

  final bool paused;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onRestart;
  final VoidCallback onComplete;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.recorder;
    final size = tokens.controlSize;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Flank(icon: AppIcons.xmark, onTap: saving ? null : onClose, size: size),
        const SizedBox(width: AppSpacing.md),
        _Flank(icon: AppIcons.arrowCounterclockwise, onTap: saving ? null : onRestart, size: size),
        const SizedBox(width: AppSpacing.md),
        _Flank(
          icon: paused ? AppIcons.playFill : AppIcons.pauseFill,
          onTap: saving ? null : onTogglePause,
          size: size,
        ),
        // Wider than the gaps inside the group, and no wider: the rule is what
        // separates the two, so the air only has to confirm it. Measured, not
        // whatever is left over - pushing complete to the screen's edge opens a
        // gulf the eye reads as a missing button.
        const SizedBox(width: AppSpacing.xl),
        _Seam(height: size / 2),
        const SizedBox(width: AppSpacing.xl),
        _CompleteButton(size: size, saving: saving, onTap: onComplete),
      ],
    );
  }
}

/// The rule between the take's controls and the one that ends it. Short: it
/// divides two groups on one row, and a full-height rule would read as a border
/// around the button it sits beside.
class _Seam extends StatelessWidget {
  const _Seam({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: height,
      child: ColoredBox(color: context.theme.hairline),
    );
  }
}

/// A flanking control: the app's circular icon press, faded out while the take
/// is being saved so the centre carries the moment alone.
class _Flank extends StatelessWidget {
  const _Flank({required this.icon, required this.onTap, required this.size});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AnimatedOpacity(
      duration: theme.motion.crossfade,
      opacity: onTap == null ? theme.button.disabledOpacity : 1,
      child: AppIconButton(icon: icon, onTap: onTap, size: size),
    );
  }
}

/// The button that ends the take: the primary fill, round. Ink fills get the
/// same machined treatment [AppButton] gives them (a top sheen and a soft
/// shadow), so the app has one primary surface in two shapes.
class _CompleteButton extends StatelessWidget {
  const _CompleteButton({required this.size, required this.saving, required this.onTap});

  final double size;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final button = theme.button;
    final fill = button.background;
    final ink = fill.computeLuminance() < 0.35;

    return Touchable(
      onTap: saving ? null : onTap,
      pressedScale: theme.motion.pressScale,
      haptic: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ink ? null : fill,
          gradient: ink
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.25],
                  colors: [Color.alphaBlend(button.sheen, fill), fill],
                )
              : null,
          boxShadow: ink ? [button.shadow] : null,
        ),
        child: Center(
          child: saving
              ? AppSpinner(color: button.foreground)
              : AppIcon(AppIcons.checkmark, size: size / 3, color: button.foreground),
        ),
      ),
    );
  }
}
