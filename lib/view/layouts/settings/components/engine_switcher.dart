import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/routes/slide_page.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/engine_picker.dart';
import 'package:opentranscribe/view/widgets/segmented_control.dart';

/// A pager's height at [position]: the two panes it sits between, mixed by
/// how far across it is. Past either end it is the end pane's own, so a
/// rubber band never stretches the page below.
double pagerHeight(List<double> heights, double position) {
  if (heights.isEmpty) return 0;
  final p = position.clamp(0.0, (heights.length - 1).toDouble());
  final lower = p.floor();
  return lerpDouble(heights[lower], heights[p.ceil()], p - lower)!;
}

/// How far a drag [overshoot] past a bound really moves across [dimension]:
/// Apple's rubber band, following less the further past it goes.
double rubberBand(double overshoot, double dimension) {
  const give = 0.55;
  if (dimension <= 0) return 0;
  return overshoot * dimension * give / (dimension + give * overshoot.abs());
}

/// How far a flick at [velocity] carries on before it rests, in
/// [velocity]'s units: Apple's projection for a deceleration [rate] per
/// millisecond.
double projectedTravel(double velocity, {required double rate}) =>
    velocity / 1000 * rate / (1 - rate);

/// The pane a released drag settles on: the one nearest where its momentum
/// ([travel], in panes) would carry [position], at most [reach] from [from]
/// and never outside [first]..[last].
int settlePane({
  required double position,
  required double travel,
  required int from,
  required int first,
  required int last,
  int reach = 1,
}) {
  final low = math.max(first, from - reach);
  final high = math.min(last, from + reach);
  if (low > high) return from.clamp(first, last);
  return (position + travel).round().clamp(low, high);
}

/// A pane's content for [row]'s engine.
typedef EnginePaneBuilder = Widget Function(BuildContext context, EngineRowState row);

/// The engines as one control over a track of their panes. Tap a segment,
/// drag the thumb, or swipe the panes: the thumb and the track move as one,
/// 1:1 under the finger and then on [AppMotion.paneSpring] from the release
/// velocity, and the track's height follows the swipe between the panes'
/// ([pagerHeight]). A pick commits at release, so the engine loads during
/// the settle. While a switch would be refused ([EnginesCubit.refusal]) the
/// track resists and says why once the finger lifts. An engine that cannot
/// run here can be looked at, its pane saying why, while the one in use
/// keeps recording.
class EngineSwitcher extends StatefulWidget {
  const EngineSwitcher({required this.rows, required this.paneBuilder, this.bleed = 0, super.key});

  final List<EngineRowState> rows;
  final EnginePaneBuilder paneBuilder;

  /// How far the track reaches past this widget's sides, into the list's
  /// gutter, so panes slide off at the screen's edge rather than at a line
  /// inside it. Each pane is inset by it again, so its content lines up with
  /// the rest of the list.
  final double bleed;

  @override
  State<EngineSwitcher> createState() => _EngineSwitcherState();
}

/// Which control a drag came from. One at a time: the other's reports are
/// ignored until the first lets go.
enum _Grip { panes, thumb }

