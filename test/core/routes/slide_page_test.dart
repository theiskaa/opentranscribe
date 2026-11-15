import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/routes/slide_page.dart';

import '../../support/display_fixtures.dart';

void main() {
  test('without a leading inset the back swipe claims the standard grab area', () {
    expect(backGestureEdgeWidth(iphonePadding, TextDirection.ltr), 20);
    expect(backGestureEdgeWidth(iphonePadding, TextDirection.rtl), 20);
  });

  test('a trailing status column leaves the left to right grab area alone', () {
    expect(backGestureEdgeWidth(coverPadding, TextDirection.ltr), 20);
  });

  test('right to left the back swipe leads from the right and widens into a column there', () {
    expect(backGestureEdgeWidth(coverPadding, TextDirection.rtl), coverPadding.right);
  });

  test('left to right the back swipe widens into a left column', () {
    expect(
      backGestureEdgeWidth(EdgeInsets.only(left: coverPadding.right), TextDirection.ltr),
      coverPadding.right,
    );
  });
}
