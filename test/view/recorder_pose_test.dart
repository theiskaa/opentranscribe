import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/view/layouts/recorder/components/recorder_pose.dart';

import '../support/fake_display_channels.dart';

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

Map<RecorderBlock, Rect> blocksFor(
  PaneLayout layout, {
  double continuing = 0,
  double notice = 0,
  TextDirection direction = TextDirection.ltr,
}) => recorderBlockRects(
  layout,
  heights: {
    RecorderBlock.header:
        76 +
        (layout.recorder.arrangement == RecorderArrangement.column
            ? layout.leading.padding.top
            : 0),
    RecorderBlock.continuing: continuing,
    RecorderBlock.wave: 96,
    RecorderBlock.words: 98.6,
    RecorderBlock.notice: notice,
    RecorderBlock.controls: 52,
  },
  barHeight: 52,
  direction: direction,
  languageSize: const Size(44, 44),
);

void main() {
  for (final (name, wire) in [
    ('regular iPhone', DisplayWire.iphone),
    ('cover', DisplayWire.cover),
    ('unsupported iPhone', DisplayWire.unsupported),
  ]) {
    test('the $name permission state retains the whole window and its safe insets', () {
      final layout = layoutFor(wire);
      expect(recorderPermissionPane(layout), layout.leading);
    });
  }

  for (final (name, wire) in [('book', DisplayWire.bookWide), ('laptop', DisplayWire.laptop)]) {
    test('the $name permission state and its action stay clear of the fold', () {
      final layout = layoutFor(wire);
      final pane = recorderPermissionPane(layout);
      expect(pane.rect.overlaps(layout.fold!.rect), isFalse);
      expect(pane.rect, layout.recorder.first);
      expect(pane.padding, EdgeInsets.zero);
    });
  }

  test('overflowing phone content keeps controls below the words like the original column', () {
    final layout = layoutFor(DisplayWire.iphone);
    final blocks = recorderBlockRects(
      layout,
      heights: const {
        RecorderBlock.header: 138,
        RecorderBlock.continuing: 30,
        RecorderBlock.wave: 96,
        RecorderBlock.words: 700,
        RecorderBlock.notice: 100,
        RecorderBlock.controls: 52,
      },
      barHeight: 52,
      direction: TextDirection.ltr,
    );
    expect(blocks[RecorderBlock.continuing]!.top, 138);
    expect(blocks[RecorderBlock.words]!.bottom, 980);
    expect(blocks[RecorderBlock.notice]!.top, 980);
    expect(blocks[RecorderBlock.controls]!.top, 1080);
  });

  for (final (name, wire) in [
    ('regular iPhone', DisplayWire.iphone),
    ('unsupported iPhone', DisplayWire.unsupported),
    ('cover', DisplayWire.cover),
  ]) {
    test('the $name retains the clock, band, words and controls at their phone positions', () {
      final layout = layoutFor(wire);
      final blocks = blocksFor(layout, continuing: 30, notice: 40);
      final signal = DisplayWire.decode(wire);
      final header = 76 + signal.padding.top;
      final body = signal.size.height - header;
      final bottom = signal.padding.bottom + 20;
      final free = body - 30 - 96 - 16 - 98.6 - 40 - 52 - bottom;
      final waveTop = header + free * 45 / 87 + 30;
      final left = signal.padding.left + 40;
      final width = signal.size.width - signal.padding.horizontal - 80;
      expect(layout.recorder.arrangement, RecorderArrangement.column);
      expect(blocks[RecorderBlock.header], Rect.fromLTWH(0, 0, signal.size.width, header));
      expect(blocks[RecorderBlock.wave], Rect.fromLTWH(left, waveTop, width, 96));
      expect(blocks[RecorderBlock.words], Rect.fromLTWH(left, waveTop + 112, width, 98.6));
      expect(blocks[RecorderBlock.controls]!.bottom, signal.size.height - bottom);
      expect(blocks[RecorderBlock.notice]!.bottom, blocks[RecorderBlock.controls]!.top);
      expect(
        blocks[RecorderBlock.language]!.left,
        signal.size.width - signal.padding.right - 12 - 44,
      );
      expect(blocks[RecorderBlock.language]!.top, signal.padding.top + 4);
    });
  }

  test('flat wide centres the instrument and words on equal safe halves', () {
    final layout = layoutFor(DisplayWire.flatWide);
    final blocks = blocksFor(layout);
    expect(blocks[RecorderBlock.header]!.center.dx, 433.5 / 2);
    expect(blocks[RecorderBlock.wave]!.center.dx, 433.5 / 2);
    expect(blocks[RecorderBlock.controls]!.center.dx, 433.5 / 2);
    expect(blocks[RecorderBlock.words]!.center, const Offset(650.25, 317.5));
    expect(blocks[RecorderBlock.wave]!.width, 353.5);
    expect(blocks[RecorderBlock.language]!.top, 136);
    expect(blocks[RecorderBlock.language]!.center.dx, 909);
  });

  test('book blocks and every control stay on their own side of the reserved fold', () {
    final layout = layoutFor(DisplayWire.bookWide);
    final blocks = blocksFor(layout, continuing: 30, notice: 40);
    final fold = layout.fold!.rect;
    for (final (block, rect) in blocks.entries.map((e) => (e.key, e.value))) {
      expect(rect.overlaps(fold), isFalse, reason: block.name);
    }
    expect(blocks[RecorderBlock.header]!.right, fold.left - 12);
    expect(blocks[RecorderBlock.wave]!.right, fold.left - 12 - 40);
    expect(blocks[RecorderBlock.words]!.left, fold.right + 40);
    expect(blocks[RecorderBlock.controls]!.bottom, 615);
  });

  test('flat tall and laptop reserve identical blocks above and below the division', () {
    final flat = blocksFor(layoutFor(DisplayWire.flatTall), continuing: 30, notice: 40);
    final layout = layoutFor(DisplayWire.laptop);
    final laptop = blocksFor(layout, continuing: 30, notice: 40);
    expect(flat, laptop);
    final fold = layout.fold!.rect;
    for (final id in [RecorderBlock.header, RecorderBlock.words, RecorderBlock.language]) {
      expect(laptop[id]!.bottom, lessThanOrEqualTo(fold.top));
    }
    for (final id in [
      RecorderBlock.continuing,
      RecorderBlock.wave,
      RecorderBlock.notice,
      RecorderBlock.controls,
    ]) {
      expect(laptop[id]!.top, greaterThanOrEqualTo(fold.bottom));
      expect(laptop[id]!.bottom, lessThanOrEqualTo(917));
    }
    expect(laptop[RecorderBlock.header]!.top, 82);
    expect(laptop[RecorderBlock.controls]!.bottom, 897);
  });

  test('large text retains the phone column on the inner display', () {
    final layout = layoutFor(DisplayWire.flatWide, body: 40);
    final blocks = blocksFor(layout);
    expect(layout.recorder.arrangement, RecorderArrangement.column);
    expect(blocks[RecorderBlock.header]!.width, 951);
    expect(blocks[RecorderBlock.words]!.top, blocks[RecorderBlock.wave]!.bottom + 16);
  });

  test('a stale reading lays out the current cover size as a phone column', () {
    final layout = layoutFor(DisplayWire.bookWide, window: const Size(466, 678));
    final blocks = blocksFor(layout);
    expect(layout.recorder.arrangement, RecorderArrangement.column);
    expect(blocks[RecorderBlock.header]!.width, 466);
    expect(blocks[RecorderBlock.controls]!.bottom, 624);
    expect(blocks[RecorderBlock.words]!.top, blocks[RecorderBlock.wave]!.bottom + 16);
  });

  test('a compact Split View half keeps the phone arrangement inside its safe edges', () {
    final layout = layoutFor(
      DisplayWire.splitHalf(
        width: 475,
        height: 669,
        insets: DisplayWire.insets(0, 0, 34, 84),
        barSide: 'right',
        division: DisplayWire.region('division', 456, 0, 19, 669),
      ),
    );
    final blocks = blocksFor(layout);
    expect(layout.recorder.arrangement, RecorderArrangement.column);
    expect(blocks[RecorderBlock.wave]!.left, 40);
    expect(blocks[RecorderBlock.wave]!.right, 351);
    expect(blocks[RecorderBlock.language]!.right, 379);
  });

  test('a physical left status column takes the language menu in either reading direction', () {
    final layout = layoutFor({
      ...DisplayWire.flatWide,
      'barSide': 'left',
      'insets': DisplayWire.insets(0, 84, 34, 0),
      'regions': [DisplayWire.region('occlusion', 0, 0, 84, 124)],
    });
    final ltr = blocksFor(layout);
    final rtl = blocksFor(layout, direction: TextDirection.rtl);
    expect(ltr[RecorderBlock.language], rtl[RecorderBlock.language]);
    expect(ltr[RecorderBlock.language]!.center.dx, 42);
    expect(ltr[RecorderBlock.language]!.top, 136);
    expect(ltr[RecorderBlock.wave]!.left, 124);
  });

  test('a phone language button mirrors within the safe content band', () {
    final layout = layoutFor(DisplayWire.cover);
    final blocks = blocksFor(layout, direction: TextDirection.rtl);
    expect(blocks[RecorderBlock.language]!.left, 12);
  });
}
