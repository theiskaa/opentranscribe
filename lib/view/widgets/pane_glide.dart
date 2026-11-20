import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
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
    // A fold appearing glides too: the content already sits on it at the
    // first frame, so travelling off it beats a cut. Two different folds are
    // a rotation, which swaps.
    (previous.fold == next.fold || previous.fold == null || next.fold == null);

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

typedef SheetReflow = ({Rect region, EdgeInsets padding});

@immutable
class PaneReflow {
  const PaneReflow._({required this.layout, required this.recorderRegion, required this._sheets});

  factory PaneReflow.fromLayout(
    PaneLayout layout, {
    Size? window,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    final size = window ?? layout.leading.rect.expandToInclude(layout.detail.rect).size;
    SheetReflow sheet(PaneTouch? source) {
      final region = duoSheetRegion(layout: layout, source: source, window: size);
      return (region: region, padding: paneInsets(padding, region, size));
    }

    return PaneReflow._(
      layout: layout,
      recorderRegion: centeredRecorderRegion(layout),
      sheets: {
        for (final source in <PaneTouch?>[null, ...PaneTouch.values]) source: sheet(source),
      },
    );
  }

  final PaneLayout layout;
  final Rect recorderRegion;
  final Map<PaneTouch?, SheetReflow> _sheets;

  SheetReflow sheetFor(PaneTouch? source) => _sheets[source]!;
}

PaneReflow interpolateReflow(PaneReflow from, PaneReflow to, double t) => PaneReflow._(
  layout: interpolatePanes(from.layout, to.layout, t),
  recorderRegion: Rect.lerp(from.recorderRegion, to.recorderRegion, t)!,
  sheets: {
    for (final source in <PaneTouch?>[null, ...PaneTouch.values])
      source: (
        region: Rect.lerp(from.sheetFor(source).region, to.sheetFor(source).region, t)!,
        padding: EdgeInsets.lerp(from.sheetFor(source).padding, to.sheetFor(source).padding, t)!,
      ),
  },
);

class PaneGlide extends StatefulWidget {
  const PaneGlide({required this.child, super.key});

  final Widget child;

  static PaneLayout layoutOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanePresentation>()?.frame.layout ??
      PaneLayoutScope.of(context).layout;

  static Rect recorderRegionOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanePresentation>()?.frame.recorderRegion ??
      centeredRecorderRegion(PaneLayoutScope.of(context).layout);

  static SheetReflow sheetOf(BuildContext context, {required PaneTouch? source}) {
    final frame = context.dependOnInheritedWidgetOfExactType<_PanePresentation>()?.frame;
    if (frame != null) return frame.sheetFor(source);
    final panes = PaneLayoutScope.of(context);
    return PaneReflow.fromLayout(
      panes.layout,
      window: panes.media.size,
      padding: panes.media.padding,
    ).sheetFor(source);
  }

  @override
  State<PaneGlide> createState() => _PaneGlideState();
}

class _PaneGlideState extends State<PaneGlide> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, value: 1);
  PaneReflow? _from;
  PaneReflow? _target;
  bool _settled = false;
  Curve _curve = Curves.linear;

  PaneReflow get _frame => interpolateReflow(_from!, _target!, _curve.transform(_clock.value));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final panes = PaneLayoutScope.of(context);
    final next = panes.layout;
    final previous = _target?.layout;
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
    final target = PaneReflow.fromLayout(
      next,
      window: panes.media.size,
      padding: panes.media.padding,
    );
    _from = previous == null || !glide ? target : _frame;
    _target = target;
    final motion = context.motionNow;
    final refolding = (previous?.fold == null) != (next.fold == null);
    _curve = refolding ? motion.duoReflowCurve : motion.indicatorCurve;
    _clock.duration = glide ? (refolding ? motion.duoReflow : motion.indicator) : AppMotion.instant;
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
    builder: (context, child) => _PanePresentation(frame: _frame, child: child!),
  );
}

class _PanePresentation extends InheritedWidget {
  const _PanePresentation({required this.frame, required super.child});

  final PaneReflow frame;

  @override
  bool updateShouldNotify(_PanePresentation oldWidget) =>
      frame.layout != oldWidget.frame.layout ||
      frame.recorderRegion != oldWidget.frame.recorderRegion ||
      !mapEquals(frame._sheets, oldWidget.frame._sheets);
}
