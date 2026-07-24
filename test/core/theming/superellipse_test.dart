import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 100, 60);

  test('path stays inside the rect', () {
    final bounds = Superellipse.pathFor(rect, 20, 0.6).getBounds();
    expect(bounds.left, greaterThanOrEqualTo(rect.left - 0.01));
    expect(bounds.top, greaterThanOrEqualTo(rect.top - 0.01));
    expect(bounds.right, lessThanOrEqualTo(rect.right + 0.01));
    expect(bounds.bottom, lessThanOrEqualTo(rect.bottom + 0.01));
  });

  test('zero radius is the plain rect', () {
    expect(Superellipse.pathFor(rect, 0, 0.6).getBounds(), rect);
  });

  test('degenerate inputs do not throw', () {
    // Radius beyond half the short side clamps; empty rects short-circuit.
    expect(Superellipse.pathFor(rect, 500, 0.6).getBounds().height, lessThanOrEqualTo(60));
    expect(Superellipse.pathFor(Rect.zero, 20, 0.6), isA<Path>());
    expect(Superellipse.pathFor(const Rect.fromLTWH(0, 0, 10, 0), 5, 0.6), isA<Path>());
  });

  test('shape border contract: outer path, scale, dimensions', () {
    const shape = Superellipse(radius: 20, side: BorderSide(width: 2));
    expect(shape.getOuterPath(rect).getBounds(), rect);
    expect(shape.dimensions, const EdgeInsets.all(2));
    final scaled = shape.scale(0.5) as Superellipse;
    expect(scaled.radius, 10);
  });

  test('decoration builds a superellipse shape', () {
    final decoration = SuperellipseDecoration(
      borderRadius: 20,
      color: const Color(0xFF000000),
      border: const BorderSide(color: Color(0xFFFFFFFF)),
    );
    expect(decoration.shape, isA<Superellipse>());
  });
}
