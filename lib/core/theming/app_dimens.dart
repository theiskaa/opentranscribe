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

/// Corner radii. `sm` for icon tiles, `chip` for chips, `card` for cards,
/// `panel` for hero cards, `pill` for buttons and pills.
abstract final class AppRadius {
  static const sm = 10.0;
  static const chip = 12.0;
  static const card = 20.0;
  static const panel = 28.0;
  static const pill = 62.0;
}
