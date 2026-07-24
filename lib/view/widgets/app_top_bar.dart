import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/edge_fade.dart';
import 'package:opentranscribe/view/widgets/glass_icon_button.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The floating bar every screen shares: a transparent overlay carrying its
/// title, over a progressive blur that fades to nothing past the content row.
/// Screens mount it on top of a Stack and let their scrollables run BEHIND
/// it; over a resting uniform background the material is invisible, so there
/// is no chrome until content actually slides under.
///
/// The padding contract: compact bars pad content by [heightOf] plus the
/// theme's `fadeTail` when the content starts flush (the material is opaque
/// through the row and only melts across the tail); large title bars pad by
/// [largeHeightOf] plus a breath (`AppScaffold.topPaddingOf` for scaffolded
/// screens).
/// Where a bar control sits relative to the screen edge, and to the next
/// control along. One number for both, so the chrome reads as a single rhythm.
const double _edgeInset = AppSpacing.md;

/// How much faster than the fold a folding bottom slot pulls itself up, so it
/// reads as retreating under the title row rather than waiting to be cut off.
const double _foldLead = 0.22;

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    this.leading,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.centerTitle = false,
    this.barHeight,
    this.onTitleTap,
    this.bottom,
    this.bottomHeight = 0,
    this.bottomFold,
    this.frosted = false,
    this.automaticLeading = true,
    super.key,
  });

  final Widget? leading;
  final Widget? title;

  /// Optional second line under the title, for title bars that carry context
  /// (home's weekday and month).
  final Widget? subtitle;

  /// Trailing controls, in reading order. The bar owns their spacing: callers
  /// pass bare buttons and never their own padding, so every bar in the app
  /// lands its controls on the same edge.
  final List<Widget> actions;

  /// The recorder centers its timer; everything else left-aligns.
  final bool centerTitle;

  /// Content row height override; defaults to the compact `TopBarTheme.height`.
  /// Title bars pass `TopBarTheme.largeHeight`.
  final double? barHeight;

  /// Makes the title block tappable (home: scroll back to the top).
  final VoidCallback? onTitleTap;

  /// Fixed chrome BELOW the title row, on the same material (home's week
  /// strip): the fade tail runs past it, never over it, and its own taps
  /// work.
  final Widget? bottom;
  final double bottomHeight;

  /// Folds the bottom slot away as its value runs 0 to 1. The slot's height
  /// goes with it, so the material and its fade close down over a strip that
  /// retreats up behind the title row, and the bar ends up compact.
  ///
  /// A listenable rather than a plain value because a scroll drives it: only
  /// the bar's frame rebuilds per frame, never the row or the slot's contents.
  final ValueListenable<double>? bottomFold;

  /// The SECONDARY bar (reeed's): a translucent frost that content shows
  /// through, fading from its midpoint, rather than home's opaque material.
  /// Every screen that is not home (settings and its sub-screens, the gallery)
  /// wears it - the home bar stays as it was.
  final bool frosted;

  /// Whether a poppable route auto-grows a back chevron in an empty leading
  /// slot. Home turns this OFF: it is the base of the stack, but mid-pop of a
  /// route above it `canPop` is briefly true, and without this a phantom back
  /// button flickers in on the way back.
  final bool automaticLeading;

  /// Status inset + the default compact row, for content padding.
  static double heightOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + context.theme.topBar.height;

  /// Status inset + the large title row, for content padding under title bars.
  static double largeHeightOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + context.theme.topBar.largeHeight;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final bar = theme.topBar;
    final topInset = MediaQuery.paddingOf(context).top;
    final rowHeight = barHeight ?? bar.height;

    final leading =
        this.leading ??
        (automaticLeading && Navigator.of(context).canPop() ? const AppBackButton() : null);

    Widget? titleBlock = title;
    if (titleBlock != null && subtitle != null) {
      titleBlock = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: AppSpacing.xxs),
          subtitle!,
        ],
      );
    }
    if (titleBlock != null && onTitleTap != null) {
      titleBlock = Touchable(onTap: onTitleTap, child: titleBlock);
    }

    final row = Row(
      children: [
        // A control sits on the bar's own edge; a bare title aligns with the
        // screen's content inset instead, so it lines up with what is under it.
        if (leading != null)
          Padding(
            padding: const EdgeInsets.only(left: _edgeInset),
            child: leading,
          )
        else
          const SizedBox(width: AppSpacing.xl),
        if (!centerTitle && titleBlock != null)
          Expanded(
            child: Align(alignment: AlignmentDirectional.centerStart, child: titleBlock),
          )
        else
          const Spacer(),
        if (actions.isEmpty)
          const SizedBox(width: AppSpacing.xl)
        else
          for (final action in actions) ...[action, const SizedBox(width: _edgeInset)],
      ],
    );

    final titledRow = centerTitle && titleBlock != null
        ? Stack(
            alignment: Alignment.center,
            children: [
              row,
              Center(child: titleBlock),
            ],
          )
        : row;

    // Everything above is built once. Only this is rebuilt as the slot folds,
    // and it reuses the widgets it closes over, so no subtree is rebuilt with
    // it.
    Widget frame(double value) {
      final fold = value.clamp(0.0, 1.0);
      final slot = bottomHeight * (1 - fold);
      final chromeHeight = topInset + rowHeight + slot;
      return SizedBox(
        height: chromeHeight + bar.fadeTail,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: frosted
                  // reeed's material: a translucent tint over the blur, faded
                  // from the midpoint, so content shows through as frost.
                  ? EdgeFade(
                      height: chromeHeight + bar.fadeTail,
                      color: bar.background.withValues(alpha: 0.55),
                      sigma: bar.blurSigma,
                    )
                  : EdgeFade(
                      height: chromeHeight + bar.fadeTail,
                      color: bar.background,
                      sigma: bar.blurSigma,
                      // Opaque through the whole chrome (title row AND the
                      // bottom slot); only the tail fades, so nothing stays
                      // legible under the title and the bottom slot is never
                      // washed.
                      fadeFrom: chromeHeight / (chromeHeight + bar.fadeTail),
                    ),
            ),
            // Content scrolled under the bar is invisible behind the wash; it
            // must not stay tappable through it. The row and the bottom slot
            // paint (and hit-test) above this, so the bar's own controls are
            // unaffected.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: chromeHeight,
              child: const AbsorbPointer(child: SizedBox.expand()),
            ),
            Positioned(top: topInset, left: 0, right: 0, height: rowHeight, child: titledRow),
            if (bottom != null)
              Positioned(
                top: topInset + rowHeight,
                left: 0,
                right: 0,
                height: slot,
                // The slot keeps handing its child the FULL height and clips
                // what no longer fits, so the strip is laid out once and only
                // the cut moves; everything is anchored at the bottom, which
                // is the chrome's own edge, so nothing drifts off it.
                //
                // What the row swallows is a ghost: the fade spends itself
                // early (ease-out), so the clip's edge only ever crosses
                // something already most of the way gone, and the slot leaves
                // by dissolving rather than by being cut in half.
                child: Opacity(
                  opacity: 1 - Curves.easeOutSine.transform(fold),
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.bottomCenter,
                      minHeight: bottomHeight,
                      maxHeight: bottomHeight,
                      child: Transform.translate(
                        offset: Offset(0, -bottomHeight * _foldLead * fold),
                        child: bottom,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final fold = bottomFold;
    if (fold == null) return frame(0);
    return ValueListenableBuilder<double>(
      valueListenable: fold,
      builder: (context, value, _) => frame(value),
    );
  }
}

/// The standard back chevron for [AppTopBar.leading]: a glass circle. Bare, as
/// every bar control is: the bar owns where it sits.
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AppGlassIconButton(
      icon: AppIcons.chevronBackward,
      iconSize: theme.topBar.backChevronSize,
      color: theme.topBar.iconColor,
      onTap: onBack ?? () => Navigator.of(context).maybePop(),
    );
  }
}
