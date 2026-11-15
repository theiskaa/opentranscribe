import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';

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
  return role == PaneTouch.journal
      ? const EdgeInsets.only(right: AppDuo.foldMargin)
      : const EdgeInsets.only(left: AppDuo.foldMargin);
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
}) {
  final block = AppSpacing.md + titleLine + AppSpacing.xxs + subtitleLine;
  final header = math.max(minimum, block);
  final baseline =
      (header - block) / 2 + AppSpacing.md + titleLine / 2 + AppDuo.baselineEm * titleSize;
  return (header: header, detailTop: baseline - detailLine / 2 - AppDuo.baselineEm * detailSize);
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
