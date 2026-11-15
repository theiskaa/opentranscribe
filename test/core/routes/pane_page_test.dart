import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/routes/pane_page.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';

import '../../support/display_fixtures.dart';

void main() {
  test('selecting the provisional entry adds no fade while phone navigation keeps its slide', () {
    const motion = AppMotion();
    for (final provisional in [false, true]) {
      expect(
        panePageDuration(mode: PaneMode.single, fromProvisional: provisional, motion: motion),
        motion.routeSlide,
      );
      expect(
        panePageDuration(mode: PaneMode.split, fromProvisional: provisional, motion: motion),
        provisional ? Duration.zero : motion.crossfade,
      );
    }
  });

  test('inner detail navigation fades briefly and preserves a promoted entry without motion', () {
    const motion = AppMotion();
    for (final reduce in [false, true]) {
      expect(
        panePageDuration(
          mode: PaneMode.split,
          fromProvisional: false,
          motion: motion,
          inner: true,
          reduce: reduce,
        ),
        reduce ? motion.duoDetailReduced : motion.duoDetailFade,
      );
      expect(
        panePageDuration(
          mode: PaneMode.split,
          fromProvisional: true,
          motion: motion,
          inner: true,
          reduce: reduce,
        ),
        Duration.zero,
      );
      expect(
        panePageDuration(
          mode: PaneMode.single,
          fromProvisional: false,
          motion: motion,
          reduce: reduce,
        ),
        motion.routeSlide,
      );
    }
  });

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
