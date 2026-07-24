import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid/src/liquid_platform_view.dart';

/// Standard iOS navigation bar height in logical pixels.
const double kLiquidAppBarHeight = 44.0;

/// A native iOS-style navigation bar for use as [Scaffold.appBar].
///
/// ## Transition animation
///
/// Flutter's [Navigator] does not share a [UINavigationController] across
/// pages, so UIKit cannot automatically cross-fade bar items between routes.
/// [LiquidAppBar] replicates the iOS behavior in Flutter by driving the
/// opacity of [leading], [title], and [trailing] from the route's own
/// animation pair:
///
/// * **Primary animation** (`ModalRoute.animation`): items fade *in* when
///   the page pushes onto the stack, and fade *out* when it pops off.
/// * **Secondary animation** (`ModalRoute.secondaryAnimation`): items fade
///   *out* when the next page pushes on top, and fade back *in* when that
///   page is popped.
///
/// The two animations are multiplied so each can independently drive
/// opacity to zero without fighting the other.  This produces a sequential
/// cross-fade that closely matches the native iOS 26 bar-item transition.
///
/// ## Layout
///
/// The bar background is rendered by a native [UiKitView] (`liquid_app_bar`).
/// On iOS 26 this is an empty [UINavigationBar] that inherits the Liquid
/// Glass aesthetic automatically; on earlier iOS versions it falls back to a
/// [UIVisualEffectView] with `.systemChromeMaterial`.
///
/// Flutter's [NavigationToolbar] positions [leading] on the left, [title]
/// centred, and [trailing] on the right — the same layout used by
/// [CupertinoNavigationBar].
///
/// On non-iOS platforms this widget returns [SizedBox.shrink].
class LiquidAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiquidAppBar({this.leading, this.title, this.trailing, this.isDark, super.key});

  /// Widget on the leading (left) edge of the bar.
  ///
  /// Typically a [LiquidIconButton] with `icon: 'chevron.left'` for back
  /// navigation.
  final Widget? leading;

  /// Widget centred in the bar.
  ///
  /// Typically a [Text] with the current page title.
  final Widget? title;

  /// Widgets on the trailing (right) edge of the bar.
  ///
  /// Typically one or more [LiquidIconButton] or a [LiquidIconButtonGroup].
  final List<Widget>? trailing;

  /// Overrides the system user-interface style for the native bar background.
  ///
  /// When null the system / Flutter theme setting is respected.
  final bool? isDark;

  @override
  Size get preferredSize => const Size.fromHeight(kLiquidAppBarHeight);

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: kLiquidAppBarHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Native glass background ─────────────────────────────────────
          // Always fully opaque; never participates in transition animations.
          // Flutter widgets are composited on top by the engine automatically.
          Positioned.fill(
            child: LiquidPlatformView(
              viewType: 'liquid_app_bar',
              creationParams: {if (isDark != null) 'isDark': isDark},
            ),
          ),
          // ── Animated bar content ────────────────────────────────────────
          Positioned.fill(
            child: _LiquidAppBarContent(leading: leading, title: title, trailing: trailing),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Internal widgets
// ────────────────────────────────────────────────────────────────────────────

/// Subscribes to [ModalRoute] animations and cross-fades its content during
/// push / pop transitions.
class _LiquidAppBarContent extends StatefulWidget {
  const _LiquidAppBarContent({required this.leading, required this.title, required this.trailing});

  final Widget? leading;
  final Widget? title;
  final List<Widget>? trailing;

  @override
  State<_LiquidAppBarContent> createState() => _LiquidAppBarContentState();
}

class _LiquidAppBarContentState extends State<_LiquidAppBarContent> {
  static const Animation<double> _kVisible = AlwaysStoppedAnimation<double>(1.0);

  /// Combined opacity driven by both primary and secondary route animations.
  Animation<double> _opacity = _kVisible;

  // The two CurvedAnimations created each time the route changes.  Kept as
  // fields so they can be disposed before recreation.
  CurvedAnimation? _primaryCurve;
  CurvedAnimation? _secondaryCurve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildAnimations();
  }

  @override
  void dispose() {
    _primaryCurve?.dispose();
    _secondaryCurve?.dispose();
    super.dispose();
  }

  /// Rebuilds [_opacity] from the current [ModalRoute]'s animation pair.
  void _rebuildAnimations() {
    _primaryCurve?.dispose();
    _secondaryCurve?.dispose();
    _primaryCurve = null;
    _secondaryCurve = null;

    final route = ModalRoute.of(context);
    final primary = route?.animation;
    final secondary = route?.secondaryAnimation;

    // No route context (e.g. used outside Navigator) — stay fully visible.
    if (primary == null) {
      _opacity = _kVisible;
      return;
    }

    // Items fade in during the latter 75 % of the push animation (delayed
    // start so the page content settles before the buttons appear), and fade
    // out in the first 75 % of the pop (quick exit mirrors the entry delay).
    final primaryCurve = _primaryCurve = CurvedAnimation(
      parent: primary,
      curve: const Interval(0.25, 1.0, curve: Curves.easeIn),
      reverseCurve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    );

    if (secondary == null) {
      _opacity = primaryCurve;
      return;
    }

    // Items fade out in the first 75 % of the secondary animation (when the
    // next page slides in), and fade back in during the last 75 % of the
    // secondary reverse (when that page is popped).
    final secondaryCurve = _secondaryCurve = CurvedAnimation(
      parent: secondary,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      reverseCurve: const Interval(0.25, 1.0, curve: Curves.easeIn),
    );

    // Invert: secondary goes 0→1 when covered, so we want opacity 1→0.
    final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(secondaryCurve);

    // Multiply: each animation can independently drive opacity to zero.
    _opacity = _ProductAnimation(primaryCurve, fadeOut);
  }

  @override
  Widget build(BuildContext context) {
    Widget? leadingWidget;
    if (widget.leading != null) {
      leadingWidget = FadeTransition(opacity: _opacity, child: widget.leading);
    }

    Widget? titleWidget;
    if (widget.title != null) {
      titleWidget = FadeTransition(opacity: _opacity, child: widget.title);
    }

    Widget? trailingWidget;
    if (widget.trailing != null && widget.trailing!.isNotEmpty) {
      trailingWidget = FadeTransition(
        opacity: _opacity,
        child: Row(mainAxisSize: MainAxisSize.min, children: widget.trailing!),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: NavigationToolbar(
        leading: leadingWidget,
        middle: titleWidget,
        trailing: trailingWidget,
      ),
    );
  }
}

/// An [Animation<double>] whose value is the product of two child animations.
///
/// Used to combine the push-in fade ([first]) and the cover-by-next-page fade
/// ([next]) into a single opacity value.  Items are fully visible only when
/// both child animations permit it; either one driving to zero is enough to
/// hide the content.
class _ProductAnimation extends CompoundAnimation<double> {
  _ProductAnimation(Animation<double> first, Animation<double> next)
    : super(first: first, next: next);

  @override
  double get value => first.value * next.value;
}
