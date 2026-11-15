import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/app_dropdown.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';

import '../../support/display_fixtures.dart';

void main() {
  const row = 56.0;
  const side = AppSizes.barControl;

  test('the fallback anchor on the cover display sits left of the status column', () {
    final rect = barControlFallbackRect(window: coverSize, padding: coverPadding, rowHeight: row);
    expect(rect.right, coverSize.width - coverPadding.right - AppTopBar.edgeInset);
    expect(rect.top, (row - side) / 2);
  });

  test('the fallback anchor on a portrait iPhone sits at the screen edge inset', () {
    final rect = barControlFallbackRect(window: iphoneSize, padding: iphonePadding, rowHeight: row);
    expect(rect.right, iphoneSize.width - AppTopBar.edgeInset);
    expect(rect.top, 62 + (row - side) / 2);
    expect(rect.size, const Size(side, side));
  });
}
