import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_page_logic.dart';
import 'package:opentranscribe/view/widgets/glass_capsule.dart';

/// The pager's floating position capsule: a frosted pill holding the ink dot
/// strip, scrubbable - a drag flies through weeks at one week per dot of
/// travel ([scrubPage]), anchored where the finger crosses the touch slop so
/// the scrub starts 1:1 with no jump - and tappable: a tap on either half
/// turns one week in that direction ([scrubTapTarget]). A raw [Listener] with
/// an opaque hit test owns the pointer directly, so the pager underneath
/// never contends for it. The capsule also just tracks ordinary pager swipes
/// through the controller it listens to.
class ReflectionScrubber extends StatefulWidget {
  const ReflectionScrubber({
    required this.controller,
    required this.count,
    required this.onScrubStart,
    required this.onScrubEnd,
    this.fade = 1,
    super.key,
  });

  final PageController controller;
  final int count;

  /// Show/hide fraction, 0..1. The caller drives the fade through here
  /// instead of an Opacity layer: a BackdropFilter inside one samples the
  /// layer's own empty buffer, so the blur would pop instead of fading.
  final double fade;

  /// Fired at pointer-down/up so the screen can hold its page physics (a
  /// scrub's jumps must not fight the ballistic snap) and keep the capsule
  /// visible under the finger.
  final VoidCallback onScrubStart;
  final VoidCallback onScrubEnd;

  @override
  State<ReflectionScrubber> createState() => _ReflectionScrubberState();
}

class _ReflectionScrubberState extends State<ReflectionScrubber> {
  double _anchorPage = 0;
  double _anchorX = 0;

  /// The pointer that owns the scrub; later fingers are ignored so a stray
  /// touch cannot re-anchor mid-drag or end the grip early.
  int? _pointer;

  /// One dot of finger travel, captured each build.
  double _pitch = 1;

  /// The finger is down: the capsule swells slightly to answer the grab.
  bool _grabbed = false;

  /// The finger has traveled past the touch slop: a real scrub owns the
  /// position from here. Until then the pointer interrupts NOTHING, so a
  /// tap landing mid-turn lets the flow keep running instead of freezing
  /// and restarting it from a standstill.
  bool _scrubActive = false;

  /// The last release's commanded page while its turn is still flowing, the
  /// base rapid taps chain from ([tapChainBase]). Dropped once the pager
  /// rests under a fresh touch or a drag owns the position.
  int? _flowTarget;

  bool get _attached => widget.controller.hasClients;