class _EngineSwitcherState extends State<EngineSwitcher> with SingleTickerProviderStateMixin {
  /// Where the track is, in panes: 1.5 is halfway from the second to the
  /// third. Driven 1:1 by a drag, then settled on a velocity-seeded spring.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: _restIndex.toDouble(),
  );

  /// Deceleration per millisecond for a flick of the panes: a scroll's, so a
  /// swipe carries like one.
  static const double _paneDeceleration = 0.998;

  /// The thumb's: a segment is a short throw, and a scroll's rate would carry
  /// a small flick across the whole control.
  static const double _thumbDeceleration = 0.99;

  /// Panes per second a refused tap leans toward its engine before the
  /// spring brings it home: enough to read as resistance, not as a move.
  static const double _refuseNudge = 3.5;

  /// How far a refused drag must have pulled, in panes, before letting go
  /// says why rather than only settling back.
  static const double _refuseSaid = 0.04;

  /// An engine that cannot run here, rested on to read why; null rests on
  /// the one in use.
  String? _viewing;

  /// The engine a commit is asking for, until the cubit answers.
  String? _pending;

  _Grip? _grip;
  double _dragBase = 0;
  double _dragTravel = 0;

  /// The panes the running drag may settle on, fixed when it starts.
  (int, int) _dragReach = (0, 0);

  /// Where the running drag moves freely before it rubber-bands: its reach,
  /// widened to where the track was caught, so grabbing a settling track
  /// never snaps it to a bound.
  (int, int) _dragBounds = (0, 0);

  /// Whether a refused switch narrowed [_dragReach], so a pull past it is
  /// answered with why.
  bool _dragRefused = false;

  bool get _dragging => _grip != null;

  /// The pane the running settle aims at.
  int _target = 0;

  List<EngineRowState> get _rows => widget.rows;

  int _indexOf(String? engineId) =>
      engineId == null ? -1 : _rows.indexWhere((row) => row.descriptor.engineId == engineId);

  int get _activeIndex => math.max(0, _rows.indexWhere((row) => row.isActive));

  int get _restIndex {
    for (final engineId in [_pending, _viewing]) {
      final index = _indexOf(engineId);
      if (index >= 0) return index;
    }
    return _activeIndex;
  }

  /// Whether resting on pane [i] needs no switch: the engine in use, or one
  /// that cannot run here and is only looked at.
  bool _needsNoSwitch(int i) => i == _activeIndex || !_rows[i].available;

  /// The panes a [grip]'s drag may settle on. While an ask is out, only the
  /// rest. While a switch would be refused, a swipe keeps to the run around
  /// the rest that needs no switch; the thumb keeps the whole control, and a
  /// release on a segment that needs a switch is refused instead.
  (int, int) _reach(_Grip grip) {
    final rest = _restIndex;
    if (_pending != null) return (rest, rest);
    final last = _rows.length - 1;
    if (context.read<EnginesCubit>().refusal == null || grip == _Grip.thumb) return (0, last);
    var low = rest;
    while (low > 0 && _needsNoSwitch(low - 1)) {
      low--;
    }
    var high = rest;
    while (high < last && _needsNoSwitch(high + 1)) {
      high++;
    }
    return (low, high);
  }

  @override
  void initState() {
    super.initState();
    _target = _restIndex;
  }

  @override
  void didUpdateWidget(EngineSwitcher old) {
    super.didUpdateWidget(old);
    final viewing = _indexOf(_viewing);
    if (viewing < 0 || _rows[viewing].available) _viewing = null;
    // An outside switch, or the rows catching up with a pick: rest where the
    // answer says.
    if (_dragging || _pending != null) return;
    final rest = _restIndex;
    if (rest != _target || (!_position.isAnimating && _position.value != rest)) _settle(rest);
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  /// Springs to pane [index] from where the track is, seeded with [velocity]
  /// or, when none is given, the running settle's own, so a retarget never
  /// kinks.
  void _settle(int index, {double? velocity}) {
    _target = index;
    if (context.reduceMotion) {
      _position
        ..stop()
        ..value = index.toDouble();
      return;
    }
    _position.animateWith(
      SpringSimulation(
        context.motionNow.paneSpring,
        _position.value,
        index.toDouble(),
        velocity ?? (_position.isAnimating ? _position.velocity : 0),
        // Exactly on the pane, or every later rebuild would see it off rest
        // and settle again.
        snapToEnd: true,
      ),
    );
  }

  /// Leans toward [toward] (or keeps the drag's own [velocity]) and springs
  /// home, then says why the switch was refused.
  void _refuse(int toward, {double velocity = 0}) {
    final refusal = context.read<EnginesCubit>().refusal;
    final rest = _restIndex;
    _settle(rest, velocity: velocity != 0 ? velocity : (toward - rest).sign * _refuseNudge);
    if (refusal != null) unawaited(explainRefusal(context, refusal));
  }

  Future<void> _commit(int index, {double? velocity}) async {
    // One ask at a time: anything while one is out rests where it points.
    if (_pending != null) {
      _settle(_restIndex, velocity: velocity);
      return;
    }
    final row = _rows[index];
    if (index == _activeIndex) {
      if (_viewing != null) setState(() => _viewing = null);
      _settle(index, velocity: velocity);
      return;
    }
    if (!row.available) {
      if (index != _restIndex) Haptics.selection();
      setState(() => _viewing = row.descriptor.engineId);
      _settle(index, velocity: velocity);
      return;
    }
    if (context.read<EnginesCubit>().refusal != null) {
      _refuse(index, velocity: velocity ?? 0);
      return;
    }
    Haptics.selection();
    setState(() {
      _viewing = null;
      _pending = row.descriptor.engineId;
    });
    _settle(index, velocity: velocity);
    await pickEngine(context, row.descriptor.engineId, onAnswer: _answered);
  }

  /// The pick answered: rest on whatever is active now. The cubit's rows are
  /// fresher than this widget's until the rebuild, so a pick that did not
  /// take springs back at once rather than a frame later.
  void _answered() {
    if (!mounted) return;
    setState(() => _pending = null);
    final rows = context.read<EnginesCubit>().state.rows;
    final active = _indexOf(rows.where((r) => r.isActive).firstOrNull?.descriptor.engineId);
    if (!_dragging && active >= 0 && active != _target) _settle(active);
  }

  void _tap(int index) {
    if (index == _restIndex && !_position.isAnimating) return;
    unawaited(_commit(index));
  }

  void _dragStart(_Grip grip) {
    if (_grip != null) return;
    _grip = grip;
    _position.stop();
    _dragBase = _position.value;
    _dragTravel = 0;
    final (low, high) = _dragReach = _reach(grip);
    final last = _rows.length - 1;
    _dragBounds = (
      math.min(low, _dragBase.floor().clamp(0, last)),
      math.max(high, _dragBase.ceil().clamp(0, last)),
    );
    _dragRefused = _pending == null && context.read<EnginesCubit>().refusal != null;
  }

  /// [panes] more travel since the last update.
  void _dragUpdate(_Grip grip, double panes) {
    if (grip != _grip) return;
    _dragTravel += panes;
    final (low, high) = _dragBounds;
    var x = _dragBase + _dragTravel;
    if (x < low) x = low - rubberBand(low - x, 1);
    if (x > high) x = high + rubberBand(x - high, 1);
    _position.value = x;
  }

  /// [velocity] in panes per second.
  void _dragEnd(_Grip grip, double velocity) {
    if (grip != _grip) return;
    _grip = null;
    final (low, high) = _dragReach;
    final (lowBound, highBound) = _dragBounds;
    final x = _position.value;
    final overshoot = x - x.clamp(lowBound, highBound);
    // Pulled against a refused switch, not merely past an end of the control.
    if (_dragRefused && overshoot.abs() > _refuseSaid) {
      final beyond = overshoot < 0 ? lowBound - 1 : highBound + 1;
      if (beyond >= 0 && beyond < _rows.length) {
        _refuse(beyond, velocity: velocity);
        return;
      }
    }
    final thumb = grip == _Grip.thumb;
    final target = settlePane(
      position: x,
      travel: projectedTravel(velocity, rate: thumb ? _thumbDeceleration : _paneDeceleration),
      from: _dragBase.round(),
      first: low,
      last: high,
      // A thumb goes where it is put; a page turns one at a time.
      reach: thumb ? _rows.length : 1,
    );
    if (_dragRefused && !_needsNoSwitch(target)) {
      _refuse(target, velocity: velocity);
      return;
    }
    unawaited(_commit(target, velocity: velocity));
  }

  void _dragCancel(_Grip grip) {
    if (grip != _grip) return;
    _grip = null;
    _settle(_restIndex);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows.isEmpty) return const SizedBox.shrink();
    final rest = _restIndex;
    final bleed = widget.bleed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DrawnSegments(
          labels: [for (final row in rows) row.descriptor.segmentName],
          position: _position,
          dimmed: {
            for (final (i, row) in rows.indexed)
              if (!row.available) i,
          },
          onTap: _tap,
          onDragStart: () => _dragStart(_Grip.thumb),
          onDragUpdate: (segments) => _dragUpdate(_Grip.thumb, segments),
          onDragEnd: (velocity) => _dragEnd(_Grip.thumb, velocity),
          onDragCancel: () => _dragCancel(_Grip.thumb),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final step = constraints.maxWidth + 2 * bleed;
            return RawGestureDetector(
              // The whole track pages, gaps and the space beside chips too.
              behavior: HitTestBehavior.opaque,
              gestures: {
                _PaneDragRecognizer: GestureRecognizerFactoryWithHandlers<_PaneDragRecognizer>(
                  () => _PaneDragRecognizer(
                    claimed: (global) => inBackGestureEdge(context, global),
                    debugOwner: this,
                  ),
                  (recognizer) {
                    recognizer
                      ..onStart = ((_) => _dragStart(_Grip.panes))
                      ..onUpdate = ((details) {
                        _dragUpdate(_Grip.panes, -details.primaryDelta! / step);
                      })
                      ..onEnd = ((details) {
                        _dragEnd(_Grip.panes, -details.primaryVelocity! / step);
                      })
                      ..onCancel = (() => _dragCancel(_Grip.panes));
                  },
                ),
              },
              child: _PagerTrack(
                position: _position,
                bleed: bleed,
                children: [
                  for (final (i, row) in rows.indexed)
                    KeyedSubtree(
                      key: ValueKey(row.descriptor.engineId),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: bleed),
                        // Only the pane the control rests on is there to use
                        // or to read; the rest slide in for show.
                        child: IgnorePointer(
                          ignoring: i != rest,
                          child: ExcludeSemantics(
                            excluding: i != rest,
                            child: widget.paneBuilder(context, row),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A horizontal drag that leaves the leading edge to the back swipe.
class _PaneDragRecognizer extends HorizontalDragGestureRecognizer {
  _PaneDragRecognizer({required this.claimed, super.debugOwner});

  final bool Function(Offset global) claimed;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      !claimed(event.position) && super.isPointerAllowed(event);
}

/// The panes side by side, [position] panes along, clipped to the track and
/// its [bleed]. Its height is [pagerHeight] over the panes' own, so it
/// follows a swipe and a pane's own growth alike.
class _PagerTrack extends MultiChildRenderObjectWidget {
  const _PagerTrack({required this.position, required this.bleed, required super.children});

  final Animation<double> position;
  final double bleed;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPagerTrack(position: position, bleed: bleed);

  @override
  void updateRenderObject(BuildContext context, _RenderPagerTrack renderObject) {
    renderObject
      ..position = position
      ..bleed = bleed;
  }
}

class _PagerTrackParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPagerTrack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PagerTrackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PagerTrackParentData> {
  _RenderPagerTrack({required this._position, required this._bleed});

  Animation<double> _position;
  set position(Animation<double> value) {
    if (identical(value, _position)) return;
    if (attached) _position.removeListener(markNeedsLayout);
    _position = value;
    if (attached) _position.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  double _bleed;
  set bleed(double value) {
    if (value == _bleed) return;
    _bleed = value;
    markNeedsLayout();
  }

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  Rect get _window => Rect.fromLTRB(-_bleed, 0, size.width + _bleed, size.height);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PagerTrackParentData) child.parentData = _PagerTrackParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _position.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _position.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final step = width + 2 * _bleed;
    final at = _position.value;
    final heights = <double>[];
    var child = firstChild;
    var i = 0;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: step), parentUsesSize: true);
      heights.add(child.size.height);
      final data = child.parentData! as _PagerTrackParentData;
      data.offset = Offset(-_bleed + (i - at) * step, 0);
      child = data.nextSibling;
      i++;
    }
    size = constraints.constrain(Size(width, pagerHeight(heights, at)));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _clip.layer = context.pushClipRect(needsCompositing, offset, _window, (context, offset) {
      var child = firstChild;
      while (child != null) {
        final data = child.parentData! as _PagerTrackParentData;
        // A pane wholly outside the window paints nothing worth its cost.
        if (data.offset.dx < _window.right && data.offset.dx + child.size.width > _window.left) {
          context.paintChild(child, data.offset + offset);
        }
        child = data.nextSibling;
      }
    }, oldLayer: _clip.layer);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
