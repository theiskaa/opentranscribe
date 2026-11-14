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
}

/// Glyph sizes, tied to the text they sit beside. A spinner or ring takes the
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

  /// On a bar control.
  static const bar = 18.0;

  /// On a drawn disc button.
  static const disc = 20.0;

  /// On the floating action disc.
  static const fab = 26.0;
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
