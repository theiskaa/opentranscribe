import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';
import 'package:opentranscribe/view/widgets/safe_sides.dart';
import 'package:opentranscribe/view/widgets/side_column.dart';

enum RecorderBlock { header, continuing, wave, words, notice, controls, language }

Pane recorderPermissionPane(PaneLayout layout) =>
    layout.recorder.arrangement == RecorderArrangement.column
    ? layout.leading
    : Pane(rect: layout.recorder.first, padding: EdgeInsets.zero);

Map<RecorderBlock, Rect> recorderBlockRects(
  PaneLayout layout, {
  required Map<RecorderBlock, double> heights,
  required double barHeight,
  required TextDirection direction,
  Size languageSize = Size.zero,
}) {
  final recorder = layout.recorder;
  final column = recorder.arrangement == RecorderArrangement.column;
  final stacked = recorder.arrangement == RecorderArrangement.stacked;
  final first = recorder.first;
  final second = recorder.second ?? first;
  final window = layout.leading.rect.expandToInclude(layout.detail.rect);
  final header = Rect.fromLTWH(
    column ? window.left : first.left,
    column ? window.top : first.top,
    column ? window.width : first.width,
    heights[RecorderBlock.header] ?? 0,
  );
  final instrument = stacked ? second : first;
  final words = column || stacked ? first : second;
  const inset = AppRecorderLayout.columnInset;
  double height(RecorderBlock block) => heights[block] ?? 0;
  Rect block(RecorderBlock id, Rect region, double top) =>
      Rect.fromLTWH(region.left + inset, top, math.max(0, region.width - inset * 2), height(id));

  final instrumentTop = stacked ? instrument.top : header.bottom;
  final contentHeight =
      height(RecorderBlock.continuing) +
      height(RecorderBlock.wave) +
      (column ? AppSpacing.lg + height(RecorderBlock.words) : 0);
  final restingNoticeTop =
      instrument.bottom -
      AppSpacing.xl -
      height(RecorderBlock.controls) -
      height(RecorderBlock.notice);
  final notice = block(
    RecorderBlock.notice,
    instrument,
    column ? math.max(restingNoticeTop, instrumentTop + contentHeight) : restingNoticeTop,
  );
  final controls = block(RecorderBlock.controls, instrument, notice.bottom);
  final free = math.max(0, notice.top - instrumentTop - contentHeight);
  final continuing = block(
    RecorderBlock.continuing,
    instrument,
    instrumentTop +
        free *
            AppRecorderLayout.upperSpace /
            (AppRecorderLayout.upperSpace + AppRecorderLayout.lowerSpace),
  );
  final wave = block(RecorderBlock.wave, instrument, continuing.bottom);
  final wordsTop = column
      ? wave.bottom + AppSpacing.lg
      : (stacked ? header.bottom : words.top) +
            math.max(
              0,
              (words.bottom - (stacked ? header.bottom : words.top) - height(RecorderBlock.words)) /
                  2,
            );
  final slot = column ? null : layout.sideColumn?.upperSlot;
  final language = slot != null
      ? sideColumnSlots(slot, [languageSize]).single
      : Rect.fromLTWH(
          direction == TextDirection.ltr
              ? first.right - AppSpacing.md - languageSize.width
              : first.left + AppSpacing.md,
          first.top + (barHeight - languageSize.height) / 2,
          languageSize.width,
          languageSize.height,
        );
  return {
    RecorderBlock.header: header,
    RecorderBlock.continuing: continuing,
    RecorderBlock.wave: wave,
    RecorderBlock.words: block(RecorderBlock.words, words, wordsTop),
    RecorderBlock.notice: notice,
    RecorderBlock.controls: controls,
    RecorderBlock.language: language,
  };
}

class RecorderPose extends StatelessWidget {
  const RecorderPose({
    required this.header,
    required this.continuing,
    required this.wave,
    required this.words,
    required this.notice,
    required this.controls,
    required this.language,
    super.key,
  });

  final Widget header;
  final Widget continuing;
  final Widget wave;
  final Widget words;
  final Widget notice;
  final Widget controls;
  final Widget language;

  @override
  Widget build(BuildContext context) {
    final tracker = PaneLayoutScope.of(context);
    final layout = PaneGlide.layoutOf(context);
    final media = tracker.media;
    final column = layout.recorder.arrangement == RecorderArrangement.column;
    final headerMedia = column
        ? media
        : paneMediaData(media, Pane(rect: layout.recorder.first, padding: EdgeInsets.zero));
    final bodyMedia = column ? safeSidesData(media) : headerMedia;
    return Stack(
      children: [
        const SideColumnGround(window: true),
        CustomMultiChildLayout(
          delegate: _RecorderPoseLayout(
            layout: layout,
            barHeight: context.theme.topBar.height,
            direction: Directionality.of(context),
          ),
          // The slots stay mounted through stale signals and every pose, preserving bars and scroll.
          children: [
            LayoutId(
              id: RecorderBlock.header,
              child: MediaQuery(data: headerMedia, child: header),
            ),
            LayoutId(
              id: RecorderBlock.continuing,
              child: MediaQuery(data: bodyMedia, child: continuing),
            ),
            LayoutId(
              id: RecorderBlock.wave,
              child: MediaQuery(data: bodyMedia, child: wave),
            ),
            LayoutId(
              id: RecorderBlock.words,
              child: MediaQuery(data: bodyMedia, child: words),
            ),
            LayoutId(
              id: RecorderBlock.notice,
              child: MediaQuery(data: bodyMedia, child: notice),
            ),
            LayoutId(
              id: RecorderBlock.controls,
              child: MediaQuery(data: bodyMedia, child: controls),
            ),
            LayoutId(
              id: RecorderBlock.language,
              child: Semantics(
                container: !column && layout.sideColumn != null,
                sortKey: !column && layout.sideColumn != null ? const OrdinalSortKey(2) : null,
                child: language,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecorderPoseLayout extends MultiChildLayoutDelegate {
  _RecorderPoseLayout({required this.layout, required this.barHeight, required this.direction});

  final PaneLayout layout;
  final double barHeight;
  final TextDirection direction;

  @override
  void performLayout(Size size) {
    final widths = recorderBlockRects(
      layout,
      heights: const {},
      barHeight: barHeight,
      direction: direction,
    );
    final heights = <RecorderBlock, double>{};
    for (final block in RecorderBlock.values) {
      if (block == RecorderBlock.language) continue;
      heights[block] = layoutChild(
        block,
        BoxConstraints.tightFor(width: widths[block]!.width),
      ).height;
    }
    final language = layoutChild(
      RecorderBlock.language,
      const BoxConstraints(maxWidth: AppSizes.barControl, maxHeight: AppSizes.barControl),
    );
    final rects = recorderBlockRects(
      layout,
      heights: heights,
      barHeight: barHeight,
      direction: direction,
      languageSize: language,
    );
    for (final block in RecorderBlock.values) {
      positionChild(block, rects[block]!.topLeft);
    }
  }

  @override
  bool shouldRelayout(_RecorderPoseLayout oldDelegate) =>
      layout != oldDelegate.layout ||
      barHeight != oldDelegate.barHeight ||
      direction != oldDelegate.direction;
}
