import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';

import '../../support/fake_display_channels.dart';

PaneLayout layout(Map<String, Object?> wire, {double width = AppDuo.closedContentWidth}) {
  final signal = DisplayWire.decode(wire);
  return paneLayoutFor(
    PaneInputs(
      size: signal.size,
      padding: signal.padding,
      signal: signal,
      bodySize: AppType.body.fontSize!,
      closedContentWidth: width,
    ),
  );
}

bool glides(
  PaneLayout from,
  PaneLayout to, {
  bool supported = true,
  bool previouslySettled = true,
  bool settled = true,
  bool cover = false,
  bool reduceMotion = false,
}) => paneGlides(
  previous: from,
  next: to,
  supported: supported,
  previouslySettled: previouslySettled,
  settled: settled,
  cover: cover,
  reduceMotion: reduceMotion,
);

void main() {
  final flat = layout(DisplayWire.flatWide);
  final wider = layout(DisplayWire.flatWide, width: 390);

  test('remembered cover widths do not disturb compact navigation while settled', () {
    expect(glides(flat, wider), isTrue);
    final middle = interpolatePanes(flat, wider, 0.5);
    expect(middle.leading.rect.right, 280);
    expect(middle.detail.rect.left, 281);
    expect(middle.mode, PaneMode.split);
    expect(middle.modal, wider.modal);
  });

  test('mode flips and recorder arrangement flips swap without travel', () {
    final cover = layout(DisplayWire.cover);
    final tall = layout(DisplayWire.flatTall);
    expect(glides(flat, cover), isFalse);
    expect(glides(cover, flat), isFalse);
    expect(glides(tall, flat), isFalse);
    expect(glides(flat, tall), isFalse);
  });

  test('a stale frame and its first settled replacement never glide', () {
    expect(glides(flat, wider, settled: false), isFalse);
    expect(glides(flat, wider, previouslySettled: false), isFalse);
  });

  test('Reduce Motion and the cover always swap frames without travel', () {
    expect(glides(flat, wider, reduceMotion: true), isFalse);
    expect(glides(flat, wider, cover: true), isFalse);
    expect(glides(flat, wider, supported: false), isFalse);
  });

  test('a regular supported iPhone never gains pane motion', () {
    final phone = layout(DisplayWire.iphone);
    expect(glides(phone, phone), isFalse);
    expect(glides(flat, phone), isFalse);
  });

  test('a settled cover never gains pane motion', () {
    final cover = layout(DisplayWire.cover);
    expect(glides(cover, cover, cover: true), isFalse);
    expect(glides(flat, cover, cover: true), isFalse);
  });

  test(
    'folding glides off the fold the content already sits on, while turning between folds swaps',
    () {
      final book = layout(DisplayWire.bookWide);
      final laptop = layout(DisplayWire.laptop);
      expect(glides(flat, book), isTrue);
      expect(glides(flat, book, settled: false), isFalse);
      expect(glides(flat, book, reduceMotion: true), isFalse);
      expect(glides(book, flat), isTrue);
      expect(glides(book, laptop), isFalse);
      expect(glides(laptop, book), isFalse);
    },
  );

  test('unfolding glides continuously from the currently visible panes', () {
    final book = layout(DisplayWire.bookWide);
    expect(glides(book, flat), isTrue);
    final first = interpolatePanes(book, flat, 0);
    final middle = interpolatePanes(book, flat, 0.5);
    final last = interpolatePanes(book, flat, 1);
    expect(first, book);
    expect(last, flat);
    expect(middle.leading.rect, Rect.lerp(book.leading.rect, flat.leading.rect, 0.5));
    expect(middle.detail.rect, Rect.lerp(book.detail.rect, flat.detail.rect, 0.5));
    expect(middle.fold, isNull);
    expect(glides(book, flat, reduceMotion: true), isFalse);
    expect(glides(book, flat, settled: false), isFalse);
  });

  test('the centered recorder unfolds from its visible panel instead of the pane union', () {
    final book = PaneReflow.fromLayout(layout(DisplayWire.bookWide));
    final open = PaneReflow.fromLayout(flat);
    var previous = book.recorderRegion;
    for (var frame = 0; frame <= 120; frame++) {
      final current = interpolateReflow(book, open, frame / 120);
      expect(
        current.recorderRegion,
        Rect.lerp(book.recorderRegion, open.recorderRegion, frame / 120),
      );
      expect(current.recorderRegion.width, greaterThanOrEqualTo(previous.width));
      expect(
        (current.recorderRegion.center - open.recorderRegion.center).distance,
        lessThanOrEqualTo((previous.center - open.recorderRegion.center).distance),
      );
      previous = current.recorderRegion;
    }
    expect(interpolateReflow(book, open, 0).recorderRegion, book.recorderRegion);
    expect(interpolateReflow(book, open, 1).recorderRegion, open.recorderRegion);
  });

  test('an interrupted reflow keeps the displayed recorder rectangle as its next origin', () {
    final book = PaneReflow.fromLayout(layout(DisplayWire.bookWide));
    final open = PaneReflow.fromLayout(flat);
    final displayed = interpolateReflow(book, open, 0.37);
    final replacement = PaneReflow.fromLayout(wider);
    final retargeted = interpolateReflow(displayed, replacement, 0);
    expect(retargeted.recorderRegion, displayed.recorderRegion);
    expect(retargeted.layout, displayed.layout);
    expect(displayed.recorderRegion, isNot(centeredRecorderRegion(displayed.layout)));
    expect(interpolateReflow(displayed, replacement, 1).recorderRegion, replacement.recorderRegion);
  });

  test('sheet regions carry the real safe insets through reflow and interruption', () {
    final folded = DisplayWire.decode(DisplayWire.laptop);
    final open = DisplayWire.decode(DisplayWire.flatTall);
    final from = PaneReflow.fromLayout(
      layout(DisplayWire.laptop),
      window: folded.size,
      padding: folded.padding,
    );
    final to = PaneReflow.fromLayout(
      layout(DisplayWire.flatTall),
      window: open.size,
      padding: open.padding,
    );
    for (final source in <PaneTouch?>[null, ...PaneTouch.values]) {
      final start = from.sheetFor(source);
      final end = to.sheetFor(source);
      expect(start.padding, EdgeInsets.only(bottom: folded.padding.bottom));
      expect(end.padding, open.padding);
      final displayed = interpolateReflow(from, to, 0.5);
      expect(displayed.sheetFor(source), (
        region: Rect.lerp(start.region, end.region, 0.5)!,
        padding: EdgeInsets.lerp(start.padding, end.padding, 0.5)!,
      ));
      expect(interpolateReflow(displayed, to, 0).sheetFor(source), displayed.sheetFor(source));
    }
  });

  test('an unchanged target cannot keep moving after motion or geometry becomes unsafe', () {
    expect(glides(flat, flat), isTrue);
    expect(glides(flat, flat, reduceMotion: true), isFalse);
    expect(glides(flat, flat, settled: false), isFalse);
    expect(glides(flat, flat, supported: false), isFalse);
    expect(glides(flat, flat, cover: true), isFalse);
  });

  test('interpolation preserves the endpoints and the recorder blocks', () {
    expect(interpolatePanes(flat, wider, 0), same(flat));
    expect(interpolatePanes(flat, wider, 1), same(wider));
    expect(interpolatePanes(flat, wider, 0).leading, flat.leading);
    expect(interpolatePanes(flat, wider, 0).detail, flat.detail);
    expect(interpolatePanes(flat, wider, 1), wider);
    expect(interpolatePanes(flat, wider, 0.5).recorder, flat.recorder);
    expect(interpolatePanes(flat, wider, 0.5).leading.padding, const EdgeInsets.only(bottom: 34));
  });
}
