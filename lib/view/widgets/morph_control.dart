import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_loader.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// How a button face is inked: [primary] is the solid button fill, for what
/// fetches or starts work; [secondary] the quiet one, as Restore beside Back up.
enum MorphVariant { primary, secondary }

/// What a [MorphControl] shows: an asking [MorphButton] or a reporting
/// [MorphBar]. A change of face crossfades its words when [morphFaceKey]
/// changes; otherwise they change in place.
sealed class MorphFace {
  const MorphFace();
}

/// The control at the general button's size and type: [label] after an
/// optional [icon], in [variant].
final class MorphButton extends MorphFace {
  const MorphButton({required this.label, this.icon, this.variant = MorphVariant.primary});

  final String label;
  final IconData? icon;
  final MorphVariant variant;
}

/// The control as a slim bar filled from the left to [fill] (0 to 1) under
/// [label]. A null [fill] is work with no measure: an empty bar with the
/// loader before the label.
final class MorphBar extends MorphFace {
  const MorphBar({required this.fill, required this.label});

  final double? fill;
  final String label;
}

/// Which faces are one face to the words' crossfade. A measured bar is one
/// face at every fill, so its sweep runs unbroken; gaining or losing a measure
/// crossfades instead, so the sweep never drains back to empty.
Object morphFaceKey(MorphFace face) => switch (face) {
  MorphBar(:final fill) => (MorphBar, fill == null),
  MorphButton(:final label, :final icon, :final variant) => (MorphButton, label, icon, variant),
};

/// Whether a control draws disabled: a button face with nothing to do, at
/// AppButton's strength. A bar with no tap only reports; it is a state, not a
/// disabled button.
bool morphDisabled(MorphFace face, VoidCallback? onPressed) =>
    face is MorphButton && onPressed == null;

/// One control that is a button while it asks and a slim progress bar while
/// it reports: the button's height, fill and words ease into the bar's on the
/// indicator motion, never a different control swapped in. The cancel disc
/// rides beside it in a seat that opens on the same motion, so the bar's width
/// and its words change together. It fills its width; [semanticLabel] is its
/// one VoiceOver name, so it must carry the state a bar shows.
class MorphControl extends StatelessWidget {
  const MorphControl({
    required this.face,
    required this.semanticLabel,
    required this.onPressed,
    this.cancellable = false,
    this.onCancel,
    this.cancelSemanticLabel,
    super.key,
  }) : assert(!cancellable || (onCancel != null && cancelSemanticLabel != null));

  final MorphFace face;
  final String semanticLabel;

  /// What a tap does. Null makes a bar a face that only reports, and a
  /// button a disabled one.
  final VoidCallback? onPressed;

  /// Whether the cancel seat is open. [onCancel] and [cancelSemanticLabel]
  /// stay wired while it closes, so keep passing them through the close.
  final bool cancellable;
  final VoidCallback? onCancel;
  final String? cancelSemanticLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Pill(face: face, semanticLabel: semanticLabel, onTap: onPressed),
        ),
        _CancelSeat(shown: cancellable, semanticLabel: cancelSemanticLabel, onTap: onCancel),
      ],
    );
  }
}

/// The words on a button face, the general button's, so the face is the
/// button it replaces.
final TextStyle _labelStyle = AppType.callout.copyWith(height: 1);

/// The words in the slim bar, tabular so the percent never shifts.
final TextStyle _barStyle = AppType.digits(AppType.footnote.copyWith(fontWeight: FontWeight.w600));

class _Pill extends StatelessWidget {
  const _Pill({required this.face, required this.semanticLabel, required this.onTap});

