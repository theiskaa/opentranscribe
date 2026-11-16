import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

/// How far the signal's size may sit from the window's and still describe it.
const _sizeSlack = 0.5;

/// Lays the window out as one column or as the journal beside a detail.
///
/// Splits only on a supported display, with a regular, wider than tall
/// window that holds two closed-width columns, and never at large text. An
/// unsupported signal, or one still describing a window of another size, is
/// always today's single column with the window's insets, so a phone without
/// reserved regions sees no change and a fold never lays out on stale regions.
PaneLayout paneLayoutFor(PaneInputs inputs) {
  final size = inputs.size;
  final padding = inputs.padding;
  final signal = inputs.signal;
  final window = Offset.zero & size;
  final safe = padding.deflateRect(window);
  final largeText = inputs.bodySize >= AppType.largeTextBody;

  if (!signal.supported || !displaySignalDescribes(signal, size)) {
    final pane = Pane(rect: window, padding: padding);
    return PaneLayout(
      mode: PaneMode.single,
      leading: pane,
      detail: pane,
      recorder: RecorderLayout(arrangement: RecorderArrangement.column, first: safe),
      modal: _modalOf(null, size, padding),
    );
  }

  final fold = _foldOf(signal, size, padding);
  final sideColumn = _sideColumnOf(size, padding, signal);
  final regular = signal.horizontal == SizeClass.regular;
  final wide = size.width > size.height;
  final recorder = _recorderOf(
    size: size,
    safe: safe,
    signal: signal,
    fold: fold,
    regular: regular,
    wide: wide,
    largeText: largeText,
  );

  final closed = inputs.closedContentWidth;
  final holdsTwo = safe.width >= 2 * closed + AppStroke.hairline;
  final split = regular && wide && !largeText && holdsTwo
      ? _splitOf(size, padding, fold, closed, sideColumn)
      : null;
  if (split != null) {
    final detail = split.detail;
    return PaneLayout(
      mode: PaneMode.split,
      leading: split.leading,
      detail: detail,
      divider: split.divider,
      fold: fold,
      sideColumn: sideColumn,
      recorder: recorder,
      modal: Rect.fromLTRB(
        detail.rect.left + detail.padding.left,
        detail.rect.top,
        detail.rect.right - detail.padding.right,
        detail.rect.bottom,
      ),
    );
  }

  final pane = Pane(rect: window, padding: padding, barToSideColumn: sideColumn != null);
  return PaneLayout(
    mode: PaneMode.single,
    leading: pane,
    detail: pane,
    fold: fold,
    sideColumn: sideColumn,
    recorder: recorder,
    modal: _modalOf(fold, size, padding),
  );
}

bool displaySignalDescribes(DisplaySignal signal, Size size) =>
    (signal.size.width - size.width).abs() <= _sizeSlack &&
    (signal.size.height - size.height).abs() <= _sizeSlack;

/// The window between its side insets, or one side of an active fold: the
/// trailing half of a book fold, the lower half of a laptop fold.
Rect _modalOf(Fold? fold, Size size, EdgeInsets padding) {
  final left = switch (fold?.axis) {
    FoldAxis.vertical => math.max(fold!.rect.right, padding.left),
    _ => padding.left,
  };
  final top = fold?.axis == FoldAxis.horizontal ? fold!.rect.bottom : 0.0;
  final right = math.max(left, size.width - padding.right);
  return Rect.fromLTRB(left, top, right, size.height);
}

FoldAxis _axisOf(Rect rect) => rect.height >= rect.width ? FoldAxis.vertical : FoldAxis.horizontal;

/// The active division, when content lies on both sides of it. A Split View
/// half holds the fold clipped at its edge, which parts nothing.
Fold? _foldOf(DisplaySignal signal, Size size, EdgeInsets padding) {
  final rect = signal.activeDivision?.rect;
  if (rect == null) return null;
  final axis = _axisOf(rect);
  final parts = switch (axis) {
    FoldAxis.vertical => rect.left > padding.left && rect.right < size.width - padding.right,
    FoldAxis.horizontal => rect.top > padding.top && rect.bottom < size.height - padding.bottom,
  };
  return parts ? Fold(rect: rect, axis: axis) : null;
}

