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
  /// The frost recipe's tint alpha, shared with every drawn glass surface
  /// (the scrubber capsule) so "the top bar's material" stays one number.
  static const frostAlpha = 0.55;

  const TopBarTheme({
    required this.background,
    required this.titleColor,
    required this.iconColor,
    this.blurSigma = 50.0,
    this.height = 52.0,
    this.largeHeight = 72.0,
    this.fadeTail = 24.0,
    this.backChevronSize = 18.0,
    this.actionSize = 44.0,
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

  /// Tap target for a bar action, and the seat anything standing in for one
  /// (a spinner) must fill so the bar's layout does not shift.
  final double actionSize;
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
    this.compactHeight = 36.0,
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

  /// An inline card action, sized to sit inside content rather than end it.
  final double compactHeight;
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
    this.activeBulge = 3.0,
    this.hitHeight = 44.0,
  });

  final Color active;
  final Color inactive;
  final double dashWidth;
  final double dashHeight;
  final double gap;

  /// Extra width on the active dash, so position reads by shape too.
  final double activeBulge;

  /// A tappable dash's hit area, finger-sized around a three-point dash.
  final double hitHeight;
}

/// The home reflection card: a quiet panel on its own ground holding the
/// week's excerpt.
@immutable
final class ReflectionCardTheme {
  const ReflectionCardTheme({required this.background, required this.border, required this.dither});

  final Color background;
  final Color border;

  /// The corner dither's cell color. Dim by construction: the field sits
  /// under the excerpt's tail and must never contest the text.
  final Color dither;
}

/// The reflections pager's floating scrubber capsule: a small frosted pill at
/// bottom center holding the ink dot strip.
@immutable
final class ScrubberTheme {
  const ScrubberTheme({
    required this.tint,
    required this.border,
    required this.ink,
    required this.track,
    this.blurSigma = 30.0,
    this.height = 38.0,
    this.topBand = 32.0,
    this.slack = 24.0,
    this.sinkDistance = 12.0,
    this.dotSize = 9.0,
    this.gap = 10.0,
    this.activeScale = 1.4,
    this.neckWaist = 0.6,
    this.inkStretch = 0.25,
  });

  /// The frost tint drawn over the blur, translucent so text reads through.
  final Color tint;
  final Color border;

  /// The moving position blob, and the empty dots it travels between.
  final Color ink;
  final Color track;
  final double blurSigma;

  /// Visual capsule height; the touch target is padded past 44 around it.
  final double height;

  /// Reading depth inside which the capsule always shows.
  final double topBand;

  /// Directional travel a scroll needs before the capsule hides or returns,
  /// so pixel jitter never flickers it.
  final double slack;

  /// How far the capsule sinks toward the screen edge as its fade runs out.
  final double sinkDistance;

  /// The dot strip's geometry, the scrubber's own: the capsule is a grabbable
  /// control, not a passive marker. One dot plus one [gap] is also the
  /// scrub's pitch, one week of travel.
  final double dotSize;
  final double gap;

  /// The resting ink dot's size over an empty dot, so position reads by
  /// weight as well as color.
  final double activeScale;

  /// The connecting stream's waist, as a fraction of the smaller blob it
  /// bridges: below 1 the neck pinches, which is what reads as liquid.
  final double neckWaist;

  /// How much each blob elongates toward the stream while it runs (height
  /// compresses in step, so the ink keeps its volume).
  final double inkStretch;
}

/// The week strip under the date bar on home.
@immutable
final class CalendarTheme {
  const CalendarTheme({
    required this.weekdayLabelColor,
    required this.dayNumberColor,
    required this.disabledDayColor,
    required this.todayDot,
    required this.tileFill,
    required this.tileFillMuted,
    required this.cursorBorder,
    required this.chipInk,
    required this.onChipInk,
    this.tileRadius = 14.0,
    this.tileGap = 5.0,
    this.dotSize = 4.0,
    this.cellHeight = 60.0,
    this.dayNumberSize = 17.0,
  });

  final Color weekdayLabelColor;

  /// The weekday letter over an inert day, faded from [weekdayLabelColor] the
  /// same way [disabledDayColor] mutes the number.
  Color get disabledWeekdayLabelColor => weekdayLabelColor.withValues(alpha: 0.5);

  /// Days with records; every other day renders in [disabledDayColor] and does
  /// not respond.
  final Color dayNumberColor;
  final Color disabledDayColor;