  @override
  void dispose() {
    // An unmount mid-grab must release the screen's hold on the page physics;
    // post-frame because this can run inside the parent's own rebuild.
    if (_pointer != null) {
      _pointer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onScrubEnd());
    }
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (!_attached || _pointer != null) return;
    _pointer = event.pointer;
    _scrubActive = false;
    _anchorX = event.position.dx;
    final page = widget.controller.page ?? 0;
    if ((page - page.round()).abs() < 0.001) _flowTarget = null;
    // The grab answers in the hand as well as in scale.
    Haptics.light();
    setState(() => _grabbed = true);
    widget.onScrubStart();
  }

  void _move(PointerMoveEvent event) {
    if (!mounted || !_attached || event.pointer != _pointer) return;
    if (!_scrubActive) {
      if ((event.position.dx - _anchorX).abs() < kTouchSlop) return;
      // The drag is real: own the position from HERE. Pinning the pixels
      // idles any running settle so the anchor cannot drift, and re-anchoring
      // at the slop edge keeps the scrub 1:1 with no startup jump.
      _scrubActive = true;
      _flowTarget = null;
      widget.controller.jumpTo(widget.controller.position.pixels);
      _anchorPage = widget.controller.page ?? 0;
      _anchorX = event.position.dx;
      return;
    }
    final page = scrubPage(
      anchorPage: _anchorPage,
      dx: event.position.dx - _anchorX,
      pitch: _pitch,
      count: widget.count,
    );
    widget.controller.jumpTo(page * widget.controller.position.viewportDimension);
  }

  void _up(PointerEvent event) => _release(event, tapEligible: true);

  void _cancel(PointerEvent event) => _release(event, tapEligible: false);

  void _release(PointerEvent event, {required bool tapEligible}) {
    if (!mounted || event.pointer != _pointer) return;
    _pointer = null;
    setState(() => _grabbed = false);
    if (!_attached) {
      widget.onScrubEnd();
      return;
    }
    Haptics.light();
    final live = widget.controller.page ?? 0;
    final target = tapEligible ? _releaseTarget(event) : live.round();
    _flowTarget = target;
    if (context.reduceMotion) {
      widget.controller.jumpToPage(target);
      _flowTarget = null;
    } else {
      final motion = context.motionNow;
      // The full weekTurn pour for a whole-week turn; a sub-dot settle takes
      // its proportional share, floored so even a nudge still flows. A turn
      // resumed mid-flight eases OUT only: restarting the two-ended curve
      // would trap rapid taps in its slow first phase forever.
      final distance = (live - target).abs().clamp(motion.weekTurnFloor, 1.0);
      final midFlight = (live - live.round()).abs() > 0.01;
      final settle = widget.controller.animateToPage(
        target,
        duration: Duration(milliseconds: (motion.weekTurn.inMilliseconds * distance).round()),
        curve: midFlight ? motion.weekTurnResumeCurve : motion.weekTurnCurve,
      );
      // Drop the chain base once THIS turn lands, so a later swipe-then-tap
      // reads the live page, not a spent target. The equality guard leaves a
      // chained tap that already retargeted untouched.
      unawaited(
        settle.whenComplete(() {
          if (mounted && _flowTarget == target) _flowTarget = null;
        }),
      );
    }
    widget.onScrubEnd();
  }

  /// A release whose finger never crossed the touch slop is a TAP, and the
  /// tapped half turns one week in its direction, chaining from an unfinished
  /// turn's own target so rapid taps advance a week each; a real scrub
  /// settles where it left off.
  int _releaseTarget(PointerEvent event) {
    final page = widget.controller.page ?? 0;
    final box = context.findRenderObject();
    if (box is! RenderBox || _scrubActive) return page.round();
    return scrubTapTarget(
      page: tapChainBase(page: page, pending: _flowTarget),
      dx: box.globalToLocal(event.position).dx,
      width: box.size.width,
      count: widget.count,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scrubber = theme.scrubber;
    final fade = widget.fade;
    _pitch = scrubber.dotSize + scrubber.gap;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      // The visual pill padded past the 44pt minimum touch target.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: AppSpacing.md),
        child: AnimatedScale(
          // The grab answers on the touch itself; stilled under Reduce Motion.
          scale: _grabbed && !context.reduceMotion ? theme.motion.grabScale : 1,
          duration: theme.motion.press,
          curve: Curves.easeOut,
          child: GlassCapsule(
            height: scrubber.height,
            tint: scrubber.tint.withValues(alpha: scrubber.tint.a * fade),
            border: scrubber.border.withValues(alpha: scrubber.border.a * fade),
            sigma: scrubber.blurSigma * fade,
            child: Opacity(
              opacity: fade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) {
                    final page = _attached ? (widget.controller.page ?? 0) : 0.0;
                    return ScrubberDots(count: widget.count, position: page);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The capsule's dot strip: one dot per week slides past a fixed [maxVisible]
/// window as the FRACTIONAL page moves, and the position is INK, one liquid
/// blob at home in the current week's dot. Moving between weeks the ink
/// MORPHS across as a liquid bridge: the source blob drains ([bridgeDrain])
/// while a pinched stream reaches over ([bridgeNeck]) and the destination
/// swells full with a soft follow-through ([bridgeFill]) - venom flowing
/// from dot to dot, never leaving the line. Driven 1:1 by the page fraction,
/// so a swipe holds the stream mid-flow and backing out reverses it; being
/// scroll-driven it needs no Reduce Motion gate. A rim with more weeks
/// beyond it shrinks its dots on a continuous ramp that reads as an ellipsis.
class ScrubberDots extends StatelessWidget {
  const ScrubberDots({required this.count, required this.position, super.key});

  /// At most this many dot slots in the viewport, the capsule's fixed width.
  static const maxVisible = 5;

  final int count;

  /// Fractional page, straight off the controller.
  final double position;

  @override
  Widget build(BuildContext context) {
    final scrubber = context.theme.scrubber;
    final pitch = scrubber.dotSize + scrubber.gap;
    // The active-scale allowance keeps the strip from breathing as ink moves.
    final width =
        math.min(count, maxVisible) * pitch + scrubber.dotSize * (scrubber.activeScale - 1);
    return CustomPaint(
      size: Size(width, scrubber.height),
      painter: _DotStripPainter(
        count: count,
        position: position.clamp(0, math.max(0, count - 1)).toDouble(),
        max: maxVisible,
        pitch: pitch,
        dotSize: scrubber.dotSize,
        activeScale: scrubber.activeScale,
        neckWaist: scrubber.neckWaist,
        inkStretch: scrubber.inkStretch,
        ink: scrubber.ink,
        track: scrubber.track,
      ),
    );
  }
}

class _DotStripPainter extends CustomPainter {
  const _DotStripPainter({
    required this.count,
    required this.position,
    required this.max,
    required this.pitch,
    required this.dotSize,
    required this.activeScale,
    required this.neckWaist,
    required this.inkStretch,
    required this.ink,
    required this.track,
  });

  final int count;
  final double position;
  final int max;
  final double pitch;
  final double dotSize;
  final double activeScale;
  final double neckWaist;
  final double inkStretch;
  final Color ink;
  final Color track;

  /// Where the stream attaches on each blob, as a fraction of its radius:
  /// inside the crown, so blob and stream meet in a concave liquid seam
  /// instead of a tangent.
  static const _attach = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    // Half-entered dots shear off at the rims instead of poking out.
    canvas.clipRect(Offset.zero & size);
    final shift = stripShift(count: count, position: position, max: max);
    final cy = size.height / 2;
    final restR = dotSize / 2;
    final inkR = restR * activeScale;
    final trackPaint = Paint()..color = track;
    final inkPaint = Paint()..color = ink;

    double centerOf(double slot) => (slot + 0.5) * pitch + (inkR - restR);

    for (var i = math.max(0, shift.floor() - 1); i < count && i < shift + max + 1; i++) {
      final slot = i - shift;
      final r = restR * rimScale(slot: slot, shift: shift, count: count, max: max);
      canvas.drawCircle(Offset(centerOf(slot), cy), r, trackPaint);
    }

    final source = position.floor();
    final t = position - source;
    final neck = bridgeNeck(t);
    final sx = centerOf(source - shift);
    final rs = inkR * bridgeDrain(t);

    void blob(double x, double r) {
      if (r <= 0) return;
      final elongation = 1 + inkStretch * neck;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, cy),
          width: r * 2 * elongation,
          height: r * 2 / elongation,
        ),
        inkPaint,
      );
    }

    blob(sx, rs);
    if (t <= 0) return;

    final dx = centerOf(source + 1 - shift);
    final rd = inkR * bridgeFill(t);
    blob(dx, rd);

    final waist = math.min(rs, rd) * neckWaist * neck;
    if (waist <= 0) return;
    final mid = (sx + dx) / 2;
    canvas.drawPath(
      Path()
        ..moveTo(sx, cy - rs * _attach)
        ..quadraticBezierTo(mid, cy - waist, dx, cy - rd * _attach)
        ..lineTo(dx, cy + rd * _attach)
        ..quadraticBezierTo(mid, cy + waist, sx, cy + rs * _attach)
        ..close(),
      inkPaint,
    );
  }

  @override
  bool shouldRepaint(_DotStripPainter old) =>
      old.count != count ||
      old.position != position ||
      old.max != max ||
      old.pitch != pitch ||
      old.dotSize != dotSize ||
      old.activeScale != activeScale ||
      old.neckWaist != neckWaist ||
      old.inkStretch != inkStretch ||
      old.ink != ink ||
      old.track != track;
}
