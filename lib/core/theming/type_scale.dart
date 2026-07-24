import 'package:flutter/widgets.dart';

/// The type scale, color-free: the use site applies a theme color via
/// `copyWith(color:)`. Not themed, for the same reason `AppSpacing` is not.
/// System font throughout; `eyebrow` is tracked uppercase (uppercased at the
/// use site), `timer` and [digits] carry tabular figures so changing numbers
/// never shift their neighbors.
abstract final class AppType {
  static const display = TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -0.8);
  static const display2 = TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.6);
  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4);
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4);
  // Regular weights are explicit so a bolder DefaultTextStyle ancestor cannot
  // leak through style inheritance.
  static const body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    height: 1.45,
  );
  static const callout = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3);
  static const subhead = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.24);
  static const footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
  );
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
  static const eyebrow = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.3);
  // A bar title, not a hero: the recorder's readout sits in the top bar, so it
  // is sized to that row. Regular weight, because a light stroke gets spindly
  // this small.
  static const timer = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Any style rendering digits that change (durations, times, positions) goes
  /// through this, so the digits are fixed-width.
  static TextStyle digits(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
