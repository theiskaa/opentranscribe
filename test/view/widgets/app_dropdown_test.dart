import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/app_dropdown.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';

import '../../support/display_fixtures.dart';

void main() {
  const row = 56.0;
  const side = AppSizes.barControl;

  test('a long dropdown anchored above the laptop fold fits below it', () {
    const bounds = Rect.fromLTRB(0, 496, 669, 917);
    final rect = dropdownRect(
      anchor: const Rect.fromLTWH(600, 100, 44, 44),
      bounds: bounds,
      naturalHeight: 2000,
    );
    expect(rect.top, bounds.top + AppSpacing.md);
    expect(rect.bottom, bounds.bottom - AppSpacing.md);
    expect(rect.height, bounds.height - AppSpacing.md * 2);
  });

  test('a long dropdown anchored below the modal fits above the anchor', () {
    const bounds = Rect.fromLTRB(496, 0, 867, 635);
    final rect = dropdownRect(
      anchor: const Rect.fromLTWH(800, 800, 44, 44),
      bounds: bounds,
      naturalHeight: 2000,
    );
    expect(rect.top, bounds.top + AppSpacing.md);
    expect(rect.bottom, bounds.bottom - AppSpacing.md);
  });

  test('a modal smaller than its margins yields a zero sized dropdown', () {
    final rect = dropdownRect(
      anchor: const Rect.fromLTWH(600, 100, 44, 44),
      bounds: const Rect.fromLTWH(0, 496, 10, 12),
      naturalHeight: 2000,
    );
    expect(rect, const Rect.fromLTWH(5, 502, 0, 0));
  });

  test('a short regular iPhone dropdown retains its anchor and width', () {
    final rect = dropdownRect(
      anchor: const Rect.fromLTWH(310, 68, 44, 44),
      bounds: const Rect.fromLTRB(0, 62, 393, 818),
      naturalHeight: 128,
    );
    expect(
      rect,
      const Rect.fromLTWH(354 - AppPopup.width, 112 + AppSpacing.sm, AppPopup.width, 128),
    );
  });

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