  /// The dot under today's number: a fixed landmark in a different grammar
  /// from the cursor's moving border, so the two compose when you are
  /// viewing today.
  final Color todayDot;

  /// A day's soft resting chip: records at full strength, nothing at a
  /// whisper, so the row reads what the week held at a glance.
  final Color tileFill;
  final Color tileFillMuted;

  /// The soft border that marks the viewed day: where you are.
  final Color cursorBorder;

  /// A chip filled solid: the reflections strip's "this day holds a
  /// reflection", the one state strong enough to read as tappable.
  final Color chipInk;
  final Color onChipInk;

  /// Density dots on the month page's week rows, one grammar with the chips:
  /// full [todayDot] = a reflection, these two = entries only and nothing.
  Color get dotEntries => todayDot.withValues(alpha: 0.35);
  Color get dotEmpty => todayDot.withValues(alpha: 0.12);

  final double tileRadius;

  /// Breathing room between neighboring tiles.
  final double tileGap;

  /// The dot under today's number, in [todayDot].
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

  /// The left inset that lands content on the records' TEXT column (content
  /// margin + rail gutter). One source for the day splitter, the reflection
  /// card, and the quiet-week marker, so a rail change cannot un-align them.
  double get textColumnInset => AppSpacing.xl + railGutter;
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

/// The revision diff's ink: what a change removed and what it added, each as
/// text color plus the wash behind it. Derived from the base danger and
/// positive colors, so every family shows ITS red and green, not a stock pair.
@immutable
final class DiffTheme {
  const DiffTheme({
    required this.removed,
    required this.removedWash,
    required this.added,
    required this.addedWash,
  });

  final Color removed;
  final Color removedWash;
  final Color added;
  final Color addedWash;
}

/// The audio player on entry detail.
@immutable
final class PlayerTheme {
  const PlayerTheme({
    required this.progress,
    required this.waveRemaining,
    required this.segmentColor,
    required this.activeSegmentHighlight,
    this.waveBarWidth = 3.0,
    this.waveGap = 3.0,
    this.waveHeight = 40.0,
    this.controlSize = 40.0,
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

  /// One bar of the wave, and its distance to the next. Shared geometry with
  /// the recorder's band on purpose: the same recording, drawn twice.
  final double waveBarWidth;
  final double waveGap;

  /// The wave's full height, peak to peak.
  final double waveHeight;

  /// The speed chip's tap-target height, matched to the wave's height.
  final double controlSize;
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
    this.rowPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  /// Every row's inset, the kit's and any row built to sit among them.
  final EdgeInsets rowPadding;
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
    this.shakeTravel = 5.0,
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

  /// How far the announcing shake throws the pill off centre.
  final double shakeTravel;
}

/// The one-shot hint callout: a surface card with a caret at what it explains.
@immutable
final class CalloutTheme {
  const CalloutTheme({
    required this.background,
    required this.border,
    required this.text,
    this.radius = AppRadius.card,
    this.caretSize = 8.0,
    this.maxWidth = 300.0,
  });

  final Color background;
  final Color border;
  final Color text;
  final double radius;

  /// The caret's height; its base is twice this.
  final double caretSize;
  final double maxWidth;
}

/// The bottom sheet: the panel every raised message shares. Content-sized, so
/// the tokens here are its frame, not its height.
@immutable
final class SheetTheme {
  const SheetTheme({
    required this.background,
    required this.grabberColor,
    this.radius = AppRadius.panel,
    this.grabberWidth = 36.0,
    this.grabberHeight = 5.0,
    this.dismissDrag = 120.0,
    this.flingVelocity = 700.0,
    this.maxHeightFraction = 0.7,
    this.tallMaxHeightFraction = 0.92,
  });

  final Color background;
  final Color grabberColor;
  final double radius;
  final double grabberWidth;
  final double grabberHeight;

  /// How far down a released drag must sit to dismiss instead of settling back.
  final double dismissDrag;

  /// Downward fling speed past which a release dismisses regardless of travel.
  final double flingVelocity;

  /// The screen fraction a sheet may grow to before its content scrolls.
  final double maxHeightFraction;

  /// The same for a sheet that has more to say than a message: a pitch, its
  /// perks, and a pinned action. Stops short of the top safe area, so the
  /// grabber never sits under the Dynamic Island.
  final double tallMaxHeightFraction;
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
