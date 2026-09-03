import 'dart:ui' show Color;

/// WCAG contrast between two opaque colours, 1 (the same) to 21 (black on
/// white). Translucent inputs are read as if opaque; composite first.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (light, dark) = la >= lb ? (la, lb) : (lb, la);
  return (light + 0.05) / (dark + 0.05);
}

/// [ink] at [alpha] over [background], with the alpha raised only as far as
/// the composite needs to reach [floor]:1 against that background. Returns
/// the translucent colour, never a flattened one, so a gradient built on it
/// keeps working. An ink that sits under the floor even opaque comes back
/// opaque; nothing here fails.
Color fadedAtLeast(Color ink, double alpha, {required Color background, double floor = 3}) {
  bool clears(double a) =>
      contrastRatio(Color.alphaBlend(ink.withValues(alpha: a), background), background) >= floor;
  if (clears(alpha)) return ink.withValues(alpha: alpha);
  if (!clears(1)) return ink.withValues(alpha: 1);
  // Bisect for the least clearing alpha. `high` only ever holds one that
  // clears, so the floor is met even where contrast is not monotone in alpha.
  var low = alpha;
  var high = 1.0;
  for (var i = 0; i < 24; i++) {
    final mid = (low + high) / 2;
    if (clears(mid)) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return ink.withValues(alpha: high);
}
