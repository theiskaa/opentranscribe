import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// A horizontal segmented control: one pill holding equal-width segments, with
/// an accent fill that slides to the selected one (jumping under Reduce Motion).
/// The single source both the appearance mode picker and the reflections period
/// switcher draw from, so they read and behave as one control.
///
/// [segments] pairs each value with its label, in display order; [selected]
/// must be one of them. Widths are equal, so keep labels short.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// The control's fixed height, so a floating caller can inset content past it.
  static const height = 40.0;
  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final reduce = context.reduceMotion;
    final index = segments.indexWhere((s) => s.$1 == selected);

    return DecoratedBox(
      decoration: SuperellipseDecoration(
        borderRadius: height / 2,
        color: theme.surface,
        border: BorderSide(color: theme.surfaceBorder),
      ),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segWidth = constraints.maxWidth / segments.length;
            return Stack(
              children: [
                if (index >= 0)
                  AnimatedPositioned(
                    duration: reduce ? Duration.zero : theme.motion.indicator,
                    curve: theme.motion.indicatorCurve,
                    left: index * segWidth + _inset,
                    top: _inset,
                    bottom: _inset,
                    width: segWidth - 2 * _inset,
                    child: DecoratedBox(
                      decoration: SuperellipseDecoration(
                        borderRadius: (height - 2 * _inset) / 2,
                        color: theme.accent,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (final (value, label) in segments)
                      Expanded(
                        child: Touchable(
                          onTap: () {
                            Haptics.selection();
                            onChanged(value);
                          },
                          child: Center(
                            child: Text(
                              label,
                              style: AppType.subhead.copyWith(
                                color: value == selected ? theme.onAccent : theme.textSecondary,
                                fontWeight: value == selected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
