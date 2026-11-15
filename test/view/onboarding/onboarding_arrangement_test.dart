import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_arrangement.dart';

import '../../support/fake_display_channels.dart';

PaneLayout layoutFor(Map<String, Object?> wire, {double body = 17, Size? window}) {
  final signal = DisplayWire.decode(wire);
  return paneLayoutFor(
    PaneInputs(
      size: window ?? signal.size,
      padding: signal.padding,
      signal: signal,
      bodySize: body,
      closedContentWidth: AppDuo.closedContentWidth,
    ),
  );
}

void main() {
  for (final (name, wire) in [
    ('regular iPhone', DisplayWire.iphone),
    ('cover', DisplayWire.cover),
    ('tall inner display', DisplayWire.flatTall),
  ]) {
    test('the $name keeps the stacked pages and full width footer', () {
      final regions = onboardingRegions(layoutFor(wire), 120);
      expect(regions.pages.width, regions.safe.width);
      expect(regions.controls.width, regions.safe.width);
      expect(regions.pages.bottom, regions.controls.top);
      expect(regions.words, regions.scene);
      expect(regions.controls.bottom, regions.safe.bottom);
    });
  }

  test('wide onboarding puts the scene beside words and Next below the leading half', () {
    final regions = onboardingRegions(layoutFor(DisplayWire.flatWide), 120);
    expect(regions.words.width, 382);
    expect(regions.scene.left, 383);
    expect(regions.controls.right, regions.words.right);
    expect(regions.scene.right, 867);
  });

  test('book onboarding keeps both content blocks and its footer off the fold', () {
    final layout = layoutFor(DisplayWire.bookWide);
    final regions = onboardingRegions(layout, 120);
    expect(regions.words.right, layout.fold!.rect.left);
    expect(regions.scene.left, layout.fold!.rect.right);
    expect(regions.controls.overlaps(layout.fold!.rect), isFalse);
  });

  test('laptop onboarding keeps the page above and Next and dashes below the fold', () {
    final layout = layoutFor(DisplayWire.laptop);
    final regions = onboardingRegions(layout, 120);
    expect(regions.pages.bottom, layout.fold!.rect.top);
    expect(regions.controls.top, greaterThanOrEqualTo(layout.fold!.rect.bottom));
    expect(regions.controls.bottom, regions.safe.bottom);
  });

  test('large text keeps onboarding in one column on the wide display', () {
    final regions = onboardingRegions(layoutFor(DisplayWire.flatWide, body: 40), 180);
    expect(regions.words, regions.scene);
    expect(regions.controls.width, regions.safe.width);
  });

  test('a stale display reading keeps onboarding in one column', () {
    final regions = onboardingRegions(
      layoutFor(DisplayWire.bookWide, window: const Size(466, 678)),
      120,
    );
    expect(regions.words, regions.scene);
    expect(regions.pages.bottom, regions.controls.top);
  });

  test('a left side column keeps words and Next together past the safe inset', () {
    final regions = onboardingRegions(
      layoutFor({
        ...DisplayWire.flatWide,
        'barSide': 'left',
        'insets': DisplayWire.insets(0, 84, 34, 0),
        'regions': [DisplayWire.region('occlusion', 0, 0, 84, 124)],
      }),
      120,
    );
    expect(regions.words.left, 84);
    expect(regions.words.width, 382);
    expect(regions.controls.left, regions.words.left);
    expect(regions.controls.right, regions.words.right);
    expect(regions.scene.left, 467);
    expect(regions.scene.right, 951);
  });

  test('an unsupported display retains the phone arrangement', () {
    final regions = onboardingRegions(layoutFor(DisplayWire.unsupported), 120);
    expect(regions.words, regions.scene);
    expect(regions.pages.bottom, regions.controls.top);
    expect(regions.controls.width, regions.safe.width);
  });

  test('a compact Split View half keeps one column with its own safe edges', () {
    final regions = onboardingRegions(
      layoutFor(
        DisplayWire.splitHalf(
          width: 475,
          height: 669,
          insets: DisplayWire.insets(0, 0, 34, 84),
          barSide: 'right',
          division: DisplayWire.region('division', 456, 0, 19, 669),
        ),
      ),
      120,
    );
    expect(regions.words, regions.scene);
    expect(regions.safe.width, 391);
    expect(regions.controls.width, regions.safe.width);
  });
}
