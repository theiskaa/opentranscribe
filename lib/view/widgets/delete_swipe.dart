import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Geometry for the swipe. The reveal runs 0..1 (closed to the disc open at the
/// action width) and, only from the open state, on to 2 - where the disc has
/// stretched into a pill filling the row. Swiping it (nearly) all the way, past
/// [_kCommitReveal], deletes; releasing short of that snaps back to open.
const double _kActionWidth = 84;
const double _kBadgeSize = 46;
const double _kOpenThreshold = 0.5;
const double _kMaxReveal = 2;
const double _kCommitReveal = 1.95;
const double _kFlingVelocity = 320; // px/s

/// Vertical slack for the disc when it is taller than a short row; well under the
/// gap between rows, so it never reaches a neighbour.
const double _kOverflow = 40;

/// The disc is tappable only when settled exactly open; this absorbs float error
/// around a reveal of 1.
const double _kSettledEpsilon = 1e-3;

/// The disc rests centred in the action gutter, so its left edge sits this far
/// from the row's right edge - the distance the row must vacate before the disc
/// is fully clear of the text.
const double _kDiscLeftInset = (_kActionWidth + _kBadgeSize) / 2;

/// The open fraction at which the disc reaches that rest spot; past it the disc
/// holds still while the row keeps sliding, opening the gap to fully-open.
const double _kRestOpen = _kDiscLeftInset / _kActionWidth;

/// Swipe-to-reveal delete for one row. A leftward drag reveals a trailing
/// destructive disc you tap to remove the row's subject. From the OPEN state a
/// further drag stretches the disc into a pill; swiping it fully across (past
/// [_kCommitReveal]) deletes. Two-stage on purpose: a swipe from closed only
/// ever opens, so a single swipe cannot delete by accident (not a [Dismissible]).
/// The one swipe vocabulary for destructive row actions: home entries and the
/// models screen's languages speak it identically.
///
/// Scoped: [openId] is the single row allowed open; opening this one claims it
/// (closing any other), and the host clears it on scroll. A tap on an open
/// row closes it instead of firing [onTap].
class DeleteSwipe extends StatefulWidget {
  const DeleteSwipe({
    required this.id,
    required this.openId,
    required this.onTap,
    required this.onDelete,
    required this.child,
    this.onLongPress,
    this.label,
    this.commitReveal = _kCommitReveal,
    super.key,
  });

  final String id;

  /// The one row currently open, shared across the list.
  final ValueNotifier<String?> openId;

  /// Fired by a tap while closed; a tap while open closes instead.
  final VoidCallback onTap;

  /// Fired by a tap on the disc, or by a full swipe.
  final VoidCallback onDelete;

  /// Optional hold action on the row content (see [Touchable.onLongPress]).
  final VoidCallback? onLongPress;

  /// The caption under the disc ("Delete" on home rows). Null for dense rows
  /// (a card list) where the labeled block would spill onto neighbours; the
  /// red disc carries the meaning alone there.
  final String? label;

  /// The reveal at which a full swipe commits the delete, in (1, 2]: 1 is the
  /// open disc, 2 the pill stretched across the whole row. The default demands
  /// nearly the full row; a host can lower it where its rows are short enough
  /// that the full pull reads as more work than the action deserves.
  final double commitReveal;

  final Widget child;

  @override
  State<DeleteSwipe> createState() => _DeleteSwipeState();
}

class _DeleteSwipeState extends State<DeleteSwipe> with TickerProviderStateMixin {
  // 0 closed, 1 open at the action width, up to 2 as the disc stretches into a
  // pill. Driven directly by the drag, then settled with the swipe curve.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    value: 0,
    upperBound: _kMaxReveal,
  );

  // The disc's entrance progress, on its OWN spring so it may overshoot: 0 fully
  // off the right edge, 1 at rest, a touch past 1 on the landing bounce. Tracks
  // the finger 1:1 while dragging (hugging the row's edge, never over the text),
  // then springs home. Separate from _reveal, which must NOT overshoot - that
  // would flash the pill.
  late final AnimationController _disc = AnimationController.unbounded(vsync: this);

  // The row width, cached from the layout so the drag math and the paint agree.
  double _width = 0;
  // Set at each drag's start: only a drag that begins open may expand past 1.
  bool _canExpand = false;
  // The reveal at the drag's start, so a release can tell a real swipe from a
  // jittery tap the drag recognizer stole.
  double _dragStartValue = 0;
  // Latches once the pill is swiped past the commit line, so delete fires once.
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    widget.openId.addListener(_onOpenIdChanged);
  }

  @override
  void didUpdateWidget(DeleteSwipe old) {
    super.didUpdateWidget(old);
    if (old.openId != widget.openId) {
      old.openId.removeListener(_onOpenIdChanged);
      widget.openId.addListener(_onOpenIdChanged);
    }
    // A keyless list rebuild can hand this State another row's config. An open
    // (or committed) reveal must not survive onto that row: reset hard, no
    // settle, the disc simply belongs to a row that is no longer here. The
    // dead row's open claim is released too, so the shared slot never points
    // at an id no row answers to.
    if (old.id != widget.id) {
      _reveal.stop();
      _reveal.value = 0;
      _disc.stop();
      _disc.value = 0;
      _committed = false;
      if (widget.openId.value == old.id) widget.openId.value = null;
    }
  }

  @override
  void dispose() {
    widget.openId.removeListener(_onOpenIdChanged);
    _reveal.dispose();
    _disc.dispose();
    super.dispose();
  }

  // Another row claimed the open slot (or a scroll cleared it): close this one.
  void _onOpenIdChanged() {
    if (widget.openId.value != widget.id && _reveal.value > 0) {
      _settle(open: false, claim: false);
    }
  }

  void _onDragStart(DragStartDetails _) {
    _reveal.stop();
    _disc.stop();
    // A settled-open reveal rests a hair below 1 (overdamped, approached from
    // below), so a raw >= 1 would read open as not-yet-open and refuse to let a
    // second drag stretch it into the delete pill. Allow the epsilon band.
    _canExpand = _reveal.value > 1 - _kSettledEpsilon;
    _dragStartValue = _reveal.value;
    _committed = false;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_committed) return;
    final v = _reveal.value;
    // Pixel-1:1 in both phases: below open a unit is the action width, above it a
    // unit is the rest of the row, so the pill tracks the finger exactly.
    final unit = v < 1 ? _kActionWidth : (_width - _kActionWidth);
    if (unit <= 0) return;
    final maxValue = _canExpand ? _kMaxReveal : 1.0;
    final next = (v - d.primaryDelta! / unit).clamp(0.0, maxValue);
    _reveal.value = next;
    // The disc hugs the sliding edge up to its rest point, then holds - so it
    // tracks the finger without ever crossing onto the text.
    _disc.value = (next / _kRestOpen).clamp(0.0, 1.0);
    // Full swipe: dragged past the commit line, delete without a release.
    if (_canExpand && next >= widget.commitReveal) {
      _committed = true;
      _commit();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_committed) return;
    final velocity = d.primaryVelocity ?? 0;
    // A "drag" that started closed and went nowhere is a TAP the horizontal
    // recognizer stole from the tap recognizer (a finger landing with a few
    // pixels of sideways jitter crosses the slop and wins the arena). Honor
    // the intent: fire the tap instead of silently swallowing it. "Started
    // closed" allows the spring's settled-closed rest (a hair above 0, not
    // exactly 0), or a once-swiped row would never recover a jittery tap.
    if (_dragStartValue < _kSettledEpsilon &&
        _reveal.value < 0.06 &&
        velocity.abs() < _kFlingVelocity) {
      _settle(open: false, claim: false);
      widget.onTap();
      return;
    }
    // Released in the expand zone but short of the commit line: back to open.
    if (_canExpand && _reveal.value >= 1) {
      _settle(open: true, pixelVelocity: velocity);
      return;
    }
    final bool open;
    if (velocity <= -_kFlingVelocity) {
      open = true;
    } else if (velocity >= _kFlingVelocity) {
      open = false;
    } else {
      open = _reveal.value >= _kOpenThreshold;
    }
    _settle(open: open, pixelVelocity: velocity);
  }

  void _commit() => widget.onDelete();

  // Settle the reveal to open (1) or closed (0) with a spring seeded by the
  // finger's release velocity, so the animation continues at the speed the drag
  // ended - no seam between dragging and settling.
  void _settle({required bool open, bool claim = true, double pixelVelocity = 0}) {
    final start = _reveal.value;
    final target = open ? 1.0 : 0.0;
    final discTarget = open ? 1.0 : 0.0;
    if (context.reduceMotion) {
      // Reduce Motion: no settle, no bounce - jump both straight to target.
      _reveal.stop();
      _reveal.value = target;
      _disc.stop();
      _disc.value = discTarget;
    } else {
      final motion = context.motionNow;
      // px/s to reveal-units/s. A leftward drag (negative pixel velocity) drives
      // the reveal up, hence the negation; the unit is whichever phase the finger
      // left in.
      final unit = start < 1 ? _kActionWidth : (_width - _kActionWidth);
      final revealVelocity = unit > 0 ? -pixelVelocity / unit : 0.0;
      // Clamp to the segment being crossed so a fast release can never overshoot
      // into a neighbouring phase (e.g. briefly flash the pill when snapping open).
      final spring = SpringSimulation(motion.swipeSpring, start, target, revealVelocity);
      _reveal.animateWith(
        ClampedSimulation(
          spring,
          xMin: start < target ? start : target,
          xMax: start < target ? target : start,
        ),
      );
      // The disc rides its own underdamped spring, handed the finger's velocity so
      // there is no seam: it lands with one soft overshoot on show, springs back
      // off the edge on hide. A faster fling lands with a proportionally bigger
      // bounce.
      final discVelocity = -pixelVelocity / _kDiscLeftInset;
      _disc.animateWith(
        SpringSimulation(motion.swipePopSpring, _disc.value, discTarget, discVelocity),
      );
    }
    if (open) {
      Haptics.selection();
      if (claim) widget.openId.value = widget.id;
    } else {
      // Closing un-commits: a row that survived its delete (the removal was a
      // no-op) must be swipeable again, not dead behind the latch.
      _committed = false;
      if (widget.openId.value == widget.id) widget.openId.value = null;
    }
  }

  void _handleTap() {
    // A settled-closed reveal rests a hair above 0 (the spring stops within its
    // tolerance, not exactly at target), so test against the same epsilon the
    // disc's hit-test uses. A raw > 0 would make a closed-but-once-swiped row
    // swallow every tap and never fire onTap.
    if (_reveal.value > _kSettledEpsilon) {
      _settle(open: false);
    } else {
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // Built once; reused each frame via closure, so the text and glyph are never
    // rebuilt while dragging.
    final content = Touchable(
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      child: widget.child,
    );
    final glyph = AppIcon(AppIcons.trash, color: theme.onDanger);
    final label = widget.label == null
        ? null
        : Text(widget.label!, style: AppType.caption.copyWith(color: theme.textSecondary));

    return GestureDetector(
      // Opaque, not deferToChild: the drag must be caught across the WHOLE row,
      // including the blank area right of short text, or it falls through to the
      // list and scrolls instead of revealing.
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: ClipRect(
        // Horizontal only: the content slides UNDER the gutter, but the disc is
        // free to spill into the row's gap on a short row.
        clipper: const _HorizontalClipper(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [_slidingContent(content), _deleteSurface(theme, glyph, label)],
            );
          },
        ),
      ),
    );
  }

  Widget _slidingContent(Widget content) {
    return AnimatedBuilder(
      animation: _reveal,
      child: content,
      builder: (context, child) {
        final open = _reveal.value.clamp(0.0, 1.0);
        final expand = (_reveal.value - 1).clamp(0.0, 1.0);
        final dx = _kActionWidth * open + (_width - _kActionWidth) * expand;
        return Transform.translate(offset: Offset(-dx, 0), child: child);
      },
    );
  }

  // The ONE delete surface: a disc that pops in on open, then the SAME shape
  // stretches into a pill as the drag continues (only its width grows; height
  // and the stadium radius hold), not a second layer fading in over it.
  Widget _deleteSurface(AppTheme theme, Widget glyph, Widget? label) {
    final AppMotion motion = theme.motion;
    const rightInset = (_kActionWidth - _kBadgeSize) / 2;
    const radius = _kBadgeSize / 2;

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _disc]),
        builder: (context, _) {
          final open = _reveal.value.clamp(0.0, 1.0);
          final expand = (_reveal.value - 1).clamp(0.0, 1.0);
          final w = _kBadgeSize + (_width - _kBadgeSize) * expand;

          // The entrance rides _disc: 0 off the right edge, 1 at rest, a touch past
          // 1 on the landing overshoot. It slides IN FROM THE RIGHT and the
          // overshoot is a soft bounce - a nudge left and a small pop in size as it
          // lands, reversed on hide. One spring, so there is no seam.
          final entrance = _disc.value;
          final grow = entrance.clamp(0.0, 1.0);
          final overshoot = (entrance - 1).clamp(0.0, 0.3);
          final appear = Curves.easeOut.transform(grow);
          final scale =
              motion.swipePopMinScale + (1 - motion.swipePopMinScale) * grow + overshoot * 0.4;

          // Whatever the spring does, never let the disc cross the sliding row's
          // right edge: clamp its offset to the strip the row has vacated, so it is
          // never drawn over the text and the off-edge part is hidden by the outer
          // clip. The expand phase holds it at rest while it stretches into the pill.
          final contentDx = _kActionWidth * open + (_width - _kActionWidth) * expand;
          final slideIn = (_kDiscLeftInset * (1 - entrance)).clamp(
            _kDiscLeftInset - contentDx,
            _kDiscLeftInset,
          );

          return IgnorePointer(
            ignoring: (_reveal.value - 1).abs() > _kSettledEpsilon,
            child: Transform.translate(
              // A label sits inside the centred block, so it pulls the disc up
              // toward the row above. Nudge the whole surface down by that much
              // to re-centre the disc on the row; no label, no nudge.
              offset: Offset(slideIn, label == null ? 0 : AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.only(right: rightInset),
                // Relax both axes + centerRight so the pill keeps its natural width
                // (pushed right, not stretched full and centered) and can spill
                // into the row's gap on a short row.
                child: OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Opacity(
                    opacity: appear,
                    child: Transform.scale(
                      scale: scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Touchable(
                            onTap: widget.onDelete,
                            pressedOpacity: 0.6,
                            child: SizedBox(
                              width: w,
                              height: _kBadgeSize,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.danger,
                                  borderRadius: BorderRadius.circular(radius),
                                ),
                                child: Center(child: glyph),
                              ),
                            ),
                          ),
                          if (label != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xs),
                              child: label,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Clips to the box's width but leaves the vertical axis open, so the sliding
/// content and the off-edge action are hidden while the taller disc can still
/// overflow into the row's gap without being cropped.
class _HorizontalClipper extends CustomClipper<Rect> {
  const _HorizontalClipper();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, -_kOverflow, size.width, size.height + _kOverflow);

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}