SideColumn? _sideColumnOf(Size size, EdgeInsets padding, DisplaySignal signal) {
  final side = signal.barSide;
  final width = switch (side) {
    BarSide.left => padding.left,
    BarSide.right => padding.right,
    BarSide.none => 0.0,
  };
  if (width <= 0) return null;
  final rect = side == BarSide.left
      ? Rect.fromLTWH(0, 0, width, size.height)
      : Rect.fromLTWH(size.width - width, 0, width, size.height);
  double? cluster;
  for (final region in signal.regions) {
    if (region.kind != RegionKind.occlusion || !region.active) continue;
    // The status cluster hangs from the top of the strip; an occlusion
    // starting in its lower half is a sensor the controls need not clear.
    if (!region.rect.overlaps(rect) || region.rect.top >= size.height / 2) continue;
    cluster = math.max(cluster ?? 0, region.rect.bottom);
  }
  final bottomEdge = size.height - padding.bottom;
  final topEdge = math.min(math.max(cluster ?? padding.top, padding.top), bottomEdge);
  final middle = (topEdge + bottomEdge) / 2;
  return SideColumn(
    rect: rect,
    side: side,
    upperSlot: Rect.fromLTRB(rect.left, topEdge, rect.right, middle),
    lowerSlot: Rect.fromLTRB(rect.left, middle, rect.right, bottomEdge),
    occlusions: List.unmodifiable([
      for (final region in signal.regions)
        if (region.active && region.rect.overlaps(rect)) region.rect.intersect(rect),
    ]),
  );
}

({Pane leading, Pane detail, Rect? divider})? _splitOf(
  Size size,
  EdgeInsets padding,
  Fold? fold,
  double closed,
  SideColumn? sideColumn,
) {
  final Rect leading;
  final Rect detail;
  Rect? divider;
  if (fold?.axis == FoldAxis.vertical) {
    leading = Rect.fromLTRB(0, 0, fold!.rect.left, size.height);
    detail = Rect.fromLTRB(fold.rect.right, 0, size.width, size.height);
  } else {
    final edge = padding.left + math.min(closed, AppDuo.navigationWidth);
    leading = Rect.fromLTRB(0, 0, edge, size.height);
    divider = Rect.fromLTWH(edge, 0, AppStroke.hairline, size.height);
    detail = Rect.fromLTRB(edge + AppStroke.hairline, 0, size.width, size.height);
  }
  if (leading.width <= padding.left || detail.width <= padding.right) return null;
  return (
    leading: Pane(
      rect: leading,
      padding: EdgeInsets.fromLTRB(padding.left, padding.top, 0, padding.bottom),
    ),
    detail: Pane(
      rect: detail,
      padding: EdgeInsets.fromLTRB(0, padding.top, padding.right, padding.bottom),
      barToSideColumn: sideColumn?.side == BarSide.right,
    ),
    divider: divider,
  );
}

RecorderLayout _recorderOf({
  required Size size,
  required Rect safe,
  required DisplaySignal signal,
  required Fold? fold,
  required bool regular,
  required bool wide,
  required bool largeText,
}) {
  if (largeText || !regular) {
    return RecorderLayout(arrangement: RecorderArrangement.column, first: safe);
  }
  if (wide) {
    final double instrumentEnd;
    final double wordsStart;
    if (fold?.axis == FoldAxis.vertical) {
      instrumentEnd = fold!.rect.left - AppDuo.recorderFoldOffset;
      wordsStart = fold.rect.right;
    } else {
      instrumentEnd = wordsStart = safe.center.dx;
    }
    return RecorderLayout(
      arrangement: RecorderArrangement.sideBySide,
      first: Rect.fromLTRB(safe.left, safe.top, instrumentEnd, safe.bottom),
      second: Rect.fromLTRB(wordsStart, safe.top, safe.right, safe.bottom),
    );
  }
  // The division read active or not, so bending into the laptop pose moves
  // nothing on screen.
  final division = signal.division?.rect;
  final band = division != null && _axisOf(division) == FoldAxis.horizontal
      ? division
      : Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width,
          height: AppDuo.foldBand,
        );
  return RecorderLayout(
    arrangement: RecorderArrangement.stacked,
    first: Rect.fromLTRB(safe.left, safe.top, safe.right, band.top),
    second: Rect.fromLTRB(safe.left, band.bottom, safe.right, safe.bottom),
  );
}
