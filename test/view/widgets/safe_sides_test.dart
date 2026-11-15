import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/safe_sides.dart';

import '../../support/display_fixtures.dart';

void main() {
  final column = coverPadding.right;
  final band = coverSize.width - column;

  test('the horizontal insets keep the side column and drop the status and home bands', () {
    expect(horizontalInsets(coverPadding), EdgeInsets.only(right: column));
    expect(horizontalInsets(iphonePadding), EdgeInsets.zero);
  });

  test('the cover display band stops at the status column', () {
    expect(safeWidth(coverSize.width, coverPadding), band);
  });

  test('a band behind a left column loses the same width', () {
    expect(safeWidth(coverSize.width, EdgeInsets.only(left: column)), band);
  });

  test('a portrait iPhone has no side insets, so its band is the whole window', () {
    expect(safeWidth(iphoneSize.width, iphonePadding), iphoneSize.width);
  });

  test('a band never goes negative when the insets outgrow the window', () {
    expect(safeWidth(100, const EdgeInsets.only(left: 60, right: 60)), 0);
  });

  test(
    'an end-anchored control adds the right inset left to right and the left one right to left',
    () {
      final padding = EdgeInsets.only(left: 10, right: column);
      expect(endInset(padding, TextDirection.ltr), column);
      expect(endInset(padding, TextDirection.rtl), 10);
      expect(endInset(iphonePadding, TextDirection.ltr), 0);
    },
  );

  test('inside the band the side padding and view padding read zero', () {
    final inside = safeSidesData(coverMedia);
    expect(inside.padding.left, 0);
    expect(inside.padding.right, 0);
    expect(inside.viewPadding.left, 0);
    expect(inside.viewPadding.right, 0);
  });

  test('inside the band the status and home indicator insets are kept', () {
    final inside = safeSidesData(iphoneMedia);
    expect(inside.padding.top, iphonePadding.top);
    expect(inside.padding.bottom, iphonePadding.bottom);
    expect(safeSidesData(coverMedia).viewPadding.bottom, coverPadding.bottom);
  });

  test('inside the band the keyboard, text scaling and display features pass through', () {
    final typing = coverMedia.copyWith(
      viewInsets: const EdgeInsets.only(bottom: 300),
      textScaler: const TextScaler.linear(1.3),
      displayFeatures: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(200, 0, 20, 678),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ],
    );
    final inside = safeSidesData(typing);
    expect(inside.viewInsets, typing.viewInsets);
    expect(inside.textScaler, typing.textScaler);
    expect(inside.displayFeatures, typing.displayFeatures);
  });

  test('inside the band the window is the band, as tall as before', () {
    expect(safeSidesData(coverMedia).size, Size(band, coverSize.height));
  });

  test('narrowing an already narrowed window changes nothing', () {
    final once = safeSidesData(coverMedia);
    expect(safeSidesData(once), once);
  });

  test('a portrait iPhone sees the same window inside the band', () {
    expect(safeSidesData(iphoneMedia), iphoneMedia);
  });
}
