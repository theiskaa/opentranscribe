import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/view/widgets/duo_style.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/animated_reveal.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_toggle.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/safe_sides.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The scroll every settings screen shares: the same insets under the frosted
/// bar, clear of the home indicator and of a side column. One place, so the
/// five screens cannot drift apart.
class SettingsList extends StatelessWidget {
  const SettingsList({required this.children, super.key});

  final List<Widget> children;

  /// The list's side inset, which content that reaches to the band's edge
  /// must bleed back through.
  static const double gutter = AppSpacing.md;

  /// From under the bar to the first content, whatever it is: a card, a
  /// label (which then takes no top of its own), a note.
  static const double lead = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final inner = duoInnerOf(context);
    final panes = PaneLayoutScope.maybeOf(context);
    return SafeSides.scroll(
      builder: (context, sides) => ListView(
        padding: inner
            ? duoDetailInsets(
                width: MediaQuery.sizeOf(context).width + sides.horizontal,
                safe: MediaQuery.paddingOf(context) + sides,
                fold: panes == null
                    ? EdgeInsets.zero
                    : duoFoldInsets(panes.layout, PaneScope.maybeOf(context)?.touch),
                top:
                    AppScaffold.topPaddingOf(context) -
                    MediaQuery.paddingOf(context).top -
                    AppSpacing.md +
                    lead,
                bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
              )
            : EdgeInsets.fromLTRB(
                    gutter,
                    // Tighter than the standard breath: settings sits closer under the bar.
                    AppScaffold.topPaddingOf(context) - AppSpacing.md + lead,
                    gutter,
                    MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
                  ) +
                  sides,
        children: children,
      ),
    );
  }
}

/// A grouped settings card: surface squircle with rows joined by inset
/// dividers. Rows are whatever widgets the caller passes (a [SelectableRow], a
/// custom row).
class SettingsCard extends StatelessWidget {
  const SettingsCard({required this.children, this.dividerInset, super.key});

  final List<Widget> children;

  /// Where the dividers start, for rows that lead with no tile; null lines
  /// them up past the tile.
  final double? dividerInset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    final inner = duoInnerOf(context);
    return DecoratedBox(
      decoration: SuperellipseDecoration(
        borderRadius: inner ? DuoTheme.groupRadius : tokens.cardRadius,
        color: inner ? context.theme.duo.surfaceGrouped : tokens.cardBackground,
        border: inner ? BorderSide.none : BorderSide(color: tokens.cardBorder),
      ),
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) SettingsDivider(inset: dividerInset),
            child,
          ],
        ],
      ),
    );
  }
}

/// The inset hairline [SettingsCard] draws between its rows. Exposed so a row
/// that reveals itself can carry its own leading divider and fold it away with
/// the row (see [AnimatedReveal]).
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({this.inset, super.key});

  /// Null starts past a row's tile, like every kit row.
  final double? inset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return Padding(
      padding: EdgeInsets.only(
        left:
            inset ??
            (duoInnerOf(context)
                ? DuoTheme.groupInset + DuoTheme.groupIcon + AppSpacing.md
                : tokens.dividerInset),
        right: duoInnerOf(context) ? DuoTheme.groupInset : 0,
      ),
      child: Container(
        height: duoInnerOf(context) ? AppDuo.separatorWidth : 1,
        color: duoInnerOf(context) ? context.theme.duo.separator : tokens.dividerColor,
      ),
    );
  }
}

/// A [SelectableRow]'s height, as it lays itself out: its padding around the
/// taller of the tile and the label. For placement math that must know a
/// popup's height before it builds.
double selectableRowHeight(
  SettingsTheme tokens, {
  required TextScaler scaler,
  required double? ambientHeight,
  required bool tile,
  bool inner = false,
}) {
  final label =
      scaler.scale(AppType.subhead.fontSize!) *
      AppType.lineHeightOf(AppType.subhead, TextStyle(height: ambientHeight));
  final content = tile ? math.max(inner ? DuoTheme.groupIcon : tokens.iconTileSize, label) : label;
  return content + tokens.rowPadding.vertical;
}

