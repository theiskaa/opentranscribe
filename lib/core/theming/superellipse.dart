import 'package:flutter/widgets.dart';

/// An iOS-style continuous-corner rectangle. A plain rounded rect changes
/// curvature abruptly where the arc meets the edge; pulling the cubic control
/// points toward the corner keeps the curvature continuous, which is what makes
/// native iOS cards read as "soft" rather than "stamped".
class Superellipse extends ShapeBorder {
  const Superellipse({
    required this.radius,
    this.smoothness = defaultSmoothness,
    this.side = BorderSide.none,
  });

  /// The house corner: every superellipse in the app that does not choose its
  /// own smoothness shares this one, so shapes drawn through [pathFor] match
  /// shapes drawn through the decoration.
  static const defaultSmoothness = 0.6;

  final double radius;

  /// 0 is a circular corner; each step toward 1 pulls the curve further out
  /// toward a square, continuous corner.
  final double smoothness;
  final BorderSide side;

  static Path pathFor(Rect rect, double radius, double smoothness) {
    final r = radius.clamp(0.0, rect.shortestSide / 2).toDouble();
    if (r <= 0 || rect.isEmpty) return Path()..addRect(rect);
    // 0.5523 is the circle-approximation constant for a cubic; nudging the
    // control strength beyond it produces the continuous corner.
    final control = (0.552284749831 + smoothness * 0.15).clamp(0.0, 1.0);
    final d = r * (1 - control);
    return Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..cubicTo(rect.right - d, rect.top, rect.right, rect.top + d, rect.right, rect.top + r)
      ..lineTo(rect.right, rect.bottom - r)
      ..cubicTo(
        rect.right,
        rect.bottom - d,
        rect.right - d,
        rect.bottom,
        rect.right - r,
        rect.bottom,
      )
      ..lineTo(rect.left + r, rect.bottom)
      ..cubicTo(rect.left + d, rect.bottom, rect.left, rect.bottom - d, rect.left, rect.bottom - r)
      ..lineTo(rect.left, rect.top + r)
      ..cubicTo(rect.left, rect.top + d, rect.left + d, rect.top, rect.left + r, rect.top)
      ..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => pathFor(rect, radius, smoothness);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      pathFor(rect.deflate(side.width), radius - side.width, smoothness);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    canvas.drawPath(pathFor(rect.deflate(side.width / 2), radius, smoothness), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) =>
      Superellipse(radius: radius * t, smoothness: smoothness, side: side.scale(t));

  // Value equality, like the framework shapes: equal decorations across
  // rebuilds compare equal and skip repaints.
  @override
  bool operator ==(Object other) =>
      other is Superellipse &&
      other.radius == radius &&
      other.smoothness == smoothness &&
      other.side == side;

  @override
  int get hashCode => Object.hash(radius, smoothness, side);
}

/// `BoxDecoration` stand-in for squircle surfaces: fill, gradient, shadows, and
/// an optional border, all clipped to the continuous corner. Not const: a const
/// initializer cannot build the shape from parameters.
class SuperellipseDecoration extends ShapeDecoration {
  SuperellipseDecoration({
    required double borderRadius,
    super.color,
    super.gradient,
    super.shadows,
    double smoothness = Superellipse.defaultSmoothness,
    BorderSide border = BorderSide.none,
  }) : super(
         shape: Superellipse(radius: borderRadius, smoothness: smoothness, side: border),
       );
}
