import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The inline error indicator: a quiet surface pill carrying a short [message],
/// a danger dot that breathes to draw the eye, and a chevron that says a tap
/// opens the full story. No colour shout, no auto-dismiss, no snackbar - it sits
/// in the layout until the failure is resolved and answers a tap with details.
class ErrorPill extends StatefulWidget {
  const ErrorPill({required this.message, required this.onTap, super.key});

  final String message;
  final VoidCallback onTap;

  @override
  State<ErrorPill> createState() => _ErrorPillState();
}

class _ErrorPillState extends State<ErrorPill> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.errorPill;

    // The breath: a slow ease-in-out pulse of the dot's opacity. Held still (and
    // fully lit) under Reduce Motion, where a blink is exactly what to drop.
    final reduce = context.reduceMotion;
    _controller.duration = theme.motion.errorBlink;
    if (reduce) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    return Touchable(
      onTap: widget.onTap,
      haptic: true,
      child: Container(
        height: tokens.height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: SuperellipseDecoration(
          borderRadius: tokens.radius,
          color: tokens.background,
          border: BorderSide(color: tokens.border),
        ),
        child: Row(
          children: [
            _Dot(controller: _controller, color: tokens.dot, size: tokens.dotSize, reduce: reduce),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                widget.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.subhead.copyWith(color: tokens.text),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppIcon(AppIcons.chevronForward, size: 14, color: tokens.chevron),
          ],
        ),
      ),
    );
  }
}

/// The breathing dot. A [FadeTransition] driven by the shared controller, so the
/// pulse costs no rebuilds; its floor is the theme's [ErrorPillTheme.blinkMinOpacity].
class _Dot extends StatelessWidget {
  const _Dot({
    required this.controller,
    required this.color,
    required this.size,
    required this.reduce,
  });

  final AnimationController controller;
  final Color color;
  final double size;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (reduce) return dot;
    return FadeTransition(
      opacity: controller.drive(
        Tween(
          begin: 1.0,
          end: context.theme.errorPill.blinkMinOpacity,
        ).chain(CurveTween(curve: Curves.easeInOut)),
      ),
      child: dot,
    );
  }
}
