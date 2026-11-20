import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';
import 'package:opentranscribe/view/widgets/safe_sides.dart';

/// Whether [context]'s route is still the top one. Every sheet opener asks
/// first: two pointers landing on two openers in one frame would otherwise
/// stack two sheets.
bool isTopRoute(BuildContext context) => ModalRoute.of(context)?.isCurrent ?? true;

/// Presents a bottom sheet in its source pane, with a pinned optional footer.
/// Dismissal resolves to null unless the content supplies a result.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double inset = AppSpacing.xxl,
  Widget? backdrop,
  WidgetBuilder? footer,
  bool tall = false,
}) {
  final motion = context.motionNow;
  final reduce =
      context.getInheritedWidgetOfExactType<MediaQuery>()?.data.disableAnimations ?? false;
  final sourcePane = context.getInheritedWidgetOfExactType<PaneScope>()?.touch;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppLocalizations.of(context)!.sheetCloseButton,
    barrierColor: context.themeNow.barrier,
    transitionDuration: motion.sheetScrim,
    pageBuilder: (context, animation, secondaryAnimation) => _AppSheetFrame(
      sourcePane: sourcePane,
      child: _SheetBody(
        builder: builder,
        inset: inset,
        backdrop: backdrop,
        footer: footer,
        tall: tall,
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        reduce ? FadeTransition(opacity: animation, child: child) : child,
  );
}

class _AppSheetFrame extends StatelessWidget {
  const _AppSheetFrame({required this.child, this.sourcePane});

  final Widget child;
  final PaneTouch? sourcePane;

  @override
  Widget build(BuildContext context) {
    final panes = PaneLayoutScope.maybeOf(context);
    if (panes == null) return ModalFrame(sourcePane: sourcePane, child: child);
    final sheet = PaneGlide.sheetOf(context, source: sourcePane);
    // The cover's sheet background extends beneath the status column.
    final region = panes.cover
        ? sheet.region
        : duoSheetFrame(region: sheet.region, padding: sheet.padding);
    // A fold can become active while the sheet is still gliding off its band.
    final pane = panes.layout.fold == null
        ? null
        : duoSheetRegion(layout: panes.layout, source: sourcePane, window: panes.media.size);
    return ClipRect(
      clipBehavior: pane == null ? Clip.none : Clip.hardEdge,
      clipper: pane == null ? null : _SheetPaneClipper(pane),
      child: ModalFrame(region: region, sourcePane: sourcePane, child: child),
    );
  }
}

class _SheetPaneClipper extends CustomClipper<Rect> {
  const _SheetPaneClipper(this.pane);

  final Rect pane;

  @override
  Rect getClip(Size size) => pane;

  @override
  bool shouldReclip(_SheetPaneClipper oldClipper) => pane != oldClipper.pane;
}

/// The exit spring's target, past fully-offscreen on purpose: the route's
/// reverse can undercut a critically damped settle, and the overshoot buys
/// the last sliver of travel before the overlay goes.
const double _exitTarget = 1.1;

/// How long a drop in the keyboard inset must last before the panel follows
/// it down: longer than an input view teardown, shorter than a reader notices.
const Duration _settleWindow = Duration(milliseconds: 300);

/// The keyboard inset a sheet lays out for: the live [inset], except while it
/// sits below the [held] one the panel already laid out for and the drop has
/// not [settled]. iOS tears the input view down and back up when focus moves
/// between fields and when a secure field is revealed, and a panel that
/// followed that dip would twitch shut and open again under the hands typing
/// into it. A drop that outlasts a teardown is the truth (a keyboard closed,
/// resized, or gone with the app) and takes the panel with it.
///
/// Callers feed the previous result back as [held]; the result is a fixed
/// point, so re-reading it every build never compounds.
double heldKeyboardInset({required double inset, required double held, required bool settled}) =>
    settled || inset >= held ? inset : held;

/// Whether a drop below the [held] inset has stopped falling back and should
/// start its settle. An inset above the [previous] one is the input view on
/// its way back, so the window restarts rather than running out mid-recovery
/// and taking the panel down with it.
bool settleArmed({required double inset, required double held, required double previous}) =>
    inset < held && inset <= previous;

/// How one drag step of [delta] pixels (positive toward the bottom edge)
/// splits between the panel and the content scrolled [pixels] into it, with
/// the panel dragged [sheetOffset] pixels down from rest. A drag down scrolls
/// the content back to its top first and then carries the panel; a drag up
/// returns the panel to rest first and then scrolls the content. The two
/// parts always sum to [delta].
({double sheet, double content}) splitSheetDrag({
  required double delta,
  required double pixels,
  required double minScrollExtent,
  required double sheetOffset,
}) {
  if (delta > 0) {
    final content = math.min(delta, math.max(0.0, pixels - minScrollExtent));
    return (sheet: delta - content, content: content);
  }
  final sheet = math.max(delta, -math.max(0.0, sheetOffset));
  return (sheet: sheet, content: delta - sheet);
}

/// The panel as the content's scroll position sees it.
abstract interface class _SheetDrag {
  /// How far the panel sits below rest, in pixels.
  double get offset;

  void dragBy(double delta);

  /// The finger left a drag that moved the panel, at [velocity] pixels per
  /// second toward the bottom edge.
  void release(double velocity);
}

class _SheetScrollController extends ScrollController {
  _SheetScrollController(this.sheet);

  final _SheetDrag sheet;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SheetScrollPosition(
    sheet: sheet,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );
}

/// Hands each drag step to the panel or the content by [splitSheetDrag], so
/// a list at its top pulls the sheet down instead of bouncing, and a pulled
/// sheet goes back up before the list scrolls.
class _SheetScrollPosition extends ScrollPositionWithSingleContext {
  _SheetScrollPosition({
    required this.sheet,
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  final _SheetDrag sheet;

  /// Whether the running drag has moved the panel, so its release is the
  /// panel's to settle rather than a fling of the content.
  bool _movedSheet = false;

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    _movedSheet = false;
    return super.drag(details, dragCancelCallback);
  }

  @override
  void applyUserOffset(double delta) {
    final split = splitSheetDrag(
      delta: delta,
      pixels: pixels,
      minScrollExtent: minScrollExtent,
      sheetOffset: sheet.offset,
    );
    if (split.sheet != 0) {
      _movedSheet = true;
      sheet.dragBy(split.sheet);
    }
    if (split.content != 0) super.applyUserOffset(split.content);
  }

  @override
  void goBallistic(double velocity) {
    final moved = _movedSheet;
    _movedSheet = false;
    if (moved && sheet.offset > 0) {
      // The scroll velocity counts toward the content's end; the panel's
      // counts toward the bottom edge.
      sheet.release(-velocity);
      super.goBallistic(0);
      return;
    }
    super.goBallistic(velocity);
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({
    required this.builder,
    required this.inset,
    this.backdrop,
    this.footer,
    this.tall = false,
  });

  final WidgetBuilder builder;

  final Widget? backdrop;

  final WidgetBuilder? footer;
  final bool tall;

  /// Horizontal breathing room around the content. Message sheets read best
  /// at the default; a sheet of full-width cards tightens it so the cards
  /// span like a screen's.
  final double inset;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody>
    with SingleTickerProviderStateMixin
    implements _SheetDrag {
  /// Vertical offset in fractions of the panel's own height: 0 resting, 1
  /// fully offscreen. Fractions, because the panel's height is unknown until
  /// layout and the entrance must start before the first frame.
  late final AnimationController _frac;

  final GlobalKey _panel = GlobalKey();
  late final ScrollController _scroll = _SheetScrollController(this);
  Animation<double>? _routeAnimation;
  bool _entered = false;
  bool _leaving = false;

  /// The inset the panel last laid out for, and the timer that lets a lasting
  /// drop below it through once it has outlasted an input view teardown.
  double _heldKeyboard = 0;
  double _lastInset = 0;
  bool _insetSettled = false;
  Timer? _settleDrop;

  @override
  void initState() {
    super.initState();
    _frac = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    if (context.getInheritedWidgetOfExactType<MediaQuery>()?.data.disableAnimations ?? false) {
      _frac.value = 0;
    } else {
      _spring(to: 0);
    }
    // A scrim tap or a programmatic pop reverses the route; the sheet leaves
    // under its own spring when that happens.
    _routeAnimation = ModalRoute.of(context)?.animation;
    _routeAnimation?.addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse || _leaving || !mounted) return;
    _leaving = true;
    if (!(context.getInheritedWidgetOfExactType<MediaQuery>()?.data.disableAnimations ?? false)) {
      _spring(to: _exitTarget);
    }
  }

  void _spring({required double to, double velocity = 0}) {
    // Floor the settle at 0, like the drag: a release velocity pointing up would
    // otherwise make the spring overshoot past its target into a negative
    // fraction, lifting the panel off the bottom edge and exposing the screen
    // behind it.
    _frac.animateWith(
      ClampedSimulation(
        SpringSimulation(context.motionNow.sheetSpring, _frac.value, to, velocity),
        xMin: 0,
      ),
    );
  }

  double? get _height => _panel.currentContext?.size?.height;

  @override
  double get offset => _frac.value * (_height ?? 0);

  @override
  void dragBy(double delta) {
    final height = _height;
    if (_leaving || height == null || height == 0) return;
    _frac.value = (_frac.value + delta / height).clamp(0.0, double.infinity);
  }

  @override
  void release(double velocity) {
    final height = _height;
    if (_leaving || height == null || height == 0) return;
    final sheet = context.themeNow.sheet;
    if (_frac.value * height > sheet.dismissDrag || velocity > sheet.flingVelocity) {
      // Pop now so the scrim fades while the sheet springs away at the
      // finger's speed: one gesture, both layers leaving together.
      _leaving = true;
      Navigator.of(context).pop();
      _spring(to: _exitTarget, velocity: velocity / height);
    } else {
      _spring(to: 0, velocity: velocity / height);
    }
  }

  /// Arms the settle while the inset stays below what the panel holds, and
  /// stands down the moment it climbs: only a drop that lasts is real.
  void _watchDrop(double inset) {
    final armed = settleArmed(inset: inset, held: _heldKeyboard, previous: _lastInset);
    _lastInset = inset;
    if (!armed) {
      _settleDrop?.cancel();
      _settleDrop = null;
      _insetSettled = false;
      return;
    }
    _settleDrop ??= Timer(_settleWindow, () {
      _settleDrop = null;
      if (mounted) setState(() => _insetSettled = true);
    });
  }

  @override
  void dispose() {
    _settleDrop?.cancel();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _scroll.dispose();
    _frac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = context.theme.sheet;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(sheet.radius)),
    );
    final screenHeight = MediaQuery.sizeOf(context).height;
    final padding = MediaQuery.paddingOf(context);
    final layout = PaneLayoutScope.maybeOf(context)?.layout;
    final paneSheet = layout?.mode == PaneMode.split || layout?.fold != null;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    // A drop while the route itself moves is never a teardown: a sheet opening
    // over a focused field takes that keyboard with it, and one on its way out
    // has no height left worth protecting.
    final route = _routeAnimation;
    final moving = _leaving || (route != null && route.status != AnimationStatus.completed);
    _heldKeyboard = heldKeyboardInset(
      inset: inset,
      held: _heldKeyboard,
      settled: _insetSettled || moving,
    );
    _watchDrop(inset);
    final keyboard = _heldKeyboard;
    final maxHeight = math.min(
      paneSheet ? math.max(0.0, screenHeight - padding.top) : screenHeight,
      screenHeight * (widget.tall ? sheet.tallMaxHeightFraction : sheet.maxHeightFraction) +
          keyboard,
    );
    final bottom = keyboard + padding.bottom + AppSpacing.xxl;
    final seat = _grabberSeat(sheet) + AppSpacing.xxl;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: _frac,
        builder: (context, child) =>
            FractionalTranslation(translation: Offset(0, _frac.value), child: child),
        child: GestureDetector(
          onVerticalDragUpdate: (d) => dragBy(d.primaryDelta!),
          onVerticalDragEnd: (d) => release(d.primaryVelocity ?? 0),
          child: ConstrainedBox(
            key: _panel,
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              width: double.infinity,
              decoration: ShapeDecoration(color: sheet.background, shape: shape),
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    if (widget.backdrop != null)
                      Positioned.fill(child: IgnorePointer(child: widget.backdrop)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SafeSides.scroll(
                            builder: (context, sides) => SingleChildScrollView(
                              controller: _scroll,
                              padding:
                                  EdgeInsets.fromLTRB(
                                    widget.inset,
                                    seat,
                                    widget.inset,
                                    widget.footer != null ? AppSpacing.lg : bottom,
                                  ) +
                                  sides,
                              child: Builder(builder: widget.builder),
                            ),
                          ),
                        ),
                        if (widget.footer != null)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: paneSheet
                                  ? math.max(0, maxHeight - seat)
                                  : double.infinity,
                            ),
                            child: SingleChildScrollView(
                              physics: paneSheet
                                  ? const ClampingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              child: SafeSides(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    AppSpacing.xxl,
                                    0,
                                    AppSpacing.xxl,
                                    bottom,
                                  ),
                                  child: Builder(builder: widget.footer!),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      top: AppSpacing.sm,
                      left: 0,
                      right: 0,
                      child: Center(child: _Grabber(sheet: sheet)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The band the grabber floats in: its top inset, the pill, and the gap the
/// content first rests below.
double _grabberSeat(SheetTheme sheet) => AppSpacing.sm + sheet.grabberHeight + AppSpacing.xs;

/// The sheet's grabber: a plain pill, drawn over the content.
class _Grabber extends StatelessWidget {
  const _Grabber({required this.sheet});

  final SheetTheme sheet;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: sheet.grabberWidth,
        height: sheet.grabberHeight,
        decoration: BoxDecoration(
          color: sheet.grabberColor,
          borderRadius: BorderRadius.circular(sheet.grabberHeight / 2),
        ),
      ),
    );
  }
}
