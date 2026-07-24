import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The recorder's controls: three circles, the middle one twice the weight of
/// its flanks. Circles because this is a machine you operate, not a form you
/// submit - restart and pause flank the one button that ends the take.
class RecorderControls extends StatelessWidget {
  const RecorderControls({
    required this.paused,
    required this.saving,
    required this.onRestart,
    required this.onComplete,
    required this.onTogglePause,
    super.key,
  });

  final bool paused;
  final bool saving;
  final VoidCallback onRestart;
  final VoidCallback onComplete;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.recorder;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Flank(
          icon: AppIcons.arrowCounterclockwise,
          onTap: saving ? null : onRestart,
          size: tokens.controlSize,
        ),
        _CompleteButton(size: tokens.completeSize, saving: saving, onTap: onComplete),
        _Flank(
          icon: paused ? AppIcons.playFill : AppIcons.pauseFill,
          onTap: saving ? null : onTogglePause,
          size: tokens.controlSize,
        ),
      ],
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
