import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/core/utils/platform_caps.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The app's segmented control, adaptive like every other native control: the
/// Liquid Glass `UISegmentedControl` on iOS 26, and the app's drawn pill
/// everywhere else. The single source both the appearance mode picker and the
/// reflections period switcher draw from, so they read and behave as one
/// control.
///
/// [segments] pairs each value with its label, in display order; [selected]
/// must be one of them. Widths are equal, so keep labels short. It fills the
/// width it is given; wrap it to size the native platform view where
/// constraints are loose, e.g. a bar title.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = defaultHeight,
    super.key,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// The control's height. Defaults to [defaultHeight]; a compact slot (a bar
  /// title) passes a shorter one.
  final double height;

  static const defaultHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final drawn = _DrawnSegmentedControl<T>(
      segments: segments,
      selected: selected,
      onChanged: onChanged,
      height: height,
    );
    if (!PlatformCaps.nativeGlass) return drawn;

    final theme = context.theme;
    final index = segments.indexWhere((s) => s.$1 == selected);
    return SizedBox(
      height: height,
      child: LiquidSegmentedControl(
        segments: [for (final (_, label) in segments) label],
        selectedIndex: index < 0 ? 0 : index,
        // UISegmentedControl gives no haptic of its own; the drawn pill
        // buzzes, so the glass one must too.
        onSelected: (i) {
          Haptics.selection();
          onChanged(segments[i].$1);
        },
        isDark: theme.brightness == Brightness.dark,
        selectedTintColor: theme.accent,
        labelColor: theme.textSecondary,
        selectedLabelColor: theme.onAccent,
        placeholderBuilder: (_) => drawn,
      ),
    );
  }
}

/// The drawn pill: equal-width segments with an accent fill that slides to the
/// selected one (jumping under Reduce Motion). The fallback below iOS 26, and
/// the stand-in while a route covers the native control.
class _DrawnSegmentedControl<T> extends StatelessWidget {
  const _DrawnSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.height,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

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
                        child: Semantics(
                          button: true,
                          selected: value == selected,
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
