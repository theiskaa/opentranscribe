import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/github_mark.dart';

// The GitHub mark is drawn from a parsed SVG path (arcs converted to cubics).
// The parser is the only non-trivial logic, so it is a pure function tested by
// the bounds of the shapes it produces - no widget is pumped.
void main() {
  test('parseSvgPath builds a rectangle from move, line, and close', () {
    final bounds = parseSvgPath('M0 0 L10 0 L10 10 L0 10 Z').getBounds();
    expect(bounds.left, closeTo(0, 0.001));
    expect(bounds.top, closeTo(0, 0.001));
    expect(bounds.right, closeTo(10, 0.001));
    expect(bounds.bottom, closeTo(10, 0.001));
  });

  test('parseSvgPath converts an arc to a curve spanning its semicircle', () {
    // Radius-8 arc between (0,8) and (16,8): a 16-wide, 8-tall bulge whichever
    // way it sweeps.
    final bounds = parseSvgPath('M0 8A8 8 0 0 1 16 8').getBounds();
    expect(bounds.width, closeTo(16, 0.2));
    expect(bounds.height, closeTo(8, 0.2));
  });

  test('parseSvgPath handles relative arcs with concatenated flags (a full circle)', () {
    // Four quarter arcs around centre (8,8), radius 8, flags written as "01"
    // exactly as the Octocat path writes them.
    final bounds = parseSvgPath(
      'M8 0a8 8 0 018 8 8 8 0 01-8 8 8 8 0 01-8-8 8 8 0 018-8z',
    ).getBounds();
    expect(bounds.left, closeTo(0, 0.3));
    expect(bounds.top, closeTo(0, 0.3));
    expect(bounds.width, closeTo(16, 0.3));
    expect(bounds.height, closeTo(16, 0.3));
  });

  // Malformed input must fail loudly. The loop used to spin forever on a char
  // it could not consume - on the UI thread, a hang, which is worse than a
  // crash.
  test('parseSvgPath throws on leading garbage instead of hanging', () {
    expect(() => parseSvgPath('x 1 1'), throwsFormatException);
  });

  test('parseSvgPath throws on trailing garbage after a close', () {
    expect(() => parseSvgPath('M0 0L1 1z 5'), throwsFormatException);
  });

  test('parseSvgPath throws on an unsupported smooth-curve command', () {
    // S is valid SVG this parser does not speak; pasting an octicon that uses
    // it must fail at parse, not misdraw or hang.
    expect(() => parseSvgPath('M0 0S1 1 2 2'), throwsFormatException);
  });

  test('parseSvgPath throws on truncated input', () {
    expect(() => parseSvgPath('M0 0L1'), throwsFormatException);
    expect(() => parseSvgPath('M0 0a1 1 0'), throwsFormatException);
  });

  test('parseSvgPath treats a zero-length arc as a no-op, not NaN geometry', () {
    final bounds = parseSvgPath('M5 5a2 2 0 0 1 0 0L6 6').getBounds();
    expect(bounds.left.isFinite, isTrue);
    expect(bounds.top.isFinite, isTrue);
    expect(bounds.right, closeTo(6, 0.001));
    expect(bounds.bottom, closeTo(6, 0.001));
  });
}
