import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';

void main() {
  test('the detail measure uses the actual pane and clears its side column', () {
    for (final width in [0.0, 320.0, 540.0, 1200.0]) {
      for (final safe in [const EdgeInsets.only(left: 64), const EdgeInsets.only(right: 64)]) {
        final insets = duoDetailInsets(
          width: width,
          safe: safe,
          fold: EdgeInsets.zero,
          top: 0,
          bottom: 0,
        );
        final measure = duoContentMeasure(width, insets);
        expect(measure, inInclusiveRange(0, AppDuo.detailMeasure));
        if (width == 540) expect(measure, 428);
        if (width == 1200) expect(measure, AppDuo.detailMeasure);
      }
    }
  });

  test('the shared grid keeps title and metadata baselines and clears both columns', () {
    for (final scale in [1.0, 1.3, 1.6, 2.5]) {
      final player = duoPlayerHeight(17 * scale);
      final grid = duoReadingGrid(
        journalLine: 34.5 * scale,
        journalBaseline: 28 * scale,
        detailBaseline: 23 * scale,
        metadataLine: 18.2 * scale,
        metadataBaseline: 14 * scale,
        dayHeight: 56 * scale,
        playerHeight: player,
      );
      expect(grid.detailTop + 23 * scale, closeTo(grid.journalTop + 28 * scale, 0.001));
      expect(grid.stripTop, greaterThanOrEqualTo(grid.header + AppSpacing.md));
      expect(grid.bodyTop, greaterThanOrEqualTo(grid.stripTop + player + AppSpacing.md));
      expect(grid.bodyTop, greaterThanOrEqualTo(grid.stripTop + 56 * scale + AppSpacing.xxl));
      if (scale == 1) {
        expect(grid.metadataTop + 14, 60);
        expect(grid.stripTop, 84);
      }
      final gaps = duoDocumentGaps(
        titleHeight: 27.6 * scale,
        metadataHeight: 18.2 * scale,
        grid: grid,
        top: grid.detailTop,
      );
      expect(gaps.metadata, greaterThanOrEqualTo(AppSpacing.xxs));
      expect(gaps.player, greaterThanOrEqualTo(AppSpacing.md));
    }
  });

  test('wrapped titles and metadata expand the header without overlap', () {
    final grid = duoReadingGrid(
      journalLine: 35,
      journalBaseline: 28,
      detailBaseline: 23,
      metadataLine: 18,
      metadataBaseline: 14,
      dayHeight: 56,
      playerHeight: 105,
    );
    final gaps = duoDocumentGaps(
      titleHeight: 56,
      metadataHeight: 54,
      grid: grid,
      top: grid.detailTop,
    );
    expect(gaps.metadata, AppSpacing.xxs);
    expect(gaps.player, AppSpacing.md);
  });

  test('rows separate the first sentence from the remaining words without duplication', () {
    expect(duoRowText(text: '  First thought. More of the day.  '), (
      title: 'First thought.',
      preview: 'More of the day.',
    ));
    expect(duoRowText(title: 'A title', text: 'The full body.'), (
      title: 'A title',
      preview: 'The full body.',
    ));
    expect(duoRowText(text: 'One short thought'), (title: 'One short thought', preview: ''));
    expect(duoRowText(text: '一つ。 次。'), (title: '一つ。', preview: '次。'));
    expect(duoRowText(text: 'First line\nSecond line'), (
      title: 'First line',
      preview: 'Second line',
    ));
    expect(duoRowText(text: ''), (title: '', preview: ''));
  });

  test('a long first sentence leaves a preview at the measured row width', () {
    const body =
        'A long thought with enough words to wrap beyond the title line and continue below.';
    final words = duoRowText(text: body, width: 160);
    expect(words.title, isNotEmpty);
    expect(words.preview, isNotEmpty);
    expect('${words.title} ${words.preview}', body);
  });

  test('the reading measure wraps metadata as the pane narrows or text grows', () {
    const text = 'Sunday, November 15 · 0:05 · English (US)';
    final wide = duoParagraphHeight(
      text,
      style: DuoTheme.metadata,
      scaler: TextScaler.noScaling,
      width: 427,
    );
    final narrow = duoParagraphHeight(
      text,
      style: DuoTheme.metadata,
      scaler: TextScaler.noScaling,
      width: 240,
    );
    final large = duoParagraphHeight(
      text,
      style: DuoTheme.metadata,
      scaler: const TextScaler.linear(1.6),
      width: 427,
    );
    expect(narrow, greaterThanOrEqualTo(wide));
    expect(large, greaterThan(wide));
    expect(duoContentMeasure(540, const EdgeInsets.fromLTRB(28, 0, 85, 0)), 427);
  });

  test('month grouping includes an old entry made on the first of a month', () {
    expect(duoJournalIsMonthly(DateTime(2026, 11), DateTime(2026, 11, 16)), isTrue);
    expect(duoJournalIsMonthly(DateTime(2026, 11, 2), DateTime(2026, 11, 16)), isFalse);
  });

  test('remaining playback time clamps the final and overshooting positions to zero', () {
    const duration = Duration(seconds: 65);
    expect(duoRemaining(duration, Duration.zero), duration);
    expect(duoRemaining(duration, const Duration(seconds: 5)), const Duration(seconds: 60));
    expect(duoRemaining(duration, duration), Duration.zero);
    expect(duoRemaining(duration, const Duration(seconds: 66)), Duration.zero);
    expect(duoRemaining(Duration.zero, Duration.zero), Duration.zero);
  });

  test('one older day names the day whose duplicate section header is hidden', () {
    final today = DateTime(2026, 11, 16);
    final older = DateTime(2026, 11, 15);
    expect(
      duoJournalHeadingDay(viewed: null, today: today, days: [older], takePending: false),
      older,
    );
    expect(
      duoJournalHeadingDay(viewed: null, today: today, days: [older], takePending: true),
      today,
    );
    expect(duoJournalHeadingDay(viewed: null, today: today, days: [], takePending: false), today);
    expect(
      duoJournalHeadingDay(viewed: older, today: today, days: [today, older], takePending: false),
      older,
    );
  });

  test('a single day hides its header and older days share one header per month', () {
    final now = DateTime(2026, 11, 16);
    expect(duoJournalHeaders([], now), isEmpty);
    expect(duoJournalHeaders([now], now), [null]);
    expect(
      duoJournalHeaders([
        now,
        DateTime(2026, 11, 15),
        DateTime(2026, 11, 2),
        DateTime(2026, 11),
        DateTime(2026, 10, 31),
        DateTime(2026, 10),
        DateTime(2025, 11),
      ], now),
      [
        now,
        DateTime(2026, 11, 15),
        DateTime(2026, 11, 2),
        DateTime(2026, 11),
        DateTime(2026, 10),
        null,
        DateTime(2025, 11),
      ],
    );
  });
}