/// A row you pick from a list, reeed's shape: a tinted chip with a language's
/// flag, the choice's own name, and a checkmark on the current one. The
/// selected row inks and bolds; the rest stay quiet. Tapping the current one
/// is a no-op.
class SelectableRow extends StatelessWidget {
  const SelectableRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.flag,
    super.key,
  });

  final String label;

  /// The leading chip's flag emoji (see `localeFlag`), or null for a plain
  /// choice with no chip (a reflection option).
  final String? flag;
  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final duration = context.reduceMotion ? Duration.zero : theme.motion.crossfade;
    final curve = theme.motion.indicatorCurve;
    return Touchable(
      onTap: onTap,
      haptic: onTap != null,
      child: Padding(
        padding: tokens.rowPadding,
        child: Row(
          children: [
            if (flag case final flag?) ...[
              // The tile stays neutral whatever the selection: the check and
              // the label weight carry it, so every row's tile matches.
              SettingsIconTile(child: LocaleFlag(flag, size: AppIconSize.flag)),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              // One line: a wrapped row would outgrow the height
              // selectableRowHeight places a dropdown by.
              child: SettingsRowLabel(
                label,
                color: selected ? theme.accent : theme.text,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
                oneLine: true,
                // The checkmark's clock, so the pick moves as one.
                duration: duration,
              ),
            ),
            // The checkmark keeps its zero-opacity residency, so the label
            // never reflows.
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: duration,
              curve: curve,
              child: AnimatedScale(
                scale: selected ? 1 : 0.5,
                duration: duration,
                curve: curve,
                child: AppIcon(AppIcons.checkmark, size: AppIconSize.accessory, color: theme.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sheet row's trailing mark: one glyph size for every mark, and one circle
/// the download arrow and the progress ring share, so a download reads as
/// that circle filling.
abstract final class RowMark {
  static const glyph = AppIconSize.body;
  static const circle = 21.0;
  static const stroke = 2.0;
}

/// The fixed column a sheet row's trailing mark stands in, so marks of any
/// width line up down the list; a tappable mark fills it as its target. A row
/// with no mark still holds the column.
class RowMarkSeat extends StatelessWidget {
  const RowMarkSeat({required this.child, required this.height, super.key});

  final Widget child;

  /// No taller than the row's own content, so a mark never grows its row.
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: context.theme.settings.trailingTargetWidth,
    height: height,
    child: Center(child: child),
  );
}

/// The square a settings row leads with: a glyph, a flag, or a drawn mark on
/// the neutral tile, or on [color] for a row that must not read as neutral.
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile({required this.child, this.color, this.accent = false, super.key});

  final Widget child;
  final Color? color;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return Container(
      width: duoInnerOf(context) ? DuoTheme.groupIcon : tokens.iconTileSize,
      height: duoInnerOf(context) ? DuoTheme.groupIcon : tokens.iconTileSize,
      alignment: Alignment.center,
      decoration: SuperellipseDecoration(
        borderRadius: duoInnerOf(context) ? DuoTheme.groupIconRadius : tokens.iconTileRadius,
        color: duoInnerOf(context) && accent
            ? (color ?? context.theme.accent)
            : color ?? tokens.iconTileBackground,
      ),
      child: child,
    );
  }
}

/// A settings row whose whole width toggles a switch: an icon tile, a label
/// over an optional [note] that eases as it opens, folds and rewords, and the
/// drawn [AppToggle]. The row is the 44pt touch target the 31pt switch alone
/// would miss; the knob's own tap wins the arena and carries the haptic, so
/// the row does not double-fire.
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
    this.note,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final enabled = onChanged != null;
    final motion = theme.motion;
    return Touchable(
      onTap: enabled ? () => onChanged!(!value) : null,
      haptic: enabled,
      child: _SettingsRowFrame(
        padding: tokens.rowPadding,
        child: Row(
          children: [
            // The ink eases between live and disabled on the indicator clock,
            // so a row that stops while another control starts moves with it.
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: duoInnerOf(context)
                    ? (enabled ? theme.onAccent : theme.textSecondary)
                    : enabled
                    ? theme.text
                    : theme.textSecondary,
              ),
              duration: context.reduceMotion ? Duration.zero : motion.indicator,
              curve: motion.indicatorCurve,
              builder: (context, content, _) => SettingsIconTile(
                accent: true,
                child: AppIcon(icon, size: AppIconSize.tile, color: content),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SettingsLabelAndNote(
                note: note,
                eased: true,
                label: SettingsRowLabel(label, color: enabled ? theme.text : theme.textSecondary),
              ),
            ),
            // A wrapping label or note must keep off the knob's edge.
            const SizedBox(width: AppSpacing.md),
            AppToggle(value: value, onChanged: onChanged, semanticLabel: label),
          ],
        ),
      ),
    );
  }
}

