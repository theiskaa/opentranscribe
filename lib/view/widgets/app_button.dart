import 'package:flutter/cupertino.dart';

import 'package:opentranscribe/core/theming/app_theme.dart';

enum AppButtonVariant { filled, plain, danger }

/// A themed tappable button. No Material ink; Cupertino press opacity.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final filled = variant == AppButtonVariant.filled;
    final foreground = switch (variant) {
      AppButtonVariant.filled => colors.onAccent,
      AppButtonVariant.plain => colors.accent,
      AppButtonVariant.danger => colors.danger,
    };

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(label, style: AppText.button(context).copyWith(color: foreground)),
      ],
    );

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      color: filled ? colors.accent : null,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: content,
    );
  }
}
