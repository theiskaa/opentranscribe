import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import '../../support/fake_display_channels.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

import 'package:opentranscribe/view/widgets/app_sheet.dart';

void main() {
  test('only the inner display uses a form in every pose and window size', () {
    for (final wire in [
      DisplayWire.flatWide,
      DisplayWire.bookWide,
      DisplayWire.flatTall,
      DisplayWire.laptop,
    ]) {
      expect(formSheetFor(DisplayWire.decode(wire)), isTrue);
    }
    for (final wire in [DisplayWire.cover, DisplayWire.iphone, DisplayWire.unsupported]) {
      expect(formSheetFor(DisplayWire.decode(wire)), isFalse);
    }
    final half = DisplayWire.splitHalf(
      width: 400,
      height: 669,
      insets: DisplayWire.insets(0, 0, 34, 0),
      division: DisplayWire.region('division', 380, 0, 20, 669),
    );
    expect(formSheetFor(DisplayWire.decode(half)), isTrue);
  });

  test('forms fit both source panes and stay clear of the fold in every pose', () {
    for (final wire in [
      DisplayWire.flatWide,
      DisplayWire.bookWide,
      DisplayWire.flatTall,
      DisplayWire.laptop,
    ]) {
      final signal = DisplayWire.decode(wire);
      final layout = paneLayoutFor(
        PaneInputs(
          size: signal.size,
          padding: signal.padding,
          signal: signal,
          bodySize: AppType.body.fontSize!,
          closedContentWidth: AppDuo.closedContentWidth,
        ),
      );
      for (final source in PaneTouch.values) {
        final pane = modalPaneRect(layout: layout, source: source, window: signal.size);
        final bounds = formSheetBounds(
          size: pane.size,
          padding: paneInsets(signal.padding, pane, signal.size),
          keyboard: 0,
        );
        final card = bounds.shift(pane.topLeft);
        expect(card.width, lessThanOrEqualTo(AppDuo.formSheetWidth));
        expect(card.left, greaterThanOrEqualTo(pane.left));
        expect(card.right, lessThanOrEqualTo(pane.right));
        expect(card.top, greaterThanOrEqualTo(pane.top));
        expect(card.bottom, lessThanOrEqualTo(pane.bottom));
        if (layout.fold != null) expect(card.overlaps(layout.fold!.rect), isFalse);
      }
    }
  });

  test('forms cap their width and center within their available safe band', () {
    final bounds = formSheetBounds(
      size: const Size(800, 900),
      padding: const EdgeInsets.only(top: 40, bottom: 34),
      keyboard: 0,
    );
    expect(bounds.width, AppDuo.formSheetWidth);
    expect(bounds.center.dx, 400);
    expect(bounds.top, 40 + AppDuo.formSheetMargin);
    expect(bounds.bottom, 900 - 34 - AppDuo.formSheetMargin);
  });

  test('a keyboard reduces the available card height without adding space inside it', () {
    final bounds = formSheetBounds(
      size: const Size(400, 669),
      padding: const EdgeInsets.only(bottom: 34),
      keyboard: 300,
    );
    expect(bounds.width, 400 - 2 * AppDuo.formSheetMargin);
    expect(bounds.bottom, 369 - AppDuo.formSheetMargin);
    expect(bounds.height, greaterThan(0));
  });

  test('tiny available regions never produce negative card constraints', () {
    final bounds = formSheetBounds(
      size: const Size(30, 40),
      padding: EdgeInsets.zero,
      keyboard: 300,
    );
    expect(bounds.width, 0);
    expect(bounds.height, 0);
  });

  test('polished sheets keep the full window center despite an asymmetric status column', () {
    for (final padding in [const EdgeInsets.only(right: 84), const EdgeInsets.only(left: 84)]) {
      final bounds = formSheetBounds(
        size: const Size(951, 669),
        padding: padding,
        keyboard: 0,
        polished: true,
        centerOnWindow: true,
      );
      expect(bounds.center.dx, 951 / 2);
      expect(bounds.center.dy, closeTo(669 / 2, 0.0001));
      expect(bounds.width, DuoTheme.sheetWidth);
      expect(bounds.height, lessThanOrEqualTo(669 * DuoTheme.sheetHeightFraction + 0.0001));
    }
  });

  test('polished forms fit narrow source panes and tiny keyboard regions', () {
    for (final size in [const Size(455, 669), const Size(30, 40)]) {
      for (final keyboard in [0.0, 300.0, 1000.0]) {
        final bounds = formSheetBounds(
          size: size,
          padding: const EdgeInsets.only(right: 84),
          keyboard: keyboard,
          polished: true,
        );
        expect(bounds.width, inInclusiveRange(0, DuoTheme.sheetWidth));
        expect(
          bounds.height,
          inInclusiveRange(0, size.height * DuoTheme.sheetHeightFraction + 0.0001),
        );
      }
    }
  });

  test('a sheet rises with the keyboard as it opens', () {
    expect(heldKeyboardInset(inset: 0, held: 0, settled: false), 0);
    expect(heldKeyboardInset(inset: 180, held: 0, settled: false), 180);
    expect(heldKeyboardInset(inset: 336, held: 180, settled: false), 336);
  });

  test('a sheet holds its height through an input view tearing down', () {
    expect(heldKeyboardInset(inset: 0, held: 336, settled: false), 336);
    expect(heldKeyboardInset(inset: 291, held: 336, settled: false), 336);
  });

  test('a drop that outlasts the teardown takes the sheet down with it', () {
    expect(heldKeyboardInset(inset: 200, held: 336, settled: true), 200);
    expect(heldKeyboardInset(inset: 0, held: 336, settled: true), 0);
  });

  test('a settled height the keyboard grows past is given up at once', () {
    expect(heldKeyboardInset(inset: 336, held: 200, settled: false), 336);
    expect(heldKeyboardInset(inset: 336, held: 336, settled: true), 336);
  });

  test('a drop that keeps falling arms its settle', () {
    expect(settleArmed(inset: 0, held: 336, previous: 336), isTrue);
    expect(settleArmed(inset: 100, held: 336, previous: 291), isTrue);
  });

  test('an inset climbing back stands the settle down', () {
    expect(settleArmed(inset: 100, held: 336, previous: 0), isFalse);
    expect(settleArmed(inset: 291, held: 336, previous: 100), isFalse);
  });

  test('an inset at or above what the panel holds never arms a settle', () {
    expect(settleArmed(inset: 336, held: 336, previous: 336), isFalse);
    expect(settleArmed(inset: 400, held: 336, previous: 336), isFalse);
    expect(settleArmed(inset: 0, held: 0, previous: 0), isFalse);
  });

  test('re-reading the held inset every build never compounds', () {
    var held = 336.0;
    for (var i = 0; i < 5; i++) {
      held = heldKeyboardInset(inset: 291, held: held, settled: false);
    }
    expect(held, 336);
    expect(heldKeyboardInset(inset: 291, held: held, settled: true), 291);
  });

  test('a drag down on a list at its top pulls the whole sheet down', () {
    final split = splitSheetDrag(delta: 12, pixels: 0, minScrollExtent: 0, sheetOffset: 0);
    expect(split.sheet, 12);
    expect(split.content, 0);
  });

  test('a drag down on a scrolled list scrolls it to its top before the sheet moves', () {
    final split = splitSheetDrag(delta: 12, pixels: 5, minScrollExtent: 0, sheetOffset: 0);
    expect(split.content, 5);
    expect(split.sheet, 7);
  });

  test('a drag down deep in a list only scrolls the list', () {
    final split = splitSheetDrag(delta: 12, pixels: 300, minScrollExtent: 0, sheetOffset: 0);
    expect(split.content, 12);
    expect(split.sheet, 0);
  });

  test('a drag up on a pulled sheet lifts it back to rest before the list scrolls', () {
    final split = splitSheetDrag(delta: -12, pixels: 0, minScrollExtent: 0, sheetOffset: 5);
    expect(split.sheet, -5);
    expect(split.content, -7);
  });

  test('a drag up on a resting sheet only scrolls the list', () {
    final split = splitSheetDrag(delta: -12, pixels: 40, minScrollExtent: 0, sheetOffset: 0);
    expect(split.sheet, 0);
    expect(split.content, -12);
  });

  test('a list bounced past its top hands a drag down straight to the sheet', () {
    final split = splitSheetDrag(delta: 8, pixels: -20, minScrollExtent: 0, sheetOffset: 0);
    expect(split.sheet, 8);
    expect(split.content, 0);
  });
}