/// A row's name in [color] and [weight], easing into a new ink or weight on
/// the indicator clock, or on [duration] where the row's other marks keep
/// another one. [oneLine] clips it to a line.
class SettingsRowLabel extends StatelessWidget {
  const SettingsRowLabel(
    this.label, {
    required this.color,
    this.weight = FontWeight.w400,
    this.oneLine = false,
    this.duration,
    super.key,
  });

  final String label;
  final Color color;
  final FontWeight weight;
  final bool oneLine;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    return AnimatedDefaultTextStyle(
      duration: context.reduceMotion ? Duration.zero : (duration ?? motion.indicator),
      curve: motion.indicatorCurve,
      // Merged, not replaced: this sets the label's root style, so it must
      // keep the line height every other row label has.
      style: DefaultTextStyle.of(
        context,
      ).style.merge(AppType.subhead.copyWith(color: color, fontWeight: weight)),
      child: oneLine ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis) : Text(label),
    );
  }
}

/// How a note line reads: quiet as a fact, or inked as an outcome.
enum NoteTone { quiet, positive, negative }

/// A [NoteTone]'s ink, or null for the quiet one, which keeps the note's own.
Color? noteToneInk(AppTheme theme, NoteTone tone) => switch (tone) {
  NoteTone.quiet => null,
  NoteTone.positive => theme.positive,
  NoteTone.negative => theme.danger,
};

/// A row's name over its quiet second line, the one stack every settings row
/// puts in its middle column.
class SettingsLabelAndNote extends StatelessWidget {
  const SettingsLabelAndNote({
    required this.label,
    required this.note,
    this.oneLine = false,
    this.tabular = false,
    this.noteColor,
    this.eased = false,
    super.key,
  });

  final Widget label;
  final String? note;

  /// The note's ink where it tells an outcome; null keeps it quiet.
  final Color? noteColor;

  /// Clips the note to one line, for a row of fixed height, or a line of
  /// figures that must not wrap.
  final bool oneLine;

  /// Figures in the note line up across rows.
  final bool tabular;

  /// The note opens, folds and rewords on the indicator clock, so a row whose
  /// note follows its own control never jumps: the centred marks beside it
  /// ride the height instead of snapping to it. Needs a bounded width: each
  /// wording fills it, so old and new wrap to the same measure mid-fade.
  final bool eased;

  @override
  Widget build(BuildContext context) {
    final style = (tabular ? AppType.digits(AppType.rowNote) : AppType.rowNote).copyWith(
      color: noteColor ?? context.theme.textSecondary,
    );
    final maxLines = oneLine ? 1 : null;
    final overflow = oneLine ? TextOverflow.ellipsis : TextOverflow.clip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        if (eased)
          _EasedNote(note: note, style: style, maxLines: maxLines, overflow: overflow)
        else if (note != null) ...[
          SizedBox(height: context.theme.settings.noteGap),
          Text(note!, maxLines: maxLines, overflow: overflow, style: style),
        ],
      ],
    );
  }
}

/// A note line that reveals and folds with its gap, and crossfades a new
/// wording while its height eases to the new line count.
class _EasedNote extends StatefulWidget {
  const _EasedNote({
    required this.note,
    required this.style,
    required this.maxLines,
    required this.overflow,
  });

