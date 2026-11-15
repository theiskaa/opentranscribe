import 'package:flutter/widgets.dart';

/// The left and right safe-area insets alone: the side a vertical status bar
/// or a sensor column reserves. Zero on every portrait iPhone.
EdgeInsets horizontalInsets(EdgeInsets padding) =>
    EdgeInsets.only(left: padding.left, right: padding.right);

/// The width left between the horizontal insets of a window [width] wide,
/// never negative.
double safeWidth(double width, EdgeInsets padding) =>
    (width - padding.left - padding.right).clamp(0.0, width);

/// The safe inset on the trailing side for [direction]: what an
/// end-anchored control adds to its own inset.
double endInset(EdgeInsets padding, TextDirection direction) => switch (direction) {
  TextDirection.ltr => padding.right,
  TextDirection.rtl => padding.left,
};

/// [media] as seen from inside the horizontal safe band: side padding and
/// view padding read zero and the width is [safeWidth]. Top and bottom
/// padding, view insets (the keyboard), text scaling, display features and
/// every other field pass through unchanged, so applying it twice is a no-op.
MediaQueryData safeSidesData(MediaQueryData media) => media.copyWith(
  size: Size(safeWidth(media.size.width, media.padding), media.size.height),
  padding: media.padding.copyWith(left: 0, right: 0),
  viewPadding: media.viewPadding.copyWith(left: 0, right: 0),
);

/// The one rule for the side insets: what lies below sees [safeSidesData], so
/// nothing there applies an inset twice or measures past the band.
///
/// A scroll view takes [SafeSides.scroll] and keeps the window as its viewport,
/// so a drag under a side column still scrolls; the insets go in its padding.
class SafeSides extends StatelessWidget {
  /// Pads [child] into the band: for content that does not scroll.
  const SafeSides({required Widget this.child, super.key}) : builder = null;

  /// Builds a scroll view under the narrowed MediaQuery, handing [builder] the
  /// side insets read above it to add to the scroll view's own padding.
  const SafeSides.scroll({
    required Widget Function(BuildContext context, EdgeInsets sides) this.builder,
    super.key,
  }) : child = null;

  final Widget? child;
  final Widget Function(BuildContext context, EdgeInsets sides)? builder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sides = horizontalInsets(media.padding);
    final scroll = builder;
    if (scroll != null) {
      return MediaQuery(
        data: safeSidesData(media),
        child: Builder(builder: (context) => scroll(context, sides)),
      );
    }
    return Padding(
      padding: sides,
      child: MediaQuery(data: safeSidesData(media), child: child!),
    );
  }
}
