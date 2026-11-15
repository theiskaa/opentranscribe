/// The whole percent a progress fraction reads as, 0 to 100: rounded, except
/// that only a finished fraction reads 100, so no bar or label claims done
/// early. The one rule every progress surface and the cubits that feed them
/// use, so 2/3 reads the same everywhere.
int percentOf(double? fraction) {
  final f = (fraction ?? 0).clamp(0.0, 1.0);
  if (f >= 1) return 100;
  final rounded = (f * 100).round();
  return rounded > 99 ? 99 : rounded;
}

/// The fill a bar shows for [fraction], snapped to the whole percent
/// [percentOf] reads, so a bar agrees with the label beside it.
double shownFraction(double? fraction) => percentOf(fraction) / 100;
