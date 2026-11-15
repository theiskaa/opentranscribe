import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
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
      expect(insets.right, greaterThanOrEqualTo(safe.right + DuoTheme.detailTrailing));
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
    expect(insets, const EdgeInsets.fromLTRB(28, 36, 104, 334));
    expect(455 - insets.horizontal, 323);
  });

  test('measured book pane edges already clear the division including its margins', () {
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
      expect(duoFoldInsets(layout, PaneTouch.journal), EdgeInsets.zero);
      expect(duoFoldInsets(layout, PaneTouch.detail), EdgeInsets.zero);
      expect(layout.divider == null, wire == DisplayWire.bookWide);
      final divider = duoDividerRect(layout, signal.padding);
      if (wire == DisplayWire.bookWide) {
        expect(divider, isNull);
      } else {
        expect(divider!.top, signal.padding.top);
        expect(divider.bottom, signal.size.height);
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

  test('flat sheets center on the window while book sheets remain in their source pane', () {
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
        final region = duoSheetRegion(layout: layout, source: source, window: signal.size);
        if (layout.fold == null) {
          expect(region, Offset.zero & signal.size);
        } else {
          expect(region, source == PaneTouch.journal ? layout.leading.rect : layout.detail.rect);
          expect(region.overlaps(layout.fold!.rect), isFalse);
        }
      }
    }
  });

  test('day selection fits each cell in both writing directions and disappears off the week', () {
    final days = List.generate(7, (i) => DateTime(2026, 11, 9 + i));
    for (final width in [0.0, 100.0, 344.0, 600.0]) {
      for (final (i, day) in days.indexed) {
        final left = duoDaySelection(days: days, selected: day, width: width, height: 56)!;
        final right = duoDaySelection(
          days: days,
          selected: day,
          width: width,
          height: 56,
          direction: TextDirection.rtl,
        )!;
        expect(
          left.left,
          closeTo(i * (duoWeekMetrics(width).cell + duoWeekMetrics(width).gap), 0.001),
        );
        expect(left.right, lessThanOrEqualTo(width + 0.001));
        expect(right.left, closeTo(width - left.right, 0.001));
        expect(right.width, closeTo(left.width, 0.001));
      }
    }
    expect(
      duoDaySelection(days: days, selected: DateTime(2026, 11, 16), width: 344, height: 56),
      isNull,
    );
  });

  test('measured title baselines align independently of font ascent and text size', () {
    for (final scale in [1.0, 1.3, 1.6, 2.5]) {
      final metrics = duoHeaderMetrics(
        minimum: 72,
        titleLine: 35 * scale,
        titleSize: 30 * scale,
        subtitleLine: 17 * scale,
        detailLine: 33 * scale,
        detailSize: 28 * scale,
        titleBaseline: 27 * scale,
        detailBaseline: 24 * scale,
      );
      final block = AppSpacing.md + 35 * scale + AppSpacing.xxs + 17 * scale;
      final journal = (metrics.header - block) / 2 + AppSpacing.md + 27 * scale;
      expect(metrics.detailTop + 24 * scale, closeTo(journal, 0.001));
      expect(AppDuo.detailMetaGap, 6);
    }
  });

  test('the week spring reaches its destination without overshooting or reversing', () {
    const motion = AppMotion();
    var previous = 0.0;
    for (var i = 0; i <= 100; i++) {
      final value = motion.duoDayCurve.transform(i / 100);
      expect(value, inInclusiveRange(previous, 1));
      previous = value;
    }
    expect(previous, 1);
    expect(motion.duoDay.inMilliseconds, 220);
    expect(DuoTheme.groupRowHeight, greaterThanOrEqualTo(44));
  });
  test('detail motion fades to completion before the rise and stays still under Reduce Motion', () {
    const motion = AppMotion();
    final start = duoDetailVisual(progress: 0, incoming: true, reduce: false, motion: motion);
    expect(start, (opacity: 0.0, rise: motion.duoDetailRise));
    final faded = duoDetailVisual(
      progress: motion.duoDetailFade.inMicroseconds / motion.duoDetailEnter.inMicroseconds,
      incoming: true,
      reduce: false,
      motion: motion,
    );
    expect(faded.opacity, 1);
    expect(faded.rise, greaterThan(0));
    expect(duoDetailVisual(progress: 1, incoming: true, reduce: false, motion: motion), (
      opacity: 1.0,
      rise: 0.0,
    ));
    for (final progress in [0.0, 0.25, 0.5, 1.0]) {
      expect(
        duoDetailVisual(progress: progress, incoming: true, reduce: true, motion: motion).rise,
        0,
      );
      expect(
        duoDetailVisual(progress: progress, incoming: false, reduce: false, motion: motion).rise,
        0,
      );
    }
  });

  test('fold clearance follows measured overlap during a pane reflow', () {
    final signal = DisplayWire.decode(DisplayWire.bookWide);
    final base = paneLayoutFor(
      PaneInputs(
        size: signal.size,
        padding: signal.padding,
        signal: signal,
        bodySize: 17,
        closedContentWidth: AppDuo.closedContentWidth,
      ),
    );
    final fold = base.fold!;
    final layout = PaneLayout(
      mode: PaneMode.split,
      leading: Pane(
        rect: Rect.fromLTRB(0, 0, fold.rect.left + 37, signal.size.height),
        padding: EdgeInsets.zero,
      ),
      detail: Pane(
        rect: Rect.fromLTRB(fold.rect.right - 19, 0, signal.size.width, signal.size.height),
        padding: EdgeInsets.zero,
      ),
      fold: fold,
      recorder: base.recorder,
      modal: base.modal,
    );
    expect(duoFoldInsets(layout, PaneTouch.journal).right, 37);
    expect(duoFoldInsets(layout, PaneTouch.detail).left, 19);
    expect(duoFoldInsets(layout, null), EdgeInsets.zero);
  });
  test('the same inner entry keeps its detail identity through selection and display changes', () {
    final first = Uri.parse('/entry/a');
    final selected = Uri.parse('/entry/a?selection=1');
    final identity = duoDetailIdentity(
      inner: true,
      entryId: 'a',
      location: selected,
      previousEntryId: 'a',
      previousLocation: first,
      previousIdentity: first,
    );
    expect(identity, same(first));
    expect(
      duoDetailIdentity(
        inner: false,
        entryId: 'a',
        location: selected,
        previousEntryId: 'a',
        previousLocation: selected,
        previousIdentity: identity,
      ),
      same(first),
    );
    final next = Uri.parse('/entry/b');
    expect(
      duoDetailIdentity(
        inner: true,
        entryId: 'b',
        location: next,
        previousEntryId: 'a',
        previousLocation: selected,
        previousIdentity: first,
      ),
      same(next),
    );
    expect(
      duoDetailIdentity(
        inner: false,
        entryId: 'a',
        location: selected,
        previousEntryId: 'a',
        previousLocation: first,
        previousIdentity: first,
      ),
      same(selected),
    );
  });
}
