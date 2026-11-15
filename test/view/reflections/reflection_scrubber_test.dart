import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_scrubber.dart';

import '../../support/fake_display_channels.dart';

void main() {
  for (final (name, wire, center) in [
    ('regular iPhone', DisplayWire.iphone, 201.0),
    ('cover', DisplayWire.cover, 191.0),
    ('flat wide detail', DisplayWire.flatWide, 242.0),
    ('book detail', DisplayWire.bookWide, 185.5),
    ('flat tall', DisplayWire.flatTall, 334.5),
    ('laptop', DisplayWire.laptop, 334.5),
  ]) {
    test('the scrubber centers within the safe content on the $name', () {
      final signal = DisplayWire.decode(wire);
      final layout = paneLayoutFor(
        PaneInputs(
          size: signal.size,
          padding: signal.padding,
          signal: signal,
          bodySize: 17,
          closedContentWidth: AppDuo.closedContentWidth,
        ),
      );
      expect(reflectionScrubberCenter(layout.detail), center);
    });
  }
}
