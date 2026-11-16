import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

class HomeNavigationRow extends StatefulWidget {
  const HomeNavigationRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<HomeNavigationRow> createState() => _HomeNavigationRowState();
}

class _HomeNavigationRowState extends State<HomeNavigationRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        selected: widget.selected,
        child: Touchable(
          onTap: widget.onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.minTarget),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: SuperellipseDecoration(
              color: widget.selected
                  ? theme.duo.pressedFill
                  : _focused
                  ? theme.duo.pressedFill
                  : null,
              borderRadius: DuoTheme.groupRadius,
              border: _focused ? BorderSide(color: theme.accent) : BorderSide.none,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: AppSpacing.xxl,
                  child: widget.icon == null
                      ? null
                      : AppIcon(
                          widget.icon!,
                          size: AppIconSize.body,
                          color: widget.selected ? theme.accent : theme.textSecondary,
                        ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.label,
                    style: AppType.body.copyWith(
                      color: theme.text,
                      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
