import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';

import '../../support/display_fixtures.dart';
import '../../support/fake_display_channels.dart';

void main() {
  test('unchanged route and geometry values do not notify tracker listeners', () {
    final tracker = PaneTouchTracker();
    final layout = paneLayoutFor(
      const PaneInputs(
        size: iphoneSize,
        padding: iphonePadding,
        signal: DisplaySignal.unsupported,
        bodySize: 17,
        closedContentWidth: 382,
      ),
    );
    var notifications = 0;
    tracker.addListener(() => notifications++);
    for (var i = 0; i < 2; i++) {
      tracker.update(
        layout: layout,
        media: iphoneMedia,
        settled: true,
        supported: false,
        cover: false,
        matches: RouteMatchList.empty,
        selectionOnTop: false,
      );
    }
    expect(notifications, 1);
    tracker.dispose();
  });

  test('equal geometry snapshots do not notify after a route selection changes', () {
    final tracker = PaneTouchTracker()
      ..layout = paneLayoutFor(
        const PaneInputs(
          size: iphoneSize,
          padding: iphonePadding,
          signal: DisplaySignal.unsupported,
          bodySize: 17,
          closedContentWidth: 382,
        ),
      )
      ..media = iphoneMedia;
    final before = PaneLayoutScope(tracker: tracker, child: const SizedBox());
    tracker.selection = Uri(path: '/entry/a');
    final after = PaneLayoutScope(tracker: tracker, child: const SizedBox());
    expect(after.updateShouldNotify(before), isFalse);
    tracker.dispose();
  });

  test('geometry snapshots notify when a safe inset changes', () {
    final tracker = PaneTouchTracker()
      ..layout = paneLayoutFor(
        const PaneInputs(
          size: iphoneSize,
          padding: iphonePadding,
          signal: DisplaySignal.unsupported,
          bodySize: 17,
          closedContentWidth: 382,
        ),
      )
      ..media = iphoneMedia;
    final before = PaneLayoutScope(tracker: tracker, child: const SizedBox());
    tracker.media = iphoneMedia.copyWith(padding: EdgeInsets.zero);
    final after = PaneLayoutScope(tracker: tracker, child: const SizedBox());
    expect(after.updateShouldNotify(before), isTrue);
    tracker.dispose();
  });

  test('selection changes notify only rows whose own selected value changes', () {
    final a = paneSelection(Uri(path: '/entry/a'))!;
    final b = paneSelection(Uri(path: '/entry/b'))!;
    final c = paneSelection(Uri(path: '/entry/c'))!;
    final before = PaneSelectionScope(selection: a, child: const SizedBox());
    final after = PaneSelectionScope(selection: b, child: const SizedBox());
    expect(after.updateShouldNotifyDependent(before, {a}), isTrue);
    expect(after.updateShouldNotifyDependent(before, {b}), isTrue);
    expect(after.updateShouldNotifyDependent(before, {c}), isFalse);
  });

  test('rows on a single pane do not receive selection notifications', () {
    const before = PaneSelectionScope(selection: null, child: SizedBox());
    const after = PaneSelectionScope(selection: null, child: SizedBox());
    expect(after.updateShouldNotify(before), isFalse);
  });

  test('selection ignores query order and unrelated entry parameters', () {
    expect(
      paneSelection(Uri.parse('/reflections?period=weekly&week=2026-11-09')),
      paneSelection(Uri.parse('/reflections?week=2026-11-09&period=weekly')),
    );
    expect(paneSelection(Uri.parse('/entry/a?other=value')), paneSelection(Uri(path: '/entry/a')));
  });

  test('a flat tall sheet is capped at closed width and stays centered', () {
    final rect = modalFrameRect(Offset.zero & tallSize, capWidth: 382);
    expect(rect.width, 382);
    expect(rect.center, tallSize.center(Offset.zero));
  });

  test('a book sheet remains wholly in the trailing half', () {
    const modal = Rect.fromLTRB(496, 0, 867, 669);
    expect(modalFrameRect(modal, capWidth: 382), modal);
  });

  test('a laptop sheet remains wholly below the fold', () {
    const modal = Rect.fromLTRB(0, 496, 669, 951);
    final rect = modalFrameRect(modal, capWidth: 382);
    expect(rect.top, modal.top);
    expect(rect.bottom, modal.bottom);
    expect(rect.width, 382);
    expect(rect.center, modal.center);
  });

  test('a regular iPhone sheet retains its full width', () {
    final rect = Offset.zero & iphoneSize;
    expect(modalFrameRect(rect), rect);
  });

  test('a supported regular iPhone keeps all 402 points of sheet width', () {
    final signal = DisplayWire.decode(DisplayWire.iphone);
    final layout = paneLayoutFor(
      PaneInputs(
        size: iphoneSize,
        padding: iphonePadding,
        signal: signal,
        bodySize: 17,
        closedContentWidth: AppDuo.closedContentWidth,
      ),
    );
    expect(signal.supported, isTrue);
    expect(layout.mode, PaneMode.single);
    final rect = modalFrameRect(
      layout.modal,
      capWidth: modalWidthCap(layout, AppDuo.closedContentWidth),
    );
    expect(rect.width, 402);
    expect(rect, layout.modal);
  });

  test('only split layouts apply the sheet width cap', () {
    for (final (wire, expectedCap) in [
      (DisplayWire.flatWide, AppDuo.closedContentWidth),
      (DisplayWire.bookWide, AppDuo.closedContentWidth),
      (DisplayWire.flatTall, null),
      (DisplayWire.laptop, null),
      (DisplayWire.cover, null),
      (DisplayWire.unsupported, null),
    ]) {
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
      expect(modalWidthCap(layout, AppDuo.closedContentWidth), expectedCap);
      expect(modalWidthCap(layout, null), isNull);
    }
    expect(modalWidthCap(null, AppDuo.closedContentWidth), isNull);
  });

  test('a full window pane leaves a regular iPhone media query intact', () {
    final pane = Pane(rect: Offset.zero & iphoneSize, padding: iphonePadding);
    expect(paneMediaData(iphoneMedia, pane), iphoneMedia);
  });

  test('the journal receives only the safe edges it touches', () {
    const media = MediaQueryData(size: wideSize, padding: widePadding, viewPadding: widePadding);
    const pane = Pane(rect: Rect.fromLTWH(0, 0, 382, 669), padding: EdgeInsets.only(bottom: 34));
    final local = paneMediaData(media, pane);
    expect(local.size, pane.rect.size);
    expect(local.padding, pane.padding);
    expect(local.viewPadding, pane.padding);
  });

  test('the detail keeps its right column and a keyboard in its own coordinates', () {
    const media = MediaQueryData(
      size: wideSize,
      padding: widePadding,
      viewPadding: widePadding,
      viewInsets: EdgeInsets.only(bottom: 300),
    );
    const pane = Pane(rect: Rect.fromLTRB(496, 0, 951, 669), padding: widePadding);
    final local = paneMediaData(media, pane);
    expect(local.viewInsets.bottom, 300);
    expect(local.padding, widePadding);
  });

  test('an upper modal half sees only the part of a keyboard it overlaps', () {
    final insets = paneInsets(
      const EdgeInsets.only(bottom: 400),
      const Rect.fromLTWH(0, 0, 669, 456),
      tallSize,
    );
    expect(insets, EdgeInsets.zero);
  });
}
