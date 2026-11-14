import 'package:flutter/widgets.dart';

/// The type scale, color-free: the use site applies a theme color via
/// `copyWith(color:)`. Not themed, for the same reason `AppSpacing` is not.
/// System font throughout; `eyebrow` is tracked uppercase (uppercased at the
/// use site), `timer` and [digits] carry tabular figures so changing numbers
/// never shift their neighbors.
abstract final class AppType {
  // Even leading: a line taller than its font splits the extra above and
  // below, so text sits centred in its box like the icons beside it.
  static const _even = TextLeadingDistribution.even;

  static const display = TextStyle(
    leadingDistribution: _even,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
  );
  static const display2 = TextStyle(
    leadingDistribution: _even,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  );
  static const title = TextStyle(
    leadingDistribution: _even,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );
  static const headline = TextStyle(
    leadingDistribution: _even,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );
  // Regular weights are explicit so a bolder DefaultTextStyle ancestor cannot
  // leak through style inheritance.
  static const body = TextStyle(
    leadingDistribution: _even,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    height: 1.45,
  );
  static const callout = TextStyle(
    leadingDistribution: _even,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static const subhead = TextStyle(
    leadingDistribution: _even,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
  );
  // A subhead that wraps as a paragraph: the prose under a title.
  static const subheadParagraph = TextStyle(
    leadingDistribution: _even,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.5,
  );
  static const footnote = TextStyle(
    leadingDistribution: _even,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
  );
  // A footnote that wraps as a paragraph: a note under a control or a card.
  static const note = TextStyle(
    leadingDistribution: _even,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.4,
  );
  // The quiet line under a row's name: tighter than a note, so the pair
  // reads as one item.
  static const rowNote = TextStyle(
    leadingDistribution: _even,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.3,
  );
  static const caption = TextStyle(
    leadingDistribution: _even,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
  static const eyebrow = TextStyle(
    leadingDistribution: _even,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.3,
  );
  // A bar title, not a hero: the recorder's readout sits in the top bar, so it
  // is sized to that row. Regular weight, because a light stroke gets spindly
  // this small.
  static const timer = TextStyle(
    leadingDistribution: _even,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Any style rendering digits that change (durations, times, positions) goes
  /// through this, so the digits are fixed-width.
  static TextStyle digits(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// The line height [style] is really set at, as a multiple of its size:
  /// its own, else the one [ambient] lends it through style inheritance,
  /// else SF Pro's own ascent plus descent.
  static double lineHeightOf(TextStyle style, TextStyle ambient) =>
      style.height ?? ambient.height ?? _naturalLineHeight;

  static const _naturalLineHeight = 1.193;

  /// What Text sets [base] in: Bold Text thickens a paragraph's root style,
  /// so spans with a weight of their own, and text laid out by hand to match,
  /// must take it here.
  static TextStyle boldAware(TextStyle base, {required bool bold}) =>
      bold ? base.copyWith(fontWeight: FontWeight.bold) : base;
}
