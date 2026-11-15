import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';

bool duoPolishEnabled({
  required PaneLayout? layout,
  required bool supported,
  required bool cover,
  required bool regular,
  required Size window,
}) =>
    supported &&
    !cover &&
    layout != null &&
    (layout.mode == PaneMode.split || (regular && window.width > window.height));

EdgeInsets duoFoldInsets(PaneLayout layout, PaneTouch? role) {
  final fold = layout.fold;
  if (layout.mode != PaneMode.split || fold?.axis != FoldAxis.vertical) return EdgeInsets.zero;
  if (role == null) return EdgeInsets.zero;
  final pane = role == PaneTouch.journal ? layout.leading.rect : layout.detail.rect;
  return role == PaneTouch.journal
      ? EdgeInsets.only(right: math.max(0, pane.right - fold!.rect.left))
      : EdgeInsets.only(left: math.max(0, fold!.rect.right - pane.left));
}

EdgeInsets duoDetailInsets({
  required double width,
  required EdgeInsets safe,
  required EdgeInsets fold,
  required double top,
  required double bottom,
}) {
  final left = safe.left + math.max(AppDuo.detailMargin, fold.left);
  final right = safe.right + math.max(AppDuo.detailMargin, fold.right);
  final measure = math.max(0.0, width - left - right);
  return EdgeInsets.fromLTRB(
    left,
    safe.top + top,
    right + math.max(0, measure - AppDuo.detailMeasure),
    bottom,
  );
}

({double cell, double gap}) duoWeekMetrics(double width) {
  final available = math.max(0.0, width);
  final gap = math.min(AppDuo.dayGap, available / 6);
  final cell = math.min(AppDuo.dayWidth, math.max(0.0, (available - gap * 6) / 7));
  return (cell: cell, gap: math.max(gap, (available - cell * 7) / 6));
}

bool duoRowSeparator({required bool last, required bool selected, required bool nextSelected}) =>
    !last && !selected && !nextSelected;

({double header, double detailTop}) duoHeaderMetrics({
  required double minimum,
  required double titleLine,
  required double titleSize,
  required double subtitleLine,
  required double detailLine,
  required double detailSize,
  double? titleBaseline,
  double? detailBaseline,
}) {
  final block = AppSpacing.md + titleLine + AppSpacing.xxs + subtitleLine;
  final header = math.max(minimum, block);
  final baseline =
      (header - block) / 2 +
      AppSpacing.md +
      (titleBaseline ?? titleLine / 2 + AppDuo.baselineEm * titleSize);
  return (
    header: header,
    detailTop: baseline - (detailBaseline ?? detailLine / 2 + AppDuo.baselineEm * detailSize),
  );
}

double duoDayHeight({required double letterLine, required double numberLine}) =>
    math.max(AppDuo.dayHeight, letterLine + AppSpacing.xxs + numberLine + AppDuo.dayDotClearance);

Rect? duoDividerRect(PaneLayout layout, EdgeInsets safe) {
  final divider = layout.divider;
  if (divider == null || layout.fold != null) return null;
  final top = math.max(divider.top, safe.top);
  final bottom = math.max(top, divider.bottom - safe.bottom);
  return Rect.fromLTRB(divider.left, top, divider.right, bottom);
}

Rect duoSheetRegion({
  required PaneLayout layout,
  required PaneTouch? source,
  required Size window,
}) {
  if (layout.fold == null) return Offset.zero & window;
  if (layout.mode != PaneMode.split || source == null) return layout.modal;
  return source == PaneTouch.journal ? layout.leading.rect : layout.detail.rect;
}

Rect? duoDaySelection({
  required List<DateTime> days,
  required DateTime selected,
  required double width,
  required double height,
  TextDirection direction = TextDirection.ltr,
}) {
  final index = days.indexOf(selected);
  if (index < 0) return null;
  final metrics = duoWeekMetrics(width);
  final left = index * (metrics.cell + metrics.gap);
  return Rect.fromLTWH(
    direction == TextDirection.rtl ? width - left - metrics.cell : left,
    0,
    metrics.cell,
    height,
  );
}

({double opacity, double rise}) duoDetailVisual({
  required double progress,
  required bool incoming,
  required bool reduce,
  required AppMotion motion,
}) {
  final value = progress.clamp(0.0, 1.0);
  final fade = reduce || !incoming
      ? value
      : (value *
                motion.duoDetailEnter.inMicroseconds /
                math.max(1, motion.duoDetailFade.inMicroseconds))
            .clamp(0.0, 1.0);
  return (
    opacity: motion.duoDetailCurve.transform(fade),
    rise: reduce || !incoming
        ? 0
        : motion.duoDetailRise * (1 - motion.duoEnterCurve.transform(value)),
  );
}

({double height, double baseline}) duoTextMetrics({
  required TextStyle style,
  required TextScaler scaler,
}) {
  final painter = TextPainter(
    text: TextSpan(text: '0', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final metrics = (
    height: painter.height,
    baseline: painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
  );
  painter.dispose();
  return metrics;
}

Object duoDetailIdentity({
  required bool inner,
  required String entryId,
  required Uri location,
  required String? previousEntryId,
  required Uri? previousLocation,
  required Object? previousIdentity,
}) =>
    previousIdentity == null ||
        entryId != previousEntryId ||
        (!inner && location != previousLocation)
    ? location
    : previousIdentity;
