import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';

import '../../support/fake_display_channels.dart';

PaneReflow reflowFor(Map<String, Object?> wire) {
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
  return PaneReflow.fromLayout(layout, window: signal.size, padding: signal.padding);
}

Rect frameFor(PaneReflow reflow, PaneTouch? source) {
  final sheet = reflow.sheetFor(source);
  return duoSheetFrame(region: sheet.region, padding: sheet.padding);
}

void main() {
  test('a wide detail sheet is capped and centered in the safe width of its pane', () {
    final reflow = reflowFor(DisplayWire.flatWide);
    final detail = reflow.layout.detail;
    final frame = frameFor(reflow, PaneTouch.detail);
    expect(frame.width, AppDuo.paneSheetWidth);
    expect(frame.center.dx, detail.padding.deflateRect(detail.rect).center.dx);
    expect(frame.top, detail.rect.top);
    expect(frame.bottom, detail.rect.bottom);
  });

  test('every source gets a bottom-attached sheet clear of the fold in book and laptop poses', () {
    for (final wire in [DisplayWire.bookWide, DisplayWire.laptop]) {
      final reflow = reflowFor(wire);
      for (final source in <PaneTouch?>[null, ...PaneTouch.values]) {
        final region = reflow.sheetFor(source).region;
        final frame = frameFor(reflow, source);
        expect(frame.width, greaterThan(0));
        expect(frame.top, region.top);
        expect(frame.bottom, region.bottom);
        expect(frame.overlaps(reflow.layout.fold!.rect), isFalse);
      }
    }
  });

  test('the cover and iPhone sheet regions fill the window and their safe widths fit the cap', () {
    for (final wire in [DisplayWire.cover, DisplayWire.iphone]) {
      final signal = DisplayWire.decode(wire);
      final reflow = reflowFor(wire);
      final window = Offset.zero & signal.size;
      final safe = signal.padding.deflateRect(window);
      for (final source in <PaneTouch?>[null, ...PaneTouch.values]) {
        expect(reflow.sheetFor(source).region, window);
        expect(frameFor(reflow, source), Rect.fromLTRB(safe.left, 0, safe.right, window.bottom));
      }
    }
  });

  test('an inner sheet clears a status column on either side of its region', () {
    final reflow = reflowFor(DisplayWire.bookWide);
    final details = reflow.sheetFor(PaneTouch.detail);
    final frame = frameFor(reflow, PaneTouch.detail);
    expect(frame.overlaps(reflow.layout.sideColumn!.rect), isFalse);
    expect(frame.right, details.region.right - details.padding.right);
    final leftInset = duoSheetFrame(
      region: details.region,
      padding: EdgeInsets.only(left: details.padding.right),
    );
    expect(leftInset.left, details.region.left + details.padding.right);
  });

  test('a sheet never extends outside its source when side insets consume the region', () {
    const region = Rect.fromLTWH(20, 10, 30, 40);
    final frame = duoSheetFrame(region: region, padding: const EdgeInsets.only(left: 84));
    expect(frame, Rect.fromLTRB(region.right, region.top, region.right, region.bottom));
  });

  test('a reflowing sheet travels within the union of its endpoint frames', () {
    for (final (folded, flat) in [
      (DisplayWire.bookWide, DisplayWire.flatWide),
      (DisplayWire.laptop, DisplayWire.flatTall),
    ]) {
      final from = reflowFor(folded);
      final to = reflowFor(flat);
      for (final source in <PaneTouch?>[null, ...PaneTouch.values]) {
        final start = frameFor(from, source);
        final end = frameFor(to, source);
        final union = start.expandToInclude(end);
        var previous = start;
        for (var step = 0; step <= 120; step++) {
          final frame = frameFor(interpolateReflow(from, to, step / 120), source);
          expect(frame.intersect(union.inflate(0.0001)), frame);
          expect(frame.width, lessThanOrEqualTo(AppDuo.paneSheetWidth + 0.0001));
          expect((frame.center - previous.center).distance, lessThan(5));
          previous = frame;
        }
        expect(previous, end);
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
