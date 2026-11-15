import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';

import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/view/widgets/page_bar_scope.dart';

import '../../support/fake_display_channels.dart';

PaneLayout layoutOf(Map<String, Object?> wire, {bool largeText = false}) {
  final signal = DisplayWire.decode(wire);
  return paneLayoutFor(
    PaneInputs(
      size: signal.size,
      padding: signal.padding,
      signal: signal,
      bodySize: largeText ? AppType.largeTextBody : AppType.body.fontSize!,
      closedContentWidth: AppDuo.closedContentWidth,
    ),
  );
}

PageBarPlacement placement(
  PaneLayout layout,
  PagePaneRole role, {
  bool settled = true,
  PageBarPlacement previous = PageBarPlacement.horizontal,
}) => pageBarPlacement(
  layout: layout,
  role: role,
  edge: layout.sideColumn?.side ?? BarSide.none,
  settled: settled,
  previous: previous,
);

void main() {
  test('a detail route leaves the journal bar horizontal and its native controls visible', () {
    final layout = layoutOf(DisplayWire.flatWide);
    final role = pagePaneRole(mode: layout.mode, touch: PaneTouch.journal);
    expect(role, PagePaneRole.sidebar);
    expect(placement(layout, role), PageBarPlacement.horizontal);
    expect(pageBarCovered(role: role, fullScreenCovered: false), isFalse);
    expect(pageBarCovered(role: role, fullScreenCovered: true), isTrue);
    expect(pageBarCovered(role: PagePaneRole.detail, fullScreenCovered: false), isNull);
    expect(pageBarCovered(role: PagePaneRole.single, fullScreenCovered: false), isNull);
  });

  test('regular iPhones keep every page bar horizontal', () {
    for (final wire in [DisplayWire.iphone, DisplayWire.unsupported]) {
      for (final role in PagePaneRole.values) {
        expect(placement(layoutOf(wire), role), PageBarPlacement.horizontal);
      }
    }
  });

  test('the cover moves the current single page bar into the status column', () {
    expect(placement(layoutOf(DisplayWire.cover), PagePaneRole.single), PageBarPlacement.vertical);
  });

  test('a wide split moves only the detail bar into the status column', () {
    for (final wire in [DisplayWire.flatWide, DisplayWire.bookWide]) {
      final layout = layoutOf(wire);
      expect(layout.mode, PaneMode.split);
      expect(placement(layout, PagePaneRole.detail), PageBarPlacement.vertical);
      expect(placement(layout, PagePaneRole.sidebar), PageBarPlacement.horizontal);
    }
  });

  test('tall and laptop inner displays keep horizontal bars', () {
    for (final wire in [DisplayWire.flatTall, DisplayWire.laptop]) {
      for (final role in PagePaneRole.values) {
        expect(placement(layoutOf(wire), role), PageBarPlacement.horizontal);
      }
    }
  });

  test('a stale signal keeps the previous placement until the regions settle', () {
    for (final previous in PageBarPlacement.values) {
      for (final role in PagePaneRole.values) {
        for (final wire in [DisplayWire.iphone, DisplayWire.cover, DisplayWire.flatWide]) {
          expect(placement(layoutOf(wire), role, settled: false, previous: previous), previous);
        }
      }
    }
  });

  test('a settled tall reading releases a previous vertical placement', () {
    expect(
      placement(
        layoutOf(DisplayWire.flatTall),
        PagePaneRole.single,
        previous: PageBarPlacement.vertical,
      ),
      PageBarPlacement.horizontal,
    );
  });

  test('a physical left bar does not follow the reading direction', () {
    final wire = {
      ...DisplayWire.flatWide,
      'barSide': 'left',
      'insets': DisplayWire.insets(0, 84, 34, 0),
    };
    expect(placement(layoutOf(wire), PagePaneRole.detail), PageBarPlacement.vertical);
    expect(placement(layoutOf(wire), PagePaneRole.sidebar), PageBarPlacement.horizontal);
  });

  test('large text keeps a single wide inner page bar vertical', () {
    final layout = layoutOf(DisplayWire.flatWide, largeText: true);
    expect(layout.mode, PaneMode.single);
    expect(placement(layout, PagePaneRole.single), PageBarPlacement.vertical);
  });
}
