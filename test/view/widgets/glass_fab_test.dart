import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';

import '../../support/display_fixtures.dart';

void main() {
  test('the disc floats its inset past a right status column', () {
    expect(GlassFab.rightFor(coverPadding), coverPadding.right + GlassFab.floatInset);
  });

  test('without a side inset the disc sits where it always has', () {
    expect(GlassFab.rightFor(iphonePadding), GlassFab.floatInset);
  });
}
