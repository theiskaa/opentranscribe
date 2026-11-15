import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';

import '../../support/fake_display_channels.dart';

void main() {
  test('polish stays on the inner display in split or wide layouts', () {
    for (final (wire, expected) in [
      (DisplayWire.iphone, false),
      (DisplayWire.cover, false),
      (DisplayWire.flatWide, true),
      (DisplayWire.bookWide, true),
      (DisplayWire.flatTall, false),
      (DisplayWire.laptop, false),
      (DisplayWire.unsupported, false),
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
      expect(
        duoPolishEnabled(
          layout: layout,
          supported: signal.supported,
          cover: wire == DisplayWire.cover,
          regular:
              wire == DisplayWire.flatWide ||
              wire == DisplayWire.bookWide ||
              wire == DisplayWire.flatTall ||
              wire == DisplayWire.laptop,
          window: signal.size,
        ),
        expected,
      );
    }
  });

  test('an unsupported landscape phone and the cover never opt into polish', () {
    for (final supported in [false, true]) {
      for (final regular in [false, true]) {
        expect(
          duoPolishEnabled(
            layout: null,
            supported: supported,
            cover: true,
            regular: regular,
            window: const Size(951, 669),
          ),
          false,
        );
      }
    }
    expect(
      duoPolishEnabled(
        layout: null,
        supported: false,
        cover: false,
        regular: true,
        window: const Size(951, 669),
      ),
      false,
    );
  });

  test('detail content clears either side column and keeps a leading aligned readable measure', () {
    for (final safe in [const EdgeInsets.only(right: 84), const EdgeInsets.only(left: 84)]) {
      final insets = duoDetailInsets(
        width: 1200,
        safe: safe,
        fold: EdgeInsets.zero,
        top: 16,
        bottom: 34,
      );
      expect(1200 - insets.horizontal, AppDuo.detailMeasure);
      expect(insets.left, safe.left + AppDuo.detailMargin);
      expect(insets.right, greaterThanOrEqualTo(safe.right + AppDuo.detailMargin));
      expect(insets.top, 16);
      expect(insets.bottom, 34);
    }
  });

  test('a narrow detail uses the available width without centering or crossing its safe edges', () {
    final insets = duoDetailInsets(
      width: 455,
      safe: const EdgeInsets.only(right: 84, top: 20),
      fold: EdgeInsets.zero,
      top: 16,
      bottom: 334,
    );
    expect(insets, const EdgeInsets.fromLTRB(28, 36, 112, 334));
    expect(455 - insets.horizontal, 315);
  });

  test('only an active book division adds space on the two facing pane edges', () {
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
      expect(
        duoFoldInsets(layout, PaneTouch.journal),
        wire == DisplayWire.bookWide
            ? const EdgeInsets.only(right: AppDuo.foldMargin)
            : EdgeInsets.zero,
      );
      expect(
        duoFoldInsets(layout, PaneTouch.detail),
        wire == DisplayWire.bookWide
            ? const EdgeInsets.only(left: AppDuo.foldMargin)
            : EdgeInsets.zero,
      );
      expect(layout.divider == null, wire == DisplayWire.bookWide);
      final divider = duoDividerRect(layout, signal.padding);
      if (wire == DisplayWire.bookWide) {
        expect(divider, isNull);
      } else {
        expect(divider!.top, signal.padding.top);
        expect(divider.bottom, signal.size.height - signal.padding.bottom);
      }
    }
  });

  test('seven day cells fit narrow and wide panes without negative gaps', () {
    for (final width in [0.0, 100.0, 290.0, 342.0, 392.0, 600.0]) {
      final metrics = duoWeekMetrics(width);
      expect(metrics.cell, inInclusiveRange(0, AppDuo.dayWidth));
      expect(metrics.gap, greaterThanOrEqualTo(0));
      expect(metrics.cell * 7 + metrics.gap * 6, closeTo(width, 0.0001));
    }
    expect(duoWeekMetrics(344), (cell: 44.0, gap: 6.0));
  });

  test('the journal header grows with text and shares its first baseline with detail', () {
    for (final scale in [1.0, 1.2, 1.3, 1.6, 2.5]) {
      final metrics = duoHeaderMetrics(
        minimum: 72,
        titleLine: 30 * 1.15 * scale,
        titleSize: 30 * scale,
        subtitleLine: 13 * 1.3 * scale,
        detailLine: 28 * 1.15 * scale,
        detailSize: 28 * scale,
      );
      final block = 12 + 30 * 1.15 * scale + 2 + 13 * 1.3 * scale;
      expect(metrics.header, greaterThanOrEqualTo(block));
      final journalBaseline =
          (metrics.header - block) / 2 +
          12 +
          30 * 1.15 * scale / 2 +
          AppDuo.baselineEm * 30 * scale;
      final detailBaseline =
          metrics.detailTop + 28 * 1.15 * scale / 2 + AppDuo.baselineEm * 28 * scale;
      expect(detailBaseline, closeTo(journalBaseline, 0.001));
    }
  });

  test('week cells grow before accessibility text collapses the split', () {
    for (final scale in [1.0, 1.2, 1.3, 1.6]) {
      final letter = 12 * 1.45 * scale;
      final number = 17 * 1.45 * scale;
      final height = duoDayHeight(letterLine: letter, numberLine: number);
      expect(height, greaterThanOrEqualTo(AppDuo.dayHeight));
      expect(height, greaterThanOrEqualTo(letter + 2 + number + AppDuo.dayDotClearance));
    }
  });

  test('separators never touch a selected halo or the last row', () {
    for (final last in [false, true]) {
      for (final selected in [false, true]) {
        for (final nextSelected in [false, true]) {
          expect(
            duoRowSeparator(last: last, selected: selected, nextSelected: nextSelected),
            !last && !selected && !nextSelected,
          );
        }
      }
    }
  });
}
