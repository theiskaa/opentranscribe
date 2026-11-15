/// Spacing scale, in logical pixels. Not themed: layout is identity, color is
/// preference. User themes recolor the app; they do not reshape it.
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

/// Fixed control sizes. Not themed, like spacing.
abstract final class AppSizes {
  /// The smallest box a tap may land in. Anything smaller pads its hit area
  /// out to this, visuals unchanged.
  static const minTarget = 44.0;

  /// A bar's icon control: the glass buttons and the menu button.
  static const barControl = minTarget;

  /// A chip, a compact button, a pill in a strip.
  static const chip = 36.0;

  /// A full control: a button, a recorder control, a pill standing alone.
  static const control = 52.0;

  /// The floating action disc.
  static const fab = 58.0;

  /// A selected card's check seat in its corner.
  static const badge = 20.0;
}

/// Stroke widths. A card's outline is a hairline; a selection rings it.
abstract final class AppStroke {
  /// A border side's own default width, so a card's outline leaves it unsaid.
  static const hairline = 1.0;
  static const ring = 2.0;
}

/// Glyph sizes, tied to the text they sit beside. A loader or ring takes the
/// size of the glyph whose seat it fills, so swapping them never shifts a row.
abstract final class AppIconSize {
  /// A badge's mark: the club's heart, a selected card's check.
  static const badge = 11.0;

  /// A row's trailing accessory: chevrons and checks beside 15pt labels.
  static const accessory = 14.0;

  /// Inside a settings icon tile.
  static const tile = 16.0;

  /// Beside body or headline text: menu rows, a card's leading glyph.
  static const body = 17.0;

  /// A language's flag inside a settings icon tile: an emoji carries less ink
  /// than a glyph of its size, so it runs larger.
  static const flag = 18.0;

  /// On a bar control.
  static const bar = 18.0;

  /// On a drawn disc button.
  static const disc = 20.0;

  /// On the floating action disc.
  static const fab = 26.0;
}

/// Loader sizes where no glyph seat sets one.
abstract final class AppLoaderSize {
  /// A button's or a disc's wait, where the label or mark it replaces sets no
  /// glyph size.
  static const control = 20.0;

  /// A wait standing in the page's flow where a paragraph will land.
  static const prose = 30.0;
}

/// Popup surfaces: the drawn menu and the dropdown grow from the same bar
/// control, so they share one width.
abstract final class AppPopup {
  static const width = 256.0;
}

/// Corner radii. `sm` for icon tiles, `chip` for chips, `card` for cards,
/// `panel` for hero cards, `pill` for buttons and pills.
abstract final class AppRadius {
  static const sm = 10.0;
  static const chip = 12.0;
  static const card = 20.0;
  static const panel = 28.0;
  static const pill = 62.0;

  /// The radius of a shape inset [inset] inside a corner of radius [outer], so
  /// the two curves stay concentric.
  static double inner(double outer, double inset) => (outer - inset).clamp(0, outer).toDouble();
}

/// Opacities a theme ink is laid at, as a wash behind itself.
abstract final class AppAlpha {
  /// A wash of an ink's own hue behind it, so a tile, pill or row reads as
  /// that ink without shouting it.
  static const wash = 0.14;
}

/// The two-display geometry. [closedContentWidth], [statusCluster] and
/// [foldBand] are fallbacks for what the live regions and insets do not
/// report, measured on the iPhone Duo simulator; the rest are chosen.
abstract final class AppDuo {
  static const onboardingTitleFraction = 0.22;

  /// The cover's content width (466 wide, less its 84 side column): what the
  /// journal pane keeps when the device opens.
  static const closedContentWidth = 382.0;

  /// The band a remembered cover width must fall in. A reading outside it is
  /// not this device's closed window, so it is pulled back inside.
  static const closedContentWidthMin = 320.0;
  static const closedContentWidthMax = 440.0;

  /// The status cluster's depth atop the side column, when no occlusion says;
  /// the cover's, the deeper of the two displays.
  static const statusCluster = 174.0;

  /// The fold's band when a tall window reports no division: the measured
  /// division is 40 across, wide and tall alike.
  static const foldBand = 40.0;

  /// How far the recorder's instrument stands off an active fold: the gap
  /// the app keeps between neighbouring blocks, as the fold is one more.
  static const recorderFoldOffset = AppSpacing.md;
}

abstract final class AppRecorderLayout {
  static const columnInset = AppSpacing.xxxl + AppSpacing.sm;
  static const upperSpace = 45.0;
  static const lowerSpace = 42.0;
}
