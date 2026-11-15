import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

final class DuoTheme {
  const DuoTheme({
    required this.surfaceGrouped,
    required this.surfaceElevated,
    required this.selectionFill,
    required this.pressedFill,
    required this.separator,
    required this.controlSurface,
    required this.player,
    required this.scrim,
  });

  factory DuoTheme.fromBase({
    required Brightness brightness,
    required Color background,
    required Color text,
    required Color textSecondary,
    required Color accent,
    required Color hairline,
    required Color barrier,
    required PlayerTheme player,
  }) {
    final dark = brightness == Brightness.dark;
    final neutral = accent.r == accent.g && accent.g == accent.b;
    final grouped = Color.alphaBlend(text.withValues(alpha: dark ? 0.05 : 0.025), background);
    return DuoTheme(
      surfaceGrouped: grouped,
      scrim: barrier.withValues(alpha: dark ? 0.48 : 0.32),
      surfaceElevated: Color.alphaBlend(text.withValues(alpha: dark ? 0.07 : 0.04), background),
      selectionFill: (neutral ? text : accent).withValues(
        alpha: neutral ? (dark ? 0.12 : 0.08) : (dark ? 0.22 : 0.14),
      ),
      pressedFill: accent.withValues(alpha: dark ? 0.12 : 0.08),
      separator: hairline.withValues(alpha: hairline.a * 0.6),
      controlSurface: background.withValues(alpha: 0.85),
      player: PlayerTheme(
        progress: accent,
        waveRemaining: textSecondary.withValues(alpha: 0.35),
        segmentColor: player.segmentColor,
        activeSegmentHighlight: player.activeSegmentHighlight,
        waveBarWidth: 2,
        waveGap: 2,
        waveHeight: 28,
      ),
    );
  }

  final Color surfaceGrouped;
  final Color surfaceElevated;
  final Color selectionFill;
  final Color pressedFill;
  final Color separator;
  final Color controlSurface;
  final PlayerTheme player;
  final Color scrim;

  static const sheetWidth = 540.0;
  static const sheetRadius = 28.0;
  static const sheetMinHeight = 320.0;
  static const sheetHeightFraction = 0.85;
  static const sheetToolbarHeight = 56.0;
  static const buttonHeight = 50.0;
  static const buttonRadius = 25.0;
  static const groupRadius = 14.0;
  static const groupRowHeight = 52.0;
  static const groupInset = 16.0;
  static const groupIcon = 30.0;
  static const groupIconRadius = 8.0;
  static const emptyGlyph = 56.0;
  static const emptyMeasure = 320.0;
  static const emptyAlignment = Alignment(0, -0.1);

  static final sheetTitle = AppType.title.copyWith(fontSize: 22, fontWeight: FontWeight.w600);
  static final sheetSubtitle = AppType.subhead.copyWith(fontSize: 15);
  static final primaryLabel = AppType.callout.copyWith(fontSize: 17, fontWeight: FontWeight.w600);
  static final emptyTitle = AppType.title.copyWith(fontSize: 20, fontWeight: FontWeight.w600);

  static final journalTitle = AppType.display2.copyWith(fontSize: 30, height: 1.15);
  static final detailTitle = AppType.display2.copyWith(letterSpacing: -0.3, height: 1.15);
  static final body = AppType.body.copyWith(fontSize: 19);
  static final rowTitle = AppType.body.copyWith(height: 1.25);
  static final metadata = AppType.footnote.copyWith(fontSize: 14, height: 1.3);
  static final section = AppType.footnote.copyWith(fontWeight: FontWeight.w600, height: 1.3);
}
