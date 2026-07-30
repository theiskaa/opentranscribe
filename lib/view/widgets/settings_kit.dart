import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
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
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.only(left: tokens.dividerInset),
                child: Container(height: 1, color: tokens.dividerColor),
              ),
            child,
          ],
        ],
      ),
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
    this.dimmed = false,
    super.key,
  });

  final String label;

  /// The leading chip's flag emoji (see `localeFlag`), or null for a plain
  /// choice with no chip (a reflection option).
  final String? flag;
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
    return Touchable(
      onTap: onTap,
      haptic: onTap != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (flag != null) ...[
              Container(
                width: tokens.iconTileSize,
                height: tokens.iconTileSize,
                alignment: Alignment.center,
                decoration: SuperellipseDecoration(
                  borderRadius: tokens.iconTileRadius,
                  color: active ? theme.accent.withValues(alpha: 0.14) : tokens.iconTileBackground,
                ),
                child: LocaleFlag(flag!, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text(
                label,
                style: AppType.subhead.copyWith(
                  color: dimmed ? theme.textSecondary : (active ? theme.accent : theme.text),
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (active) AppIcon(AppIcons.checkmark, size: 14, color: theme.accent),
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
