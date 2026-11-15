import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';

bool paneGlides({
  required PaneLayout previous,
  required PaneLayout next,
  required bool supported,
  required bool previouslySettled,
  required bool settled,
  required bool cover,
  required bool reduceMotion,
}) =>
    supported &&
    previouslySettled &&
    settled &&
    !cover &&
    !reduceMotion &&
    (next.mode == PaneMode.split ||
        next.recorder.arrangement != RecorderArrangement.column ||
        next.fold != null) &&
    previous.mode == next.mode &&
    previous.recorder.arrangement == next.recorder.arrangement &&
    previous.fold == next.fold;

PaneLayout interpolatePanes(PaneLayout from, PaneLayout to, double t) {
  if (t == 0) return from;
  if (t == 1) return to;
  Pane pane(Pane a, Pane b) => Pane(
    rect: Rect.lerp(a.rect, b.rect, t)!,
    padding: EdgeInsets.lerp(a.padding, b.padding, t)!,
    barToSideColumn: b.barToSideColumn,
  );
  return PaneLayout(
    mode: to.mode,
    leading: pane(from.leading, to.leading),
    detail: pane(from.detail, to.detail),
    recorder: RecorderLayout(
      arrangement: to.recorder.arrangement,
      first: Rect.lerp(from.recorder.first, to.recorder.first, t)!,
      second: Rect.lerp(from.recorder.second, to.recorder.second, t),
    ),
    modal: to.modal,
    divider: Rect.lerp(from.divider, to.divider, t),
    fold: to.fold,
    sideColumn: to.sideColumn,
  );
}

class PaneGlide extends StatefulWidget {
  const PaneGlide({required this.child, super.key});

  final Widget child;

  static PaneLayout layoutOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanePresentation>()?.layout ??
      PaneLayoutScope.of(context).layout;

  @override
  State<PaneGlide> createState() => _PaneGlideState();
}

class _PaneGlideState extends State<PaneGlide> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, value: 1);
  PaneLayout? _from;
  PaneLayout? _target;
  bool _settled = false;
  Curve _curve = Curves.linear;

  PaneLayout get _layout => interpolatePanes(_from!, _target!, _curve.transform(_clock.value));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final panes = PaneLayoutScope.of(context);
    final next = panes.layout;
    final previous = _target;
    final glide =
        previous != null &&
        paneGlides(
          previous: previous,
          next: next,
          supported: panes.supported,
          previouslySettled: _settled,
          settled: panes.settled,
          cover: panes.cover,
          reduceMotion: panes.media.disableAnimations,
        );
    _settled = panes.settled;
    if (previous == next && glide) return;
    _from = previous == null || !glide ? next : _layout;
    _target = next;
    final motion = context.motionNow;
    _curve = motion.indicatorCurve;
    _clock.duration = glide ? motion.indicator : AppMotion.instant;
    if (glide) {
      _clock.forward(from: 0);
    } else {
      _clock.value = 1;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    child: widget.child,
    builder: (context, child) => _PanePresentation(layout: _layout, child: child!),
  );
}

class _PanePresentation extends InheritedWidget {
  const _PanePresentation({required this.layout, required super.child});

  final PaneLayout layout;

  @override
  bool updateShouldNotify(_PanePresentation oldWidget) => layout != oldWidget.layout;
}
