import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/core/theming/screen_colors.dart';

/// The single source of visual truth: pure data (colors and doubles), no
/// context, no logic. A future user theme is `fromBase` with 13 colors; any
/// component group is overridable whole (a group override restates that group,
/// nothing else). Widgets read this via `context.theme` only.
@immutable
final class AppTheme {
  const AppTheme({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceBorder,
    required this.text,
    required this.textSecondary,
    required this.hairline,
    required this.accent,
    required this.accentPressed,
    required this.onAccent,
    required this.record,
    required this.danger,
    required this.onDanger,
    required this.shadow,
    required this.barrier,
    required this.screens,
    required this.topBar,
    required this.button,
    required this.pageIndicator,
    required this.calendar,
    required this.entryList,
    required this.recorder,
    required this.player,
    required this.settings,
    required this.onboarding,
    required this.navigation,
    this.motion = const AppMotion(),
  });

  /// Derives every component group from the base palette. This is the contract
  /// that keeps user themes small: 13 colors in, a coherent theme out, with any
  /// group overridable when a theme wants to diverge.
  factory AppTheme.fromBase({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceBorder,
    required Color text,
    required Color textSecondary,
    required Color hairline,
    required Color accent,
    required Color accentPressed,
    required Color onAccent,
    required Color record,
    required Color danger,
    required Color shadow,
    required Color barrier,
    Color onDanger = const Color(0xFFFFFFFF),
    ScreenColors? screens,
    TopBarTheme? topBar,
    ButtonTheme? button,
    PageIndicatorTheme? pageIndicator,
    CalendarTheme? calendar,
    EntryListTheme? entryList,
    RecorderTheme? recorder,
    PlayerTheme? player,
    SettingsTheme? settings,
    OnboardingTheme? onboarding,
    NavigationTheme? navigation,
    AppMotion motion = const AppMotion(),
  }) {
    return AppTheme(
      brightness: brightness,
      background: background,
      surface: surface,
      surfaceBorder: surfaceBorder,
      text: text,
      textSecondary: textSecondary,
      hairline: hairline,
      accent: accent,
      accentPressed: accentPressed,
      onAccent: onAccent,
      record: record,
      danger: danger,
      onDanger: onDanger,
      shadow: shadow,
      barrier: barrier,
      screens:
          screens ??
          ScreenColors(
            onboarding: background,
            home: background,
            recorder: background,
            entryDetail: background,
            settings: background,
          ),
      topBar: topBar ?? TopBarTheme(background: background, titleColor: text, iconColor: text),
      button:
          button ??
          ButtonTheme(
            background: accent,
            pressed: accentPressed,
            foreground: onAccent,
            sheen: const Color(0xFFFFFFFF).withValues(alpha: 0.14),
            // Contact, not elevation: enough to seat an ink fill on the page,
            // far too little to read as a card floating over it. A primary
            // button earns its weight from the fill itself.
            shadow: BoxShadow(
              color: shadow.withValues(alpha: 0.16),
              blurRadius: 14,
              spreadRadius: -6,
              offset: const Offset(0, 4),
            ),
            secondaryBackground: surface,
            secondaryPressed: hairline,
            secondaryForeground: text,
            secondaryBorder: surfaceBorder,
          ),
      pageIndicator:
          pageIndicator ??
          PageIndicatorTheme(active: accent, inactive: accent.withValues(alpha: 0.25)),
      calendar:
          calendar ??
          CalendarTheme(
            weekdayLabelColor: textSecondary,
            dayNumberColor: text,
            disabledDayColor: textSecondary.withValues(alpha: 0.6),
            // Today is marked by a dot, not a hue: the strip stays ink-only.
            todayColor: text,
            tileBorder: text.withValues(alpha: 0.14),
            tileBorderDisabled: text.withValues(alpha: 0.07),
            // A ring, not a block: the cursor slides across the tiles and
            // today's tint has to survive underneath it.
            cursorFill: text.withValues(alpha: 0.08),
            cursorBorder: text.withValues(alpha: 0.55),
          ),
      entryList:
          entryList ??
          EntryListTheme(
            titleColor: text,
            excerptColor: text,
            metaColor: textSecondary,
            splitterColor: textSecondary,
            // The rail is quieter than a hairline border was: it runs the whole
            // height of a day, so it has to stay under the text, not frame it.
            railColor: hairline,
            nodeColor: textSecondary,
          ),
      recorder:
          recorder ??
          RecorderTheme(
            timerColor: text,
            waveformBar: accent,
            waveformBarIdle: accent.withValues(alpha: 0.25),
            waveformBaseline: text.withValues(alpha: 0.10),
            liveTextColor: textSecondary,
            liveTextFadedColor: textSecondary.withValues(alpha: 0.45),
          ),
      player:
          player ??
          PlayerTheme(
            progress: accent,
            // Present, not decorative: the unplayed wave has to read as the
            // same recording as the played half, just not reached yet.
            waveRemaining: text.withValues(alpha: 0.16),
            segmentColor: text,
            activeSegmentHighlight: text.withValues(alpha: 0.12),
          ),
      settings:
          settings ??
          SettingsTheme(
            cardBackground: surface,
            cardBorder: surfaceBorder,
            iconTileBackground: text.withValues(alpha: 0.06),
            iconColor: textSecondary,
            dangerIconTint: danger.withValues(alpha: 0.12),
            chevronColor: textSecondary.withValues(alpha: 0.7),
            dividerColor: hairline,
            sectionLabelColor: textSecondary,
            // The one hue in an ink app: a switch's on-state is green because
            // that is what a switch's on-state IS on iOS, and the native glass
            // toggle draws itself this green anyway - the drawn fallback matches
            // it rather than inventing an ink switch nobody would read as "on".
            toggleActive: brightness == Brightness.dark
                ? const Color(0xFF30D158)
                : const Color(0xFF34C759),
          ),
      onboarding:
          onboarding ??
          OnboardingTheme(
            logoTileBackground: surface,
            logoTileBorder: surfaceBorder,
            titleColor: text,
            bodyColor: textSecondary,
            handleColor: text,
          ),
      navigation:
          navigation ??
          NavigationTheme(
            // Black at low alpha; a touch stronger in the dark so the dim and
            // the edge shadow still read against near-black screens.
            scrim: shadow.withValues(alpha: brightness == Brightness.dark ? 0.14 : 0.08),
            edgeShadow: shadow.withValues(alpha: brightness == Brightness.dark ? 0.13 : 0.07),
          ),
      motion: motion,
    );
  }

