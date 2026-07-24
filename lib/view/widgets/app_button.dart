import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

enum AppButtonVariant { primary, secondary, danger }

/// The general button: full-width squircle pill, scale-press with a light
/// haptic, animated disabled state, and a loading state that holds the fill.
/// Dark fills get the machined treatment (top sheen and a soft drop shadow).
class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.height,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// Optional leading glyph, colored with the label.
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final double? height;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 0.96,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  bool _pressed = false;

  bool get _interactive => widget.onPressed != null && !widget.isLoading;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!_interactive) return;
    Haptics.light();
    setState(() => _pressed = true);
    _controller.forward();
  }

  void _release() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final button = theme.button;
    final (background, pressed, foreground, border) = switch (widget.variant) {
      AppButtonVariant.primary => (
        button.background,
        button.pressed,
        button.foreground,
        BorderSide.none,
      ),
      AppButtonVariant.secondary => (
        button.secondaryBackground,
        button.secondaryPressed,
        button.secondaryForeground,
        BorderSide(color: button.secondaryBorder),
      ),
      AppButtonVariant.danger => (theme.danger, theme.danger, theme.onAccent, BorderSide.none),
    };
    final disabled = widget.onPressed == null && !widget.isLoading;
    final fill = widget.isLoading ? background : (_pressed ? pressed : background);
    // Ink pills get the machined treatment; light fills stay flat.
    final inkFill = fill.computeLuminance() < 0.35;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: _interactive ? widget.onPressed : null,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: disabled ? button.disabledOpacity : 1,
          child: Container(
            height: widget.height ?? button.height,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            decoration: SuperellipseDecoration(
              borderRadius: button.radius,
              color: inkFill ? null : fill,
              gradient: inkFill
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.25],
                      colors: [Color.alphaBlend(button.sheen, fill), fill],
                    )
                  : null,
              shadows: inkFill && !disabled ? [button.shadow] : null,
              border: border,
            ),
            child: Center(
              child: widget.isLoading
                  ? AppSpinner(color: foreground)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          AppIcon(widget.icon!, size: 18, color: foreground),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text(widget.label, style: AppType.callout.copyWith(color: foreground)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular icon press: the secondary-surface treatment at icon size, with a
/// hairline and a shadow soft enough to separate it from whatever scrolls
/// under it. Every round control that is not the native glass button is this
/// one: the recorder flanks, and the bar buttons wherever glass is unavailable.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onTap,
    this.size = 52,
    this.iconSize = 20,
    this.foreground,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Touchable(
      onTap: onTap,
      pressedScale: theme.motion.pressIconScale,
      haptic: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.button.secondaryBackground,
          shape: BoxShape.circle,
          // No shadow. A filled circle with a hairline is already a defined
          // object; a cast under it only makes the page look lit, and the app
          // is flat everywhere else.
          border: Border.all(color: theme.button.secondaryBorder),
        ),
        child: Center(
          child: AppIcon(icon, size: iconSize, color: foreground ?? theme.text),
        ),
      ),
    );
  }
}
