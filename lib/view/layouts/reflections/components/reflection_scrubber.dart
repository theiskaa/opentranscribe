import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_page_logic.dart';
import 'package:opentranscribe/view/widgets/glass_capsule.dart';

/// The pager's floating position capsule: a frosted pill holding the
/// continuous dash strip, scrubbable - a drag flies through weeks at one week
/// per dash of travel ([scrubPage]), anchored at pointer-down so touching
/// never teleports. A raw [Listener] with an opaque hit test: it answers on the
/// touch itself (no gesture arena, no slop delay) and the pager underneath
/// never contends for the pointer. The capsule also just tracks ordinary
/// pager swipes through the controller it listens to.
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

  /// One dash of finger travel, captured each build.
  double _pitch = 1;

  /// The finger is down: the capsule swells slightly to answer the grab.
  bool _grabbed = false;

  bool get _attached => widget.controller.hasClients;

  void _down(PointerDownEvent event) {
    if (!_attached || _pointer != null) return;
    _pointer = event.pointer;
    // A pager still settling keeps its ballistic ticking under the grab;
    // pinning the pixels idles it, so the anchor cannot drift stale.
    widget.controller.jumpTo(widget.controller.position.pixels);
    _anchorPage = widget.controller.page ?? 0;
    _anchorX = event.position.dx;
    // The grab answers in the hand as well as in scale.
    Haptics.light();
    setState(() => _grabbed = true);
    widget.onScrubStart();
  }

  void _move(PointerMoveEvent event) {
    if (!mounted || !_attached || event.pointer != _pointer) return;
    final page = scrubPage(
      anchorPage: _anchorPage,
      dx: event.position.dx - _anchorX,
      pitch: _pitch,
      count: widget.count,
    );
    widget.controller.jumpTo(page * widget.controller.position.viewportDimension);
  }

  void _up(PointerEvent event) {
    if (!mounted || event.pointer != _pointer) return;
    _pointer = null;
    setState(() => _grabbed = false);
    if (!_attached) {
      widget.onScrubEnd();
      return;
    }
    Haptics.light();
    final target = (widget.controller.page ?? 0).round();
    if (context.reduceMotion) {
      widget.controller.jumpToPage(target);
    } else {
      // weekHome: the settle answers a touch, like the calendar's tap-home.
      widget.controller.animateToPage(
        target,
        duration: context.motionNow.weekHome,
        curve: Curves.easeOutCubic,
      );
    }
    widget.onScrubEnd();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scrubber = theme.scrubber;
    final dashes = theme.pageIndicator;
    final fade = widget.fade;
    _pitch = dashes.dashWidth + dashes.gap;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
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
                    return ScrubberDashes(count: widget.count, position: page);
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

/// The capsule's dash strip, drawn continuously: one dash per week slides
/// past a fixed viewport as the FRACTIONAL page moves, the active bar glued
/// to the position rather than stepping at commits, and a rim with more
/// weeks beyond it shrinks its dashes on a continuous ramp that reads as an
/// ellipsis. Scroll-driven 1:1, so it needs no Reduce Motion gate.
class ScrubberDashes extends StatelessWidget {
  const ScrubberDashes({required this.count, required this.position, super.key});

  /// At most this many dash slots in the viewport.
  static const maxVisible = 7;

  final int count;

  /// Fractional page, straight off the controller.
  final double position;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.pageIndicator;
    final pitch = tokens.dashWidth + tokens.gap;
    // The bulge allowance keeps the strip from breathing as the bar moves.
    final width = math.min(count, maxVisible) * pitch + tokens.activeBulge;
    return CustomPaint(
      size: Size(width, tokens.dashHeight),
      painter: _DashStripPainter(
        count: count,
        position: position.clamp(0, math.max(0, count - 1)).toDouble(),
        max: maxVisible,
        pitch: pitch,
        dashWidth: tokens.dashWidth,
        dashHeight: tokens.dashHeight,
        bulge: tokens.activeBulge,
        active: tokens.active,
        inactive: tokens.inactive,
      ),
    );
  }
}

class _DashStripPainter extends CustomPainter {
  const _DashStripPainter({
    required this.count,
    required this.position,
    required this.max,
    required this.pitch,
    required this.dashWidth,
    required this.dashHeight,
    required this.bulge,
    required this.active,
    required this.inactive,
  });

  final int count;
  final double position;
  final int max;
  final double pitch;
  final double dashWidth;
  final double dashHeight;
  final double bulge;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    // Half-entered dashes shear off at the rims instead of poking out.
    canvas.clipRect(Offset.zero & size);
    final shift = dashStripShift(count: count, position: position, max: max);
    final cy = size.height / 2;
    final radius = Radius.circular(dashHeight);
    final paint = Paint()..color = inactive;

    RRect dash(double cx, double w) => RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: dashHeight),
      radius,
    );

    // Dashes sit centered inside the active bar's bulge allowance.
    double centerOf(double slot) => (slot + 0.5) * pitch + bulge / 2;

    for (var i = math.max(0, shift.floor() - 1); i < count && i < shift + max + 1; i++) {
      final slot = i - shift;
      final w = dashWidth * dashRimScale(slot: slot, shift: shift, count: count, max: max);
      canvas.drawRRect(dash(centerOf(slot), w), paint);
    }
    canvas.drawRRect(dash(centerOf(position - shift), dashWidth + bulge), Paint()..color = active);
  }

  @override
  bool shouldRepaint(_DashStripPainter old) =>
      old.count != count ||
      old.position != position ||
      old.max != max ||
      old.pitch != pitch ||
      old.dashWidth != dashWidth ||
      old.dashHeight != dashHeight ||
      old.bulge != bulge ||
      old.active != active ||
      old.inactive != inactive;
}
