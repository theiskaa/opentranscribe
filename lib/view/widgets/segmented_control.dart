import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/glass_scope.dart';
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
    if (!GlassScope.nativeOf(context)) return drawn;

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
class _DrawnSegmentedControl<T> extends StatefulWidget {
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

  @override
  State<_DrawnSegmentedControl<T>> createState() => _DrawnSegmentedControlState<T>();
}

class _DrawnSegmentedControlState<T> extends State<_DrawnSegmentedControl<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: _index.toDouble(),
  );

  int get _index => widget.segments.indexWhere((s) => s.$1 == widget.selected);

  /// The segment the thumb is headed for, so a rebuild mid-slide keeps its
  /// course instead of restarting it.
  late int _target = _index;

  @override
  void didUpdateWidget(_DrawnSegmentedControl<T> old) {
    super.didUpdateWidget(old);
    final index = _index;
    if (index < 0 || index == _target) return;
    _target = index;
    if (context.reduceMotion) {
      _position.value = index.toDouble();
      return;
    }
    final motion = context.motionNow;
    unawaited(
      _position.animateTo(
        index.toDouble(),
        duration: motion.indicator,
        curve: motion.indicatorCurve,
      ),
    );
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DrawnSegments(
      labels: [for (final (_, label) in widget.segments) label],
      position: _position,
      thumbShown: _index >= 0,
      height: widget.height,
      onTap: (i) {
        Haptics.selection();
        widget.onChanged(widget.segments[i].$1);
      },
    );
  }
}

/// The drawn pill at a thumb [position] in segments (1.5 is halfway from the
/// second to the third): equal-width segments, the accent thumb wherever the
/// position is, and the nearer segment's label inked. The one drawing behind
/// the drawn [AppSegmentedControl] and the engine switcher, whose thumb
/// follows a finger, so the two read as one control. With [onDragUpdate] the
/// pill also takes a horizontal drag, reported in segments.
class DrawnSegments extends StatelessWidget {
  const DrawnSegments({
    required this.labels,
    required this.position,
    required this.onTap,
    this.height = AppSegmentedControl.defaultHeight,
    this.thumbShown = true,
    this.dimmed = const {},
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    super.key,
  });

  final List<String> labels;
  final Animation<double> position;
  final ValueChanged<int> onTap;
  final double height;

  /// False while no segment is selected.
  final bool thumbShown;

  /// Segments kept but quieter, for a choice this phone cannot take.
  final Set<int> dimmed;

  final VoidCallback? onDragStart;

  /// Travel in segments since the last update.
  final ValueChanged<double>? onDragUpdate;

  /// Release velocity in segments per second.
  final ValueChanged<double>? onDragEnd;
  final VoidCallback? onDragCancel;

  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final last = (labels.length - 1).toDouble();
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
            final segment = constraints.maxWidth / labels.length;
            final pill = AnimatedBuilder(
              animation: position,
              builder: (context, _) {
                // A track may rubber-band past an end; the thumb stays inside
                // the pill.
                final at = position.value.clamp(0.0, last);
                final inked = thumbShown ? at.round() : -1;
                return Stack(
                  children: [
                    if (thumbShown)
                      Positioned(
                        left: at * segment + _inset,
                        top: _inset,
                        bottom: _inset,
                        width: segment - 2 * _inset,
                        child: DecoratedBox(
                          decoration: SuperellipseDecoration(
                            borderRadius: (height - 2 * _inset) / 2,
                            color: theme.accent,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        for (final (i, label) in labels.indexed)
                          Expanded(
                            child: _Segment(
                              label: label,
                              inked: i == inked,
                              dimmed: dimmed.contains(i),
                              onTap: () => onTap(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            );
            final update = onDragUpdate;
            if (update == null) return pill;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => onDragStart?.call(),
              onHorizontalDragUpdate: (details) => update(details.primaryDelta! / segment),
              onHorizontalDragEnd: (details) => onDragEnd?.call(details.primaryVelocity! / segment),
              onHorizontalDragCancel: onDragCancel,
              child: pill,
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.inked,
    required this.dimmed,
    required this.onTap,
  });

  final String label;
  final bool inked;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Semantics(
      button: true,
      selected: inked,
      child: Touchable(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.subhead.copyWith(
              color: inked
                  ? theme.onAccent
                  : dimmed
                  ? theme.dimmedText
                  : theme.textSecondary,
              fontWeight: inked ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
