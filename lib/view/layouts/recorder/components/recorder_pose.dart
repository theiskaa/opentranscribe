import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/pane_geometry.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';
import 'package:opentranscribe/view/widgets/safe_sides.dart';
import 'package:opentranscribe/view/widgets/side_column.dart';

enum RecorderBlock { header, continuing, wave, words, notice, controls, language }

Pane recorderPermissionPane(PaneLayout layout) =>
    layout.recorder.arrangement == RecorderArrangement.column && layout.fold == null
    ? layout.leading
    : Pane(rect: centeredRecorderRegion(layout), padding: EdgeInsets.zero);

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

class RecorderPose extends StatefulWidget {
  const RecorderPose({
    required this.header,
    required this.continuing,
    required this.wave,
    required this.words,
    required this.notice,
    required this.controls,
    required this.language,
    this.centered = false,
    super.key,
  });

  final Widget header;
  final Widget continuing;
  final Widget wave;
  final Widget words;
  final Widget notice;
  final Widget controls;
  final Widget language;
  final bool centered;

  @override
  State<RecorderPose> createState() => _RecorderPoseState();
}

class _RecorderPoseState extends State<RecorderPose> {
  // Reparent the existing waveform and word window when the cover changes the layout.
  final _keys = {for (final block in RecorderBlock.values) block: GlobalKey()};

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
    final blocks = {
      RecorderBlock.header: widget.header,
      RecorderBlock.continuing: widget.continuing,
      RecorderBlock.wave: widget.wave,
      RecorderBlock.words: widget.words,
      RecorderBlock.notice: widget.notice,
      RecorderBlock.controls: widget.controls,
      RecorderBlock.language: widget.language,
    };
    Widget child(RecorderBlock block, MediaQueryData data) => KeyedSubtree(
      key: _keys[block],
      child: MediaQuery(data: data, child: blocks[block]!),
    );
    if (widget.centered) {
      final region = PaneGlide.recorderRegionOf(context);
      final contentMedia = paneMediaData(media, Pane(rect: region, padding: EdgeInsets.zero));
      final language = recorderBlockRects(
        layout,
        heights: const {},
        barHeight: context.theme.topBar.height,
        direction: Directionality.of(context),
        languageSize: const Size.square(AppSizes.barControl),
      )[RecorderBlock.language]!;
      return Stack(
        children: [
          const SideColumnGround(window: true),
          Positioned.fromRect(
            rect: region,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                  vertical: AppRecorderLayout.verticalInset,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(
                      0,
                      constraints.maxHeight - AppRecorderLayout.verticalInset * 2,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AppRecorderLayout.contentWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          child(RecorderBlock.header, contentMedia),
                          child(RecorderBlock.continuing, contentMedia),
                          child(RecorderBlock.wave, contentMedia),
                          const SizedBox(height: AppSpacing.lg),
                          child(RecorderBlock.words, contentMedia),
                          const SizedBox(height: AppSpacing.xxxl),
                          child(RecorderBlock.notice, contentMedia),
                          child(RecorderBlock.controls, contentMedia),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fromRect(rect: language, child: child(RecorderBlock.language, media)),
        ],
      );
    }
    return Stack(
      children: [
        const SideColumnGround(window: true),
        CustomMultiChildLayout(
          delegate: _RecorderPoseLayout(
            layout: layout,
            barHeight: context.theme.topBar.height,
            direction: Directionality.of(context),
          ),
          children: [
            for (final block in RecorderBlock.values)
              LayoutId(
                id: block,
                child: block == RecorderBlock.language
                    ? Semantics(
                        container: !column && layout.sideColumn != null,
                        sortKey: !column && layout.sideColumn != null
                            ? const OrdinalSortKey(2)
                            : null,
                        child: child(block, media),
                      )
                    : child(block, block == RecorderBlock.header ? headerMedia : bodyMedia),
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
