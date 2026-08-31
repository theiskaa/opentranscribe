import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/entry/components/append_ink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const style = TextStyle(fontSize: 16, height: 1.5, fontFamily: 'Ahem');

  test('the painted ink covers the paragraph the words will occupy', () async {
    final painted = await paintAppendedInk(
      base: 'aaaa',
      addition: 'bbbb bbbb bbbb bbbb bbbb bbbb',
      width: 200,
      style: style,
      textScaler: TextScaler.noScaling,
      pixelRatio: 2,
      color: const Color(0xFF000000),
    );

    expect(painted.size.width, lessThanOrEqualTo(200));
    expect(painted.size.height, greaterThan(24));
    expect(painted.top, 0);
    expect(painted.image.width, (painted.size.width * 2).ceil());
    expect(painted.image.height, (painted.size.height * 2).ceil());
    painted.image.dispose();
  });

  test("only the region from the addition's first line down is painted", () async {
    final painted = await paintAppendedInk(
      base: 'aaaa aaaa aaaa aaaa aaaa',
      addition: 'bb',
      width: 200,
      style: style,
      textScaler: TextScaler.noScaling,
      pixelRatio: 1,
      color: const Color(0xFF000000),
    );

    expect(painted.top, 48);
    expect(painted.size.height, 24);
    painted.image.dispose();
  });

  test('only the addition leaves ink; the base is painted transparent', () async {
    final painted = await paintAppendedInk(
      base: 'aaaa',
      addition: 'bb',
      width: 200,
      style: style,
      textScaler: TextScaler.noScaling,
      pixelRatio: 1,
      color: const Color(0xFF000000),
    );
    final data = (await painted.image.toByteData())!;
    int alpha(int x, int y) => data.getUint8((y * painted.image.width + x) * 4 + 3);

    expect(alpha(8, 12), 0);
    expect(alpha(16 * 5 + 8, 12), greaterThan(0));
    painted.image.dispose();
  });
}
