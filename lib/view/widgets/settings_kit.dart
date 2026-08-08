import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/app_toggle.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The scroll every settings screen shares: the same insets under the frosted
/// bar and clear of the home indicator. One place, so the five screens cannot
/// drift apart (one used to miss the bottom safe-area inset).
class SettingsList extends StatelessWidget {
  const SettingsList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        // Tighter than the standard breath: settings sits closer under the bar.
        AppScaffold.topPaddingOf(context) - AppSpacing.md,
        AppSpacing.md,
        MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
      ),
      children: children,
    );
  }
}

/// A grouped settings card: surface squircle with rows joined by inset
/// dividers. Rows are whatever widgets the caller passes (a [SelectableRow], a
/// custom row).
class SettingsCard extends StatelessWidget {
  const SettingsCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return DecoratedBox(
      decoration: SuperellipseDecoration(
        borderRadius: tokens.cardRadius,
        color: tokens.cardBackground,
        border: BorderSide(color: tokens.cardBorder),
      ),
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[if (i > 0) const SettingsDivider(), child],
        ],
      ),
    );
  }
}

/// The inset hairline [SettingsCard] draws between its rows. Exposed so a row
/// that reveals itself can carry its own leading divider and fold it away with
/// the row (see [AnimatedReveal]).
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return Padding(
      padding: EdgeInsets.only(left: tokens.dividerInset),
      child: Container(height: 1, color: tokens.dividerColor),
    );
  }
}

