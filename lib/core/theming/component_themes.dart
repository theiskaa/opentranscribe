import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';

/// Component token groups. Pure data: colors and doubles only, so user themes
/// serialize cleanly later (durations live in AppMotion). Color fields are
/// required and derived from the base palette in `AppTheme.fromBase`;
/// dimension fields carry the design defaults and stay individually
/// overridable.

/// The blurred top bar content scrolls under.
@immutable
final class TopBarTheme {
  const TopBarTheme({
    required this.background,
    required this.titleColor,
    required this.iconColor,
    this.blurSigma = 50.0,
    this.height = 52.0,
    this.largeHeight = 72.0,
    this.fadeTail = 24.0,
    this.backChevronSize = 18.0,
  });

  final Color background;
  final Color titleColor;
  final Color iconColor;
  final double blurSigma;
  final double height;

  /// Content row height for title bars (a display-size title, optionally with
  /// a subtitle under it).
  final double largeHeight;

  /// How far the material's fade runs past the content row, so glyphs melt at
  /// the bar's edge instead of clipping.
  final double fadeTail;
  final double backChevronSize;
}

/// The general button (primary fill, secondary surface, danger reuses primary
/// geometry with the base `danger` color at the use site).
@immutable
final class ButtonTheme {
  const ButtonTheme({
    required this.background,
    required this.pressed,
    required this.foreground,
    required this.sheen,
    required this.shadow,
    required this.secondaryBackground,
    required this.secondaryPressed,
    required this.secondaryForeground,
    required this.secondaryBorder,
    this.disabledOpacity = 0.5,
    this.height = 52.0,
    this.radius = AppRadius.pill,
  });

  final Color background;
  final Color pressed;
  final Color foreground;

  /// Blended over the top quarter of dark fills for the machined look.
  final Color sheen;
  final BoxShadow shadow;
  final Color secondaryBackground;
  final Color secondaryPressed;
  final Color secondaryForeground;
  final Color secondaryBorder;
  final double disabledOpacity;
  final double height;
  final double radius;
}

/// The onboarding dash page indicator.
@immutable
final class PageIndicatorTheme {
  const PageIndicatorTheme({
    required this.active,
    required this.inactive,
    this.dashWidth = 18.0,
    this.dashHeight = 3.0,
    this.gap = 8.0,
  });

  final Color active;
  final Color inactive;
  final double dashWidth;
  final double dashHeight;
  final double gap;
}

/// The week strip under the date bar on home.
@immutable
final class CalendarTheme {
  const CalendarTheme({
    required this.weekdayLabelColor,
    required this.dayNumberColor,
    required this.disabledDayColor,
    required this.todayColor,
    required this.tileBorder,
    required this.tileBorderDisabled,
    required this.cursorFill,
    required this.cursorBorder,
    this.tileRadius = 14.0,
    this.tileGap = 5.0,
    this.dotSize = 4.0,
    this.cellHeight = 60.0,
    this.dayNumberSize = 17.0,
  });

  final Color weekdayLabelColor;

  /// Days with records; every other day renders in [disabledDayColor] and does
  /// not respond.
  final Color dayNumberColor;
  final Color disabledDayColor;
  final Color todayColor;

  /// Each day is its own OUTLINED tile - no fill at rest; inert days carry
  /// the fainter outline.
  final Color tileBorder;
  final Color tileBorderDisabled;

  /// The viewed day is the only filled tile, and its outline strengthens.
  final Color cursorFill;
  final Color cursorBorder;
  final double tileRadius;

  /// Breathing room between neighboring tiles.
  final double tileGap;

  /// The dot inside today's tile, in [todayColor].
  final double dotSize;

  /// One tile's height, which is the strip's height.
  final double cellHeight;
  final double dayNumberSize;
}

/// The records list: hairline-bordered cards under mixed-case day splitters.
/// Flat and unfilled - the page background shows through; a crisp 1px border
/// draws each entry, and typography carries the hierarchy inside.
@immutable
final class EntryListTheme {
  const EntryListTheme({
    required this.titleColor,
    required this.excerptColor,
    required this.metaColor,
    required this.splitterColor,
    required this.railColor,
    required this.nodeColor,
    this.railWidth = 1.0,
    this.nodeSize = 6.0,
    this.railGutter = AppSpacing.lg,
    this.excerptLines = 4,
  });

  /// The user's title, a real headline when one exists.
  final Color titleColor;

  /// The transcript excerpt, the card's main content.
  final Color excerptColor;
  final Color metaColor;
  final Color splitterColor;

  /// The hairline a day's records hang off, and the node marking each one on
  /// it. There is no card: no fill, no border, no shadow. The node is the
  /// stronger ink of the two - the rail is structure, the node is the record.
  final Color railColor;
  final Color nodeColor;
  final double railWidth;
  final double nodeSize;

  /// Rail to text. The node sits flush with the screen's content margin, so
  /// this is what puts the text on the same line as the day splitter above it.
  final double railGutter;

  final int excerptLines;
}

/// The recorder screen: timer, waveform, live transcript. The pause, restart,
/// and complete buttons carry no tokens here; they consume [ButtonTheme]
/// (secondary geometry for the flanks, primary for complete).
@immutable
final class RecorderTheme {
  const RecorderTheme({
    required this.timerColor,
    required this.waveformBar,
    required this.waveformBarIdle,
    required this.waveformBaseline,
    required this.liveTextColor,
    required this.liveTextFadedColor,
    this.waveformBarWidth = 3.0,
    this.waveformGap = 3.0,
    this.waveformHeight = 96.0,
    this.waveformFade = 48.0,
    this.controlSize = 52.0,
  });

