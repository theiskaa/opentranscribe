import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/routes/app_router.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';

import '../../support/display_fixtures.dart';
import '../../support/fake_display_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the provisional entry and its explicit selection share one detail identity', () {
    final tracker = PaneTouchTracker();
    final provisional = tracker.entryDetailKey('a');
    expect(tracker.entryDetailKey('a'), same(provisional));
    expect(tracker.takeProvisionalKey('b'), isNull);
    expect(tracker.takeProvisionalKey('a'), same(provisional));
    expect(tracker.takeProvisionalKey('a'), isNull);
    expect(tracker.entryDetailKey('a'), isNot(same(provisional)));
    tracker.dispose();
  });

  test('the provisional journal highlight equals an explicit selection of the same entry', () {
    final provisional = journalPaneSelection(
      mode: PaneMode.split,
      selection: null,
      hasDetail: false,
      newestEntryId: 'a',
    );
    final explicit = paneSelection(Uri.parse('/entry/a'));
    expect(provisional, explicit);
    expect(
      journalPaneSelection(
        mode: PaneMode.split,
        selection: explicit,
        hasDetail: true,
        newestEntryId: 'b',
      ),
      provisional,
    );
  });

  test('the provisional highlight stays out of phone layouts and other detail pages', () {
    for (final mode in PaneMode.values) {
      for (final hasDetail in [false, true]) {
        expect(
          journalPaneSelection(
            mode: mode,
            selection: null,
            hasDetail: hasDetail,
            newestEntryId: 'a',
          ),
          mode == PaneMode.split && !hasDetail ? paneSelection(Uri.parse('/entry/a')) : null,
        );
      }
    }
    expect(
      journalPaneSelection(
        mode: PaneMode.split,
        selection: null,
        hasDetail: false,
        newestEntryId: null,
      ),
      isNull,
    );
  });

  test('only the journal entry selection is a detail root without back', () {
    final router = AppRouter(onboardingDone: () => true).config;
    final signal = DisplayWire.decode(DisplayWire.flatWide);
    final layout = paneLayoutFor(
      PaneInputs(
        size: signal.size,
        padding: signal.padding,
        signal: signal,
        bodySize: 17,
        closedContentWidth: AppDuo.closedContentWidth,
      ),
    );
    final tracker = PaneTouchTracker();
    final home = router.configuration.findMatch(Uri.parse(Routes.home));
    final entry = router.configuration.findMatch(Uri.parse('/entry/a'));
    for (final path in [
      '/entry/a',
      Routes.reflections,
      '${Routes.reflections}?week=2026-11-09',
      '${Routes.reflections}?period=weekly&week=2026-11-09',
      Routes.settingsModels,
      Routes.settingsAppearance,
      Routes.settingsCache,
      Routes.settingsBackup,
      Routes.settingsNotifications,
    ]) {
      final page = router.configuration.findMatch(Uri.parse(path));
      for (final base in [null, home, entry]) {
        final matches = base == null
            ? page
            : base.push(
                ImperativeRouteMatch(
                  pageKey: ValueKey('push-$path'),
                  matches: page,
                  completer: Completer<Object?>(),
                ),
              );
        tracker.update(
          layout: layout,
          media: MediaQueryData(size: signal.size, padding: signal.padding),
          settled: true,
          supported: true,
          cover: false,
          matches: matches,
          selectionOnTop: true,
        );
        final selection = base == entry
            ? entry.matches.last.pageKey
            : base == null && path == '/entry/a'
            ? page.matches.last.pageKey
            : null;
        expect(tracker.journalSelectionKey, selection, reason: '$path over ${base?.uri}');
        final topKey = matches.matches.last.pageKey;
        for (final mode in [null, PaneMode.single, PaneMode.split]) {
          expect(
            panePageShowsBack(
              mode: mode,
              journalSelection: tracker.journalSelectionKey == topKey,
              canPop: matches.matches.length > 1,
            ),
            mode != PaneMode.split || base != null || path != '/entry/a',
            reason: '$path over ${base?.uri} in $mode',
          );
        }
        if (base != null) {
          expect(matches.remove(matches.matches.last), base);
        }
      }
    }
    tracker.dispose();
    router.dispose();
  });

  test('split sheets use the source pane with normal margins and the full pane height', () {
    for (final wire in [DisplayWire.flatWide, DisplayWire.bookWide]) {
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
      for (final source in PaneTouch.values) {
        final pane = source == PaneTouch.journal ? layout.leading : layout.detail;
        final rect = sheetPaneRect(layout: layout, source: source)!;
        expect(rect.left, pane.rect.left + pane.padding.left + AppSpacing.md);
        expect(rect.right, pane.rect.right - pane.padding.right - AppSpacing.md);
        expect(rect.top, pane.rect.top);
        expect(rect.bottom, pane.rect.bottom);
        expect(rect.overlaps(layout.fold?.rect ?? layout.divider!), isFalse);
        expect(rect.overlaps(layout.sideColumn!.rect), isFalse);
        final media = paneMediaData(
          MediaQueryData(size: signal.size, padding: signal.padding),
          Pane(rect: rect, padding: paneInsets(signal.padding, rect, signal.size)),
        );
        expect(media.size.height, pane.rect.height);
        expect(media.padding.bottom, signal.padding.bottom);
      }
    }
  });

  test('a wide detail sheet is not narrowed to the closed display width', () {
    final signal = DisplayWire.decode(DisplayWire.flatWide);
    final layout = paneLayoutFor(
      PaneInputs(
        size: signal.size,
        padding: signal.padding,
        signal: signal,
        bodySize: 17,
        closedContentWidth: AppDuo.closedContentWidth,
      ),
    );
    expect(
      sheetPaneRect(layout: layout, source: PaneTouch.detail)!.width,
      greaterThan(AppDuo.closedContentWidth),
    );
    expect(sheetPaneRect(layout: layout, source: null), isNull);
  });

  test('nested overlays keep the journal sheet source instead of the detail fallback', () {
    for (final wire in [DisplayWire.flatWide, DisplayWire.bookWide]) {
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
      final sheet = sheetPaneRect(layout: layout, source: PaneTouch.journal)!;
      final scope = PaneScope(
        pane: Pane(rect: sheet, padding: paneInsets(signal.padding, sheet, signal.size)),
        detailRoot: false,
        touch: PaneTouch.journal,
        child: const SizedBox(),
      );
      expect(sheetPaneRect(layout: layout, source: scope.touch), sheet);
      expect(modalPaneRect(layout: layout, source: scope.touch, window: signal.size), sheet);
      expect(modalPaneRect(layout: layout, source: null, window: signal.size), layout.modal);
      expect(sheet.overlaps(layout.detail.rect), isFalse);
    }
  });

  test('phone cover tall and unresolved sheets retain the existing modal geometry', () {
    for (final wire in [
      DisplayWire.iphone,
      DisplayWire.cover,
      DisplayWire.flatTall,
      DisplayWire.laptop,
      DisplayWire.unsupported,
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
      for (final source in [null, ...PaneTouch.values]) {
        expect(sheetPaneRect(layout: layout, source: source), isNull);
        expect(modalPaneRect(layout: layout, source: source, window: signal.size), layout.modal);
      }
    }
    expect(sheetPaneRect(layout: null, source: PaneTouch.journal), isNull);
  });

  test('settling notifies the tracker and scope even when geometry stays unchanged', () {
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
    PaneLayoutScope? before;
    for (final settled in [false, true]) {
      tracker.update(
        layout: layout,
        media: iphoneMedia,
        settled: settled,
        supported: true,
        cover: false,
        matches: RouteMatchList.empty,
        selectionOnTop: false,
      );
      final scope = PaneLayoutScope(tracker: tracker, child: const SizedBox());
      if (before == null) {
        before = scope;
      } else {
        expect(scope.settled, isTrue);
        expect(scope.updateShouldNotify(before), isTrue);
      }
    }
    expect(notifications, 2);
    tracker.dispose();
  });

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