  final String? note;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  State<_EasedNote> createState() => _EasedNoteState();
}

class _EasedNoteState extends State<_EasedNote> {
  // Kept through a fold, so the words leave with the line instead of first.
  late String? _shown = widget.note;

  @override
  void didUpdateWidget(_EasedNote old) {
    super.didUpdateWidget(old);
    if (widget.note != null) _shown = widget.note;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return AnimatedReveal(
      visible: widget.note != null,
      child: shown == null
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(top: context.theme.settings.noteGap),
              child: MeltSwap(
                id: shown,
                child: Text(
                  shown,
                  maxLines: widget.maxLines,
                  overflow: widget.overflow,
                  style: widget.style,
                ),
              ),
            ),
    );
  }
}

/// A tappable settings row that performs an action: a leading tile holding a
/// glyph ([icon]) or a drawn mark ([leading]), exactly one of the two; the
/// label, an optional wrapping [note] under it, and an optional trailing accent
/// word before the chevron. [tint] colours the tile and glyph for a row that
/// must read as a warning rather than neutral (a denied-permission prompt).
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
    this.note,
    this.trailing,
    this.tint,
    super.key,
  }) : assert(
         (icon == null) != (leading == null),
         'the tile takes exactly one of a glyph or a mark',
       );

  /// The tile's glyph, or null when [leading] draws the mark instead.
  final IconData? icon;

  /// A drawn mark for the tile in place of a glyph (the club's swatches).
  final Widget? leading;

  final String label;
  final VoidCallback onTap;

  /// A second line saying what the row leads to. Wraps: unlike [SelectableRow]
  /// this row never sits in a popup placed by its row height.
  final String? note;

  final String? trailing;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final inner = duoInnerOf(context);
    final accent = inner ? (tint == null ? theme.onAccent : theme.onDanger) : tint ?? theme.text;
    return Touchable(
      onTap: onTap,
      haptic: true,
      child: _SettingsRowFrame(
        padding: tokens.rowPadding,
        child: Row(
          children: [
            SettingsIconTile(
              accent: true,
              color: inner ? tint : tint?.withValues(alpha: AppAlpha.wash),
              child: leading ?? AppIcon(icon!, size: AppIconSize.tile, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SettingsLabelAndNote(
                note: note,
                label: Text(label, style: AppType.subhead.copyWith(color: theme.text)),
              ),
            ),
            if (trailing != null) ...[
              Text(trailing!, style: AppType.subhead.copyWith(color: theme.accent)),
              const SizedBox(width: AppSpacing.xs),
            ],
            AppIcon(AppIcons.chevronForward, size: tokens.chevronSize, color: tokens.chevronColor),
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
    required this.accent,
    required this.onAccent,
    this.background,
    this.foreground,
    this.child,
    this.aspectRatio = defaultAspectRatio,
    this.radius = defaultRadius,
    this.marked = false,
    super.key,
  });

  static const defaultAspectRatio = 92 / 108;
  static const defaultRadius = 16.0;

  /// The corner seat the check and the club's heart share.
  static const double _badge = AppSizes.badge;
  static const double _badgeGlyph = AppIconSize.badge;

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color onAccent;

  /// The palette the drawn mock previews; unused when [child] fills the tile.
  final Color? background;
  final Color? foreground;

  /// A ready preview (an app icon) in place of the drawn palette mock.
  final Widget? child;
  final double aspectRatio;
  final double radius;

  /// Wears the club's heart in the badge seat: a look the viewer cannot wear yet.
  final bool marked;

  @override
  State<ThemeFamilyCard> createState() => _ThemeFamilyCardState();
}

class _ThemeFamilyCardState extends State<ThemeFamilyCard> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final popCurve = theme.motion.swipePopCurve;
    final foreground = widget.foreground ?? theme.text;
    final faded = foreground.withValues(alpha: 0.4);

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
            aspectRatio: widget.aspectRatio,
            child: AnimatedBuilder(
              animation: _sel,
              builder: (context, _) {
                final t = _sel.value;
                final pop = popCurve.transform(t.clamp(0.0, 1.0));
                // R - r puts the badge's centre on the corner arc's centre, so the
                // two curves are concentric whatever the card's radius.
                final badgeInset = AppRadius.inner(widget.radius, ThemeFamilyCard._badge / 2);
                return Stack(
                  children: [
                    if (widget.child != null)
                      Positioned.fill(
                        child: ClipPath(
                          clipper: ShapeBorderClipper(shape: Superellipse(radius: widget.radius)),
                          child: widget.child,
                        ),
                      )
                    else
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: SuperellipseDecoration(
                            borderRadius: widget.radius,
                            color: widget.background,
                            // The theme's own faint edge, so the card reads as a
                            // real surface in that palette, not a flat swatch.
                            border: BorderSide(color: foreground.withValues(alpha: 0.12)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title in the ACCENT: the theme's defining hue
                                // reads as content, no stray chip to look odd.
                                _MockLine(widthFactor: 0.62, height: 6, color: widget.accent),
                                const SizedBox(height: 9),
                                _MockLine(widthFactor: 0.95, height: 3, color: faded),
                                const SizedBox(height: 5),
                                _MockLine(widthFactor: 0.7, height: 3, color: faded),
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
                                borderRadius: widget.radius,
                                border: BorderSide(color: widget.accent, width: AppStroke.ring),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.marked)
                      Positioned(
                        top: badgeInset,
                        right: badgeInset,
                        child: SizedBox.square(
                          dimension: ThemeFamilyCard._badge,
                          child: Center(
                            child: AppIcon(
                              AppIcons.heartFill,
                              size: ThemeFamilyCard._badgeGlyph,
                              color: widget.accent,
                            ),
                          ),
                        ),
                      ),
                    // Checkmark badge in the accent, popping in with overshoot.
                    if (pop > 0)
                      Positioned(
                        top: badgeInset,
                        right: badgeInset,
                        child: Transform.scale(
                          scale: pop,
                          child: Container(
                            width: ThemeFamilyCard._badge,
                            height: ThemeFamilyCard._badge,
                            decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle),
                            child: Center(
                              child: AppIcon(
                                AppIcons.checkmark,
                                size: ThemeFamilyCard._badgeGlyph,
                                color: widget.onAccent,
                              ),
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

/// One rounded line of a [ThemeFamilyCard]'s mock, [widthFactor] of its width.
class _MockLine extends StatelessWidget {
  const _MockLine({required this.widthFactor, required this.height, required this.color});

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
    ),
  );
}

/// A paragraph of explanation, above or below a card (reeed's description text):
/// footnote, secondary, generously leaded so it reads as help rather than a row.
class SectionInfo extends StatelessWidget {
  const SectionInfo(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: duoInnerOf(context)
          ? const EdgeInsets.fromLTRB(
              DuoTheme.groupInset,
              AppSpacing.sm,
              DuoTheme.groupInset,
              AppSpacing.sm,
            )
          : const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.md),
      child: Text(text, style: AppType.note.copyWith(color: context.theme.textSecondary)),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppType.note.copyWith(color: theme.textSecondary)),
          // The gaps around the link are its hit area too: a taller target,
          // nothing drawn moves.
          Touchable(
            onTap: onTap,
            haptic: true,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.md),
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
          ),
        ],
      ),
    );
  }
}

/// The uppercase group label above a card.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {this.top = AppSpacing.xxl, super.key});

  final String label;

  /// The breath above the label; less where something above already gives it.
  final double top;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.sm, top: top, bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: AppType.eyebrow.copyWith(color: tokens.sectionLabelColor),
      ),
    );
  }
}

class _SettingsRowFrame extends StatelessWidget {
  const _SettingsRowFrame({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inner = duoInnerOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: inner ? DuoTheme.groupRowHeight : 0),
      child: Padding(
        padding: inner ? const EdgeInsets.all(DuoTheme.groupInset) : padding,
        child: child,
      ),
    );
  }
}