  final Color timerColor;
  final Color waveformBar;
  final Color waveformBarIdle;

  /// The line silence rests on, and the band's body before a single sample has
  /// arrived.
  final Color waveformBaseline;
  final Color liveTextColor;
  final Color liveTextFadedColor;
  final double waveformBarWidth;
  final double waveformGap;

  /// The band's full height, peak to peak. It is the only thing on the screen
  /// answering the voice in real time, so it is sized to carry that: a shorter
  /// band reads as a level meter rather than as the sound itself.
  final double waveformHeight;

  /// How far the band's bars fade at each end, so they arrive and leave
  /// instead of being cut.
  final double waveformFade;

  /// Every control circle on the recorder's row. One size: the complete button
  /// carries its weight with a FILL, not with a bigger footprint.
  final double controlSize;
}

/// The audio player on entry detail.
@immutable
final class PlayerTheme {
  const PlayerTheme({
    required this.progress,
    required this.waveRemaining,
    required this.segmentColor,
    required this.activeSegmentHighlight,
    required this.skeletonBase,
    required this.skeletonHighlight,
    this.waveBarWidth = 3.0,
    this.waveGap = 3.0,
    this.waveHeight = 40.0,
    this.controlSize = 40.0,
    this.skeletonLineHeight = 11.0,
    this.skeletonLineGap = 15.0,
    this.skeletonRadius = AppRadius.sm,
  });

  /// The played part of the wave, and the quiet tone the rest is drawn in. The
  /// boundary between them IS the playhead, which is why there is no thumb.
  final Color progress;
  final Color waveRemaining;

  /// The transcript reads at ONE weight, whatever is playing; the segment under
  /// the playhead is marked with a wash behind it instead of the rest being
  /// dimmed, so following the audio never costs the page its legibility.
  final Color segmentColor;
  final Color activeSegmentHighlight;

  /// The transcript skeleton shown while a (re-)transcription is in flight: the
  /// resting bar fill and the sheen that sweeps across it. Ink at low alpha, so
  /// the placeholder reads as the page's own quiet, not a foreign grey.
  final Color skeletonBase;
  final Color skeletonHighlight;

  /// One bar of the wave, and its distance to the next. Shared geometry with
  /// the recorder's band on purpose: the same recording, drawn twice.
  final double waveBarWidth;
  final double waveGap;

  /// The wave's full height, peak to peak.
  final double waveHeight;

  /// The speed chip's tap-target height, matched to the wave's height.
  final double controlSize;

  /// One skeleton line's height and the gap to the next, sized to the body
  /// text the placeholder stands in for.
  final double skeletonLineHeight;
  final double skeletonLineGap;
  final double skeletonRadius;
}

/// Grouped settings cards, rows, and toggles.
@immutable
final class SettingsTheme {
  const SettingsTheme({
    required this.cardBackground,
    required this.cardBorder,
    required this.iconTileBackground,
    required this.iconColor,
    required this.dangerIconTint,
    required this.chevronColor,
    required this.dividerColor,
    required this.sectionLabelColor,
    required this.toggleActive,
    this.cardRadius = AppRadius.card,
    this.iconTileRadius = AppRadius.sm,
    this.iconTileSize = 32.0,
    this.chevronSize = 12.0,
    this.dividerInset = 58.0,
  });

  final Color cardBackground;
  final Color cardBorder;
  final Color iconTileBackground;
  final Color iconColor;

  /// Tile tint behind a destructive row's icon; the icon itself uses the base
  /// `danger` color.
  final Color dangerIconTint;
  final Color chevronColor;
  final Color dividerColor;
  final Color sectionLabelColor;
  final Color toggleActive;
  final double cardRadius;
  final double iconTileRadius;
  final double iconTileSize;
  final double chevronSize;
  final double dividerInset;
}

/// The inline error indicator: a quiet pill that pulses a danger dot and opens
/// a details sheet on tap. A surface card with one hue (the dot), so it reads as
/// the app's own, not a system alert pasted in.
@immutable
final class ErrorPillTheme {
  const ErrorPillTheme({
    required this.background,
    required this.border,
    required this.dot,
    required this.text,
    required this.chevron,
    this.height = 46.0,
    this.radius = AppRadius.chip,
    this.dotSize = 8.0,
    this.blinkMinOpacity = 0.25,
  });

  final Color background;
  final Color border;

  /// The one hue: the pulsing dot that says "something is wrong here".
  final Color dot;
  final Color text;
  final Color chevron;
  final double height;
  final double radius;
  final double dotSize;

  /// How far the dot dims at the bottom of its breath, 1 being no dimming.
  final double blinkMinOpacity;
}

/// The onboarding pages.
@immutable
final class OnboardingTheme {
  const OnboardingTheme({
    required this.logoTileBackground,
    required this.logoTileBorder,
    required this.titleColor,
    required this.bodyColor,
    required this.handleColor,
  });

  final Color logoTileBackground;
  final Color logoTileBorder;
  final Color titleColor;
  final Color bodyColor;
  final Color handleColor;
}

/// Depth cues for a horizontal page push (the SlidePage transition): a dim over
/// the page below and a shadow off the arriving page's leading edge. Tuned per
/// brightness in `AppTheme.fromBase`, because a dark scrim over a dark page
/// needs more presence to read than over a light one.
@immutable
final class NavigationTheme {
  const NavigationTheme({required this.scrim, required this.edgeShadow});

  /// Dims the page below while a pushed page is over it.
  final Color scrim;

  /// The shadow cast off the leading edge of the arriving page, fading inward.
  final Color edgeShadow;
}