/// A language row you pick from a list, reeed's shape: a tinted flag chip, the
/// language in its own name, and a checkmark on the current one. The selected
/// row inks and bolds; the rest stay quiet. Tapping the current one is a no-op.
class SelectableRow extends StatelessWidget {
  const SelectableRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.flag,
    this.leading,
    this.note,
    this.dimmed = false,
    super.key,
  });

  final String label;

  /// A quiet second line saying what the choice actually is (what an export
  /// format writes). One line, and only inside a card: it makes the row taller
  /// than the fixed height showAppDropdown estimates its popup by.
  final String? note;

  /// The leading chip's flag emoji (see `localeFlag`), or null for a plain
  /// choice with no chip (a reflection option).
  final String? flag;

  /// A widget for the leading chip instead of a flag (a format's brand mark).
  final Widget? leading;
  final bool selected;

  /// A kept-but-unavailable choice (an unsupported language): shown honestly,
  /// quieter than the rest.
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final active = selected && !dimmed;
    final duration = context.reduceMotion ? Duration.zero : theme.motion.crossfade;
    final curve = theme.motion.indicatorCurve;
    final chipColor = active ? theme.accent.withValues(alpha: 0.14) : tokens.iconTileBackground;
    return Touchable(
      onTap: onTap,
      haptic: onTap != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (flag != null || leading != null) ...[
              // TweenAnimationBuilder rather than AnimatedContainer: the
              // superellipse decoration has no lerp, so AnimatedContainer
              // would snap the color halfway instead of fading it.
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: chipColor),
                duration: duration,
                curve: curve,
                builder: (context, color, child) => Container(
                  width: tokens.iconTileSize,
                  height: tokens.iconTileSize,
                  alignment: Alignment.center,
                  decoration: SuperellipseDecoration(
                    borderRadius: tokens.iconTileRadius,
                    color: color ?? chipColor,
                  ),
                  child: child,
                ),
                child: leading ?? LocaleFlag(flag!, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: curve,
                    style: AppType.subhead.copyWith(
                      color: dimmed ? theme.textSecondary : (active ? theme.accent : theme.text),
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                    // One line: a wrapped row would break showAppDropdown's
                    // fixed row estimate and misplace the popup.
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.footnote.copyWith(color: theme.textSecondary, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            // Always in the row at zero opacity, so the label never reflows
            // when the checkmark arrives.
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: duration,
              curve: curve,
              child: AnimatedScale(
                scale: active ? 1 : 0.5,
                duration: duration,
                curve: curve,
                child: AppIcon(AppIcons.checkmark, size: 14, color: theme.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A settings row whose whole width toggles a switch: an icon tile, a label,
/// and the drawn [AppToggle]. The row is the 44pt touch target the 31pt switch
/// alone would miss; the knob's own tap wins the arena and carries the haptic,
/// so the row does not double-fire.
///
/// A null [onChanged] disables the row: it stops responding, the label dims, and
/// the knob draws at half strength - for a toggle whose precondition is not met
/// (reflections off, so a weekly nudge could not fire anyway).
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final enabled = onChanged != null;
    final content = enabled ? theme.text : theme.textSecondary;
    return Touchable(
      onTap: enabled ? () => onChanged!(!value) : null,
      haptic: enabled,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: tokens.iconTileSize,
              height: tokens.iconTileSize,
              alignment: Alignment.center,
              decoration: SuperellipseDecoration(
                borderRadius: tokens.iconTileRadius,
                color: tokens.iconTileBackground,
              ),
              child: AppIcon(icon, size: 16, color: content),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: AppType.subhead.copyWith(color: content)),
            ),
            AppToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A tappable settings row that performs an action: a leading tile + glyph, a
/// label, and an optional trailing accent word followed by a chevron. [tint]
/// colours the tile and glyph for a row that must read as a warning rather than
/// neutral (a denied-permission prompt).
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final accent = tint ?? theme.text;
    return Touchable(
      onTap: onTap,
      haptic: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: tokens.iconTileSize,
              height: tokens.iconTileSize,
              alignment: Alignment.center,
              decoration: SuperellipseDecoration(
                borderRadius: tokens.iconTileRadius,
                color: tint == null ? tokens.iconTileBackground : tint!.withValues(alpha: 0.14),
              ),
              child: AppIcon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: AppType.subhead.copyWith(color: theme.text)),
            ),
            if (trailing != null) ...[
              Text(trailing!, style: AppType.subhead.copyWith(color: theme.accent)),
              const SizedBox(width: AppSpacing.xs),
            ],
            AppIcon(AppIcons.chevronForward, size: 14, color: theme.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// A long-running action row: icon tile, label, and a trailing seat the
/// spinner takes while the operation runs, showing [detail] otherwise.
/// [tint] colors the tile, icon and label for a destructive flavor. A null
/// [onTap] disables the row.
class SettingsBusyRow extends StatelessWidget {
  const SettingsBusyRow({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
    this.detail,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onTap;
  final String? detail;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final enabled = onTap != null;
    final accent = tint ?? theme.accent;
    final labelColor = switch ((enabled, tint)) {
      (false, _) => theme.textSecondary,
      (true, null) => theme.text,
      (true, _) => tint!,
    };
    return Touchable(
      onTap: onTap,
      haptic: enabled,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: tokens.iconTileSize,
              height: tokens.iconTileSize,
              alignment: Alignment.center,
              decoration: SuperellipseDecoration(
                borderRadius: tokens.iconTileRadius,
                color: enabled ? accent.withValues(alpha: 0.14) : tokens.iconTileBackground,
              ),
              child: AppIcon(icon, size: 16, color: enabled ? accent : theme.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: AppType.subhead.copyWith(color: labelColor)),
            ),
            AnimatedSwitcher(
              duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
              child: busy
                  ? AppSpinner(size: 16, color: theme.textSecondary)
                  : detail != null
                  ? Text(
                      detail!,
                      key: ValueKey(detail),
                      style: AppType.digits(AppType.subhead).copyWith(color: theme.textSecondary),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A theme preview: a small mock of the family in the CURRENT appearance - its
/// background, an accent title line, two ink body lines - with the name below.
/// Selecting picks the family (mode is unchanged) and fades an accent ring onto
/// the edge while a checkmark badge pops in; both spring, and go instant under
/// Reduce Motion.
class ThemeFamilyCard extends StatefulWidget {
  const ThemeFamilyCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.accent,
    required this.onAccent,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final Color accent;
  final Color onAccent;

  @override
  State<ThemeFamilyCard> createState() => _ThemeFamilyCardState();
}

class _ThemeFamilyCardState extends State<ThemeFamilyCard> with SingleTickerProviderStateMixin {
  static const _radius = 16.0;

  late final AnimationController _sel = AnimationController(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(ThemeFamilyCard old) {
    super.didUpdateWidget(old);
    if (old.selected == widget.selected) return;
    final target = widget.selected ? 1.0 : 0.0;
    if (context.reduceMotion) {
      _sel.value = target;
    } else {
      _sel.animateTo(target, duration: context.motionNow.indicator);
    }
  }

  @override
  void dispose() {
    _sel.dispose();
    super.dispose();
  }

  Widget _bar(double widthFactor, double height, Color color) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final popCurve = theme.motion.swipePopCurve;
    final faded = widget.foreground.withValues(alpha: 0.4);

    return Touchable(
      onTap: () {
        Haptics.selection();
        widget.onTap();
      },
      pressedScale: theme.motion.pressIconScale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 92 / 108,
            child: AnimatedBuilder(
              animation: _sel,
              builder: (context, _) {
                final t = _sel.value;
                final pop = popCurve.transform(t.clamp(0.0, 1.0));
                return Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: SuperellipseDecoration(
                          borderRadius: _radius,
                          color: widget.background,
                          // The theme's own faint edge, so the card reads as a
                          // real surface in that palette, not a flat swatch.
                          border: BorderSide(color: widget.foreground.withValues(alpha: 0.12)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title in the ACCENT: the theme's defining hue
                              // reads as content, no stray chip to look odd.
                              _bar(0.62, 6, widget.accent),
                              const SizedBox(height: 9),
                              _bar(0.95, 3, faded),
                              const SizedBox(height: 5),
                              _bar(0.7, 3, faded),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Accent ring on the edge, faded in (no layout shift).
                    if (t > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: t,
                            child: DecoratedBox(
                              decoration: SuperellipseDecoration(
                                borderRadius: _radius,
                                border: BorderSide(color: widget.accent, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Checkmark badge in the accent, popping in with overshoot.
                    if (pop > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Transform.scale(
                          scale: pop,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle),
                            child: Center(
                              child: AppIcon(AppIcons.checkmark, size: 11, color: widget.onAccent),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(
              color: widget.selected ? theme.accent : theme.text,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A paragraph of explanation, above or below a card (reeed's description text):
/// footnote, secondary, generously leaded so it reads as help rather than a row.
class SectionInfo extends StatelessWidget {
  const SectionInfo(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.md),
      child: Text(
        text,
        style: AppType.footnote.copyWith(color: context.theme.textSecondary, height: 1.4),
      ),
    );
  }
}

/// A [SectionInfo] that ends in an action: the explanatory line, then a bold
/// accent link on its own line ("Turn on reflections"). For a precondition the
/// reader can fix in one tap, where a full action-row card would shout louder
/// than a footnote should.
class SectionInfoLink extends StatelessWidget {
  const SectionInfoLink({
    required this.text,
    required this.linkLabel,
    required this.onTap,
    this.icon = AppIcons.chevronForward,
    super.key,
  });

  final String text;
  final String linkLabel;
  final VoidCallback onTap;

  /// The trailing glyph after the link. Defaults to a forward chevron for an
  /// in-app jump; pass [AppIcons.arrowUpRight] for a link that leaves the app.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppType.footnote.copyWith(color: theme.textSecondary, height: 1.4)),
          const SizedBox(height: AppSpacing.xs),
          Touchable(
            onTap: onTap,
            haptic: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  linkLabel,
                  style: AppType.footnote.copyWith(
                    color: theme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                AppIcon(icon, size: 10, color: theme.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The uppercase group label above a card.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        top: AppSpacing.xxl,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppType.eyebrow.copyWith(color: tokens.sectionLabelColor),
      ),
    );
  }
}