  final MorphFace face;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final button = theme.button;
    final motion = theme.motion;
    final duration = context.reduceMotion ? Duration.zero : motion.indicator;
    final face = this.face;
    final variant = switch (face) {
      MorphButton(:final variant) => variant,
      MorphBar() => MorphVariant.secondary,
    };
    // An ink face wears the button's sheen and shadow, on AppButton's own
    // rule (a dark fill only); both fade with the fill as the face changes.
    final inked =
        variant == MorphVariant.primary &&
        button.background.computeLuminance() < button.inkLuminance;
    final (fill, border, ink) = switch (variant) {
      MorphVariant.primary => (button.background, button.background, button.foreground),
      MorphVariant.secondary => (
        button.secondaryBackground,
        button.secondaryBorder,
        button.secondaryForeground,
      ),
    };
    final content = switch (face) {
      MorphBar() => _ProgressBar(face: face),
      MorphButton() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Center(
          child: _ButtonWords(face: face, ink: ink),
        ),
      ),
    };
    final disabled = morphDisabled(face, onTap);
    return Semantics(
      button: onTap != null || disabled,
      enabled: onTap != null ? true : (disabled ? false : null),
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Touchable(
        onTap: onTap,
        haptic: onTap != null,
        // AppButton's press: a scale, no dimming.
        pressedScale: motion.pressScale,
        pressedOpacity: 1,
        child: AnimatedOpacity(
          opacity: disabled ? button.disabledOpacity : 1,
          // The face's own clock, so a control dimming as another starts
          // moves with that one's morph.
          duration: duration,
          curve: motion.indicatorCurve,
          child: AnimatedContainer(
            duration: duration,
            curve: motion.indicatorCurve,
            height: face is MorphBar ? button.bandHeight : button.height,
            decoration: SuperellipseDecoration(
              // Clamped to half the height, so a capsule at either size.
              borderRadius: button.radius,
              color: fill,
              shadows: [
                inked
                    ? button.shadow
                    : button.shadow.copyWith(color: button.shadow.color.withValues(alpha: 0)),
              ],
              border: BorderSide(color: border, width: button.borderWidth),
            ),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                // Out over the border the decoration insets content by, so the
                // sheen starts at the top edge as AppButton's does.
                Positioned(
                  left: -button.borderWidth,
                  top: -button.borderWidth,
                  right: -button.borderWidth,
                  bottom: -button.borderWidth,
                  child: _Sheen(shown: inked, duration: duration, curve: motion.indicatorCurve),
                ),
                // The words ride the same duration and curve as the fill and the
                // cancel's seat, so a face change moves as one.
                AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: motion.indicatorCurve,
                  switchOutCurve: motion.indicatorCurve.flipped,
                  layoutBuilder: meltStack,
                  child: KeyedSubtree(key: ValueKey(morphFaceKey(face)), child: content),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar as the control itself: it fills from the left, its words centred
/// and legible over both halves (the same words twice, the filled copy
/// clipped to the sweep).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.face});

  final MorphBar face;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final button = theme.button;
    final loading = face.fill == null;
    final clipper = ShapeBorderClipper(shape: Superellipse(radius: button.radius));
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: (face.fill ?? 0).clamp(0.0, 1.0)),
      duration: context.reduceMotion ? Duration.zero : theme.motion.indicator,
      curve: theme.motion.indicatorCurve,
      builder: (context, value, _) => ClipPath(
        clipper: clipper,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BarWords(label: face.label, loading: loading, ink: button.secondaryForeground),
            // An empty sweep shows nothing, so it builds no second loader.
            if (value > 0)
              ClipRect(
                clipper: _Sweep(value),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: button.background),
                    _BarWords(label: face.label, loading: loading, ink: button.foreground),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarWords extends StatelessWidget {
  const _BarWords({required this.label, required this.loading, required this.ink});

  final String label;
  final bool loading;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: _barStyle.copyWith(color: ink),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Center(
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLoader(size: AppIconSize.bar, color: ink),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: text),
                  ],
                ],
              )
            : text,
      ),
    );
  }
}

/// Keeps the left [fraction] of the bar, the sweep a filling one makes.
class _Sweep extends CustomClipper<Rect> {
  const _Sweep(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_Sweep old) => old.fraction != fraction;
}

/// The cancel's seat, opening on the pill's own motion so the bar narrows
/// with it instead of the disc shoving the bar aside.
class _CancelSeat extends StatelessWidget {
  const _CancelSeat({required this.shown, required this.semanticLabel, required this.onTap});

  final bool shown;
  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final motion = theme.motion;
    final size = theme.button.bandHeight;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: shown ? 1 : 0),
      duration: context.reduceMotion ? Duration.zero : motion.indicator,
      curve: motion.indicatorCurve,
      builder: (context, open, child) => SizedBox(
        width: (size + AppSpacing.sm) * open,
        height: size,
        // The disc keeps its own size while the seat narrows, and shrinks
        // from the seat's own edge rather than sliding over the bar.
        child: OverflowBox(
          minWidth: size,
          maxWidth: size,
          minHeight: size,
          maxHeight: size,
          alignment: Alignment.centerRight,
          child: Transform.scale(
            scale: open,
            alignment: Alignment.centerRight,
            // A closed seat is not a control: its disc leaves the semantics
            // tree with it.
            child: ExcludeSemantics(excluding: !shown, child: child),
          ),
        ),
      ),
      child: CancelDisc(semanticLabel: semanticLabel, onTap: onTap),
    );
  }
}

/// Stops the work a bar is showing: a danger-tinted disc beside it, the
/// same height as the slim bar so the pair reads as one control. Shared with
/// any row that runs work in place, so every cancel is this one disc.
class CancelDisc extends StatelessWidget {
  const CancelDisc({required this.semanticLabel, required this.onTap, super.key});

  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final size = theme.button.bandHeight;
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Touchable(
        onTap: onTap,
        haptic: true,
        pressedScale: theme.motion.pressIconScale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: theme.button.dangerTint),
          child: Center(
            child: AppIcon(AppIcons.xmark, size: AppIconSize.accessory, color: theme.danger),
          ),
        ),
      ),
    );
  }
}

/// A button face's words: an optional glyph and the label, in the face's ink.
class _ButtonWords extends StatelessWidget {
  const _ButtonWords({required this.face, required this.ink});

  final MorphButton face;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final icon = face.icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          AppIcon(icon, size: AppIconSize.bar, color: ink),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            face.label,
            maxLines: 1,
            // Faded at the edge, not cut to an ellipsis: the pill narrows as
            // the cancel seat opens, and a melting label must not re-break.
            softWrap: false,
            overflow: TextOverflow.fade,
            style: _labelStyle.copyWith(color: ink),
          ),
        ),
      ],
    );
  }
}

/// The button's sheen over an ink face, faded rather than blended out, since a
/// gradient and a flat fill do not animate into each other.
class _Sheen extends StatelessWidget {
  const _Sheen({required this.shown, required this.duration, required this.curve});

  final bool shown;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final button = context.theme.button;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: duration,
        curve: curve,
        child: DecoratedBox(
          decoration: SuperellipseDecoration(
            borderRadius: button.radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: button.sheenStops,
              colors: [button.sheen, button.sheen.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
