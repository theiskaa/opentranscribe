import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/display_signal.dart';

import '../../support/display_fixtures.dart';
import '../../support/fake_display_channels.dart';

void main() {
  test('a measured pose decodes to its size, insets, bar side and regions', () {
    final signal = DisplayWire.decode(DisplayWire.bookWide);

    expect(signal.supported, isTrue);
    expect(signal.size, wideSize);
    expect(signal.horizontal, SizeClass.regular);
    expect(signal.padding, widePadding);
    expect(signal.fullScreen, isTrue);
    expect(signal.barSide, BarSide.right);
    expect(signal.regions, hasLength(3));
    expect(signal.activeDivision?.rect, const Rect.fromLTWH(456, 0, 40, 669));
  });

  test('an inactive division is kept as the division, but is not the active one', () {
    final signal = DisplayWire.decode(DisplayWire.flatWide);

    expect(signal.activeDivision, isNull);
    expect(signal.division?.rect, const Rect.fromLTWH(456, 0, 40, 669));
  });

  test('the bare unsupported payload decodes to an empty unsupported signal', () {
    expect(DisplaySignal.fromWire({'supported': false}), DisplaySignal.unsupported);
  });

  test('an unsupported payload keeps its size and insets but no regions or bar', () {
    final signal = DisplaySignal.fromWire({
      ...DisplayWire.unsupported,
      'barSide': 'right',
      'regions': [DisplayWire.region('division', 0, 0, 10, 10)],
    })!;

    expect(signal.supported, isFalse);
    expect(signal.size, iphoneSize);
    expect(signal.padding, iphonePadding);
    expect(signal.barSide, BarSide.none);
    expect(signal.regions, isEmpty);
  });

  test('a payload that does not say whether it fills its screen reads as not filling it', () {
    final wire = Map.of(DisplayWire.cover)..remove('fullScreen');

    expect(DisplaySignal.fromWire(wire)!.fullScreen, isFalse);
  });

  test('names this build does not know read as absent, not as malformed', () {
    final signal = DisplaySignal.fromWire({
      ...DisplayWire.flatWide,
      'horizontal': 'roomy',
      'barSide': 'top',
      'regions': [
        DisplayWire.region('hinge', 0, 0, 10, 10),
        DisplayWire.region('occlusion', 867, 0, 84, 124),
      ],
    })!;

    expect(signal.horizontal, SizeClass.unspecified);
    expect(signal.barSide, BarSide.none);
    expect(signal.regions.single.kind, RegionKind.occlusion);
  });

  test('every malformed shape is rejected whole', () {
    final region = DisplayWire.region('division', 456, 0, 40, 669);
    final malformed = <Object?>[
      null,
      'cover',
      [DisplayWire.cover],
      {'width': 466.0},
      {'supported': 'yes'},
      {...DisplayWire.cover, 'width': null},
      {...DisplayWire.cover, 'height': -1.0},
      {...DisplayWire.cover, 'width': double.nan},
      {...DisplayWire.cover, 'insets': null},
      {...DisplayWire.cover, 'insets': DisplayWire.insetsOf(coverPadding)..remove('right')},
      {...DisplayWire.cover, 'horizontal': 1},
      {...DisplayWire.cover, 'fullScreen': 'yes'},
      {...DisplayWire.cover, 'barSide': true},
      {...DisplayWire.cover, 'regions': 'none'},
      {
        ...DisplayWire.cover,
        'regions': [
          {...region, 'active': null},
        ],
      },
      {
        ...DisplayWire.cover,
        'regions': [
          {...region, 'width': -40.0},
        ],
      },
      {
        ...DisplayWire.cover,
        'regions': [
          {...region, 'x': double.infinity},
        ],
      },
      {
        ...DisplayWire.cover,
        'regions': [region, 'division'],
      },
      {...DisplayWire.cover, 'reduceTransparency': 1},
    ];

    for (final wire in malformed) {
      expect(DisplaySignal.fromWire(wire), isNull, reason: '$wire');
    }
  });

  test('integer points decode the same as fractional ones', () {
    final signal = DisplaySignal.fromWire({
      ...DisplayWire.cover,
      'width': coverSize.width.toInt(),
      'height': coverSize.height.toInt(),
      'insets': {
        'top': coverPadding.top.toInt(),
        'left': coverPadding.left.toInt(),
        'bottom': coverPadding.bottom.toInt(),
        'right': coverPadding.right.toInt(),
      },
    })!;

    expect(signal, DisplayWire.decode(DisplayWire.cover));
  });
}
