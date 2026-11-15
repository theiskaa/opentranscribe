import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/anchored_popup.dart';

import '../../support/display_fixtures.dart';

void main() {
  test('a regular phone popup retains its window corner as the scale origin', () {
    expect(
      popupOrigin(
        anchor: const Rect.fromLTWH(330, 70, 44, 44),
        modal: Offset.zero & iphoneSize,
        window: iphoneSize,
      ),
      Alignment.topRight,
    );
  });

  test('a laptop popup scales toward the lower modal half without crossing the fold', () {
    const modal = Rect.fromLTRB(0, 496, 669, 951);
    final origin = popupOrigin(
      anchor: const Rect.fromLTWH(590, 520, 44, 44),
      modal: modal,
      window: tallSize,
    );
    final pivot = origin.alongSize(tallSize);
    expect(pivot, modal.topRight);
    const popup = Rect.fromLTWH(400, 508, 256, 200);
    for (final scale in [0.88, 0.94, 1.0]) {
      final topLeft = pivot + (popup.topLeft - pivot) * scale;
      final bottomRight = pivot + (popup.bottomRight - pivot) * scale;
      expect(topLeft.dy, greaterThanOrEqualTo(modal.top));
      expect(bottomRight.dx, lessThanOrEqualTo(modal.right));
    }
  });

  const width = AppPopup.width;
  const side = AppSizes.barControl;
  final cover = coverSize.width;
  final iphone = iphoneSize.width;

  Rect controlEndingAt(double right) => Rect.fromLTWH(right - side, 70, side, side);

  test('a popup grown from a control in the safe band lines up with its right edge', () {
    final anchor = controlEndingAt(cover - coverPadding.right - AppSpacing.md);
    expect(
      popupLeft(anchor: anchor, width: width, windowWidth: cover, padding: coverPadding),
      anchor.right - width,
    );
  });

  test('a popup anchored under the status column is pulled back clear of it', () {
    final left = popupLeft(
      anchor: controlEndingAt(cover),
      width: width,
      windowWidth: cover,
      padding: coverPadding,
    );
    expect(left + width, cover - coverPadding.right - AppSpacing.md);
  });

  test('a popup keeps its margin past a left column', () {
    final left = popupLeft(
      anchor: controlEndingAt(100),
      width: width,
      windowWidth: cover,
      padding: EdgeInsets.only(left: coverPadding.right),
    );
    expect(left, coverPadding.right + AppSpacing.md);
  });

  test('with no side inset a popup sits where the screen margin alone put it', () {
    expect(
      popupLeft(
        anchor: controlEndingAt(iphone),
        width: width,
        windowWidth: iphone,
        padding: iphonePadding,
      ),
      iphone - width - AppSpacing.md,
    );
  });

  test('a window narrower than the popup pins it to the leading margin instead of throwing', () {
    expect(
      popupLeft(
        anchor: controlEndingAt(200),
        width: width,
        windowWidth: 200,
        padding: EdgeInsets.zero,
      ),
      AppSpacing.md,
    );
  });
}