  /// Whether this theme is a light or dark appearance, for system chrome
  /// (status bar, keyboard) and for slotting into a mode picker.
  final Brightness brightness;

  final Color background;
  final Color surface;
  final Color surfaceBorder;
  final Color text;
  final Color textSecondary;
  final Color hairline;

  /// Ink, not a hue: filled buttons and selection fills.
  final Color accent;
  final Color accentPressed;
  final Color onAccent;
  final Color record;
  final Color danger;

  /// Foreground on a [danger] fill (a destructive button or the delete badge).
  /// White in both themes, since [danger] is a saturated red either way.
  final Color onDanger;

  /// Always applied at low alpha by the consuming token or use site.
  final Color shadow;
  final Color barrier;

  final ScreenColors screens;
  final TopBarTheme topBar;
  final ButtonTheme button;
  final PageIndicatorTheme pageIndicator;
  final CalendarTheme calendar;
  final EntryListTheme entryList;
  final RecorderTheme recorder;
  final PlayerTheme player;
  final SettingsTheme settings;
  final OnboardingTheme onboarding;
  final NavigationTheme navigation;
  final AppMotion motion;

  /// Proper white, neutral grays, ink black.
  static final defaultLight = AppTheme.fromBase(
    brightness: Brightness.light,
    background: const Color(0xFFFFFFFF),
    surface: const Color(0xFFF6F6F6),
    surfaceBorder: const Color(0xFFE6E6E6),
    text: const Color(0xFF111111),
    textSecondary: const Color(0xFF8A8A8E),
    hairline: const Color(0xFFE6E6E6),
    accent: const Color(0xFF111111),
    accentPressed: const Color(0xFF000000),
    onAccent: const Color(0xFFFFFFFF),
    record: const Color(0xFFD64B3F),
    danger: const Color(0xFFFF3B30),
    shadow: const Color(0xFF000000),
    barrier: const Color(0x73000000),
  );

  /// Proper neutral dark, same relationships inverted.
  static final defaultDark = AppTheme.fromBase(
    brightness: Brightness.dark,
    background: const Color(0xFF111111),
    surface: const Color(0xFF1C1C1E),
    surfaceBorder: const Color(0xFF2A2A2C),
    text: const Color(0xFFF5F5F5),
    textSecondary: const Color(0xFF98989E),
    hairline: const Color(0xFF2A2A2C),
    accent: const Color(0xFFF5F5F5),
    accentPressed: const Color(0xFFFFFFFF),
    onAccent: const Color(0xFF111111),
    record: const Color(0xFFE4685C),
    danger: const Color(0xFFFF453A),
    shadow: const Color(0xFF000000),
    barrier: const Color(0x73000000),
  );
}
