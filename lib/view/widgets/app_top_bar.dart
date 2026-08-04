import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/core/utils/platform_caps.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/edge_fade.dart';
import 'package:opentranscribe/view/widgets/glass_icon_button.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Where a bar control sits relative to the screen edge, and to the next
/// control along. One number for both, so the chrome reads as a single rhythm.
const double _edgeInset = AppSpacing.md;

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

    final chromeHeight = topInset + rowHeight + bottomHeight;
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
                ? _BarMaterial(
                    chromeHeight: chromeHeight,
                    color: bar.background.withValues(alpha: TopBarTheme.frostAlpha),
                    sigma: bar.blurSigma,
                  )
                : _BarMaterial(
                    chromeHeight: chromeHeight,
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
              height: bottomHeight,
              child: bottom!,
            ),
        ],
      ),
    );
  }
}

/// The bar's material. On iOS 26 it is the native [LiquidEdgeFade]: a Flutter
/// [EdgeFade] cannot cover a platform view (the engine injects a blur over it
/// that breaks Liquid Glass into an opaque black rectangle), while the native
/// material blurs platform views and Flutter content alike, so native glass
/// controls may scroll under the bar. Below iOS 26 nothing native scrolls
/// under, and the drawn [EdgeFade] stands. [sigma] only shapes the drawn
/// fallback; the native blur radius is the system material's.
class _BarMaterial extends StatelessWidget {
  const _BarMaterial({
    required this.chromeHeight,
    required this.color,
    required this.sigma,
    this.fadeFrom = 0.5,
  });

  final double chromeHeight;
  final Color color;
  final double sigma;
  final double fadeFrom;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final height = chromeHeight + theme.topBar.fadeTail;
    final drawn = EdgeFade(height: height, color: color, sigma: sigma, fadeFrom: fadeFrom);
    if (!PlatformCaps.nativeGlass) return drawn;

    return LiquidEdgeFade(
      height: height,
      chromeHeight: chromeHeight,
      color: color,
      fadeFrom: fadeFrom,
      isDark: theme.brightness == Brightness.dark,
      placeholderBuilder: (_) => drawn,
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
