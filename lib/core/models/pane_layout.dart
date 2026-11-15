/// @docImport 'package:opentranscribe/core/theming/type_scale.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:opentranscribe/core/models/display_signal.dart';

/// One column of content, or the journal beside a detail.
enum PaneMode { single, split }

/// Which way the fold's line runs: [vertical] top to bottom (the book pose),
/// [horizontal] side to side (the laptop pose).
enum FoldAxis { vertical, horizontal }

/// How the recorder lays out. [column] is today's screen. [sideBySide] puts
/// the clock, the wave and the controls on the leading half and the live
/// words on the trailing half. [stacked] puts the words and the clock on top
/// and the wave and the controls below the fold.
enum RecorderArrangement { column, sideBySide, stacked }

/// What the pane layout is computed from.
@immutable
final class PaneInputs {
  const PaneInputs({
    required this.size,
    required this.padding,
    required this.signal,
    required this.bodySize,
    required this.closedContentWidth,
  });

  /// The window, as `MediaQuery` reports it.
  final Size size;

  /// The window's safe insets, as `MediaQuery` reports them.
  final EdgeInsets padding;

  final DisplaySignal signal;

  /// [AppType.body]'s font size after the text scaler.
  final double bodySize;

  /// The width the journal pane keeps when split flat.
  final double closedContentWidth;
}

/// A rectangle of the window a screen lays out in as if it were the window.
@immutable
final class Pane {
  const Pane({required this.rect, required this.padding, this.barToSideColumn = false});

  /// In window coordinates.
  final Rect rect;

  /// The safe insets this pane sees: only the window edges it touches.
  final EdgeInsets padding;

  /// Whether its bar's controls move into the side column.
  final bool barToSideColumn;

  @override
  bool operator ==(Object other) =>
      other is Pane &&
      other.rect == rect &&
      other.padding == padding &&
      other.barToSideColumn == barToSideColumn;

  @override
  int get hashCode => Object.hash(rect, padding, barToSideColumn);

  @override
  String toString() => 'Pane($rect, $padding, side column: $barToSideColumn)';
}

/// The fold while it reserves space, already widened by Apple's margins.
@immutable
final class Fold {
  const Fold({required this.rect, required this.axis});

  final Rect rect;
  final FoldAxis axis;

  @override
  bool operator ==(Object other) => other is Fold && other.rect == rect && other.axis == axis;

  @override
  int get hashCode => Object.hash(rect, axis);

  @override
  String toString() => 'Fold($rect, ${axis.name})';
}

/// The strip the vertical bar reserves at the window's side, where a pane's
/// bar controls stand when they cannot sit in a row.
@immutable
final class SideColumn {
  const SideColumn({
    required this.rect,
    required this.side,
    required this.upperSlot,
    required this.lowerSlot,
  });

  final Rect rect;
  final BarSide side;

  /// Under the status cluster: the bar's leading control first, then its actions.
  final Rect upperSlot;

  /// Above the bottom inset: the record disc and the floating action.
  final Rect lowerSlot;

  @override
  bool operator ==(Object other) =>
      other is SideColumn &&
      other.rect == rect &&
      other.side == side &&
      other.upperSlot == upperSlot &&
      other.lowerSlot == lowerSlot;

  @override
  int get hashCode => Object.hash(rect, side, upperSlot, lowerSlot);

  @override
  String toString() => 'SideColumn($rect, ${side.name}, upper: $upperSlot, lower: $lowerSlot)';
}

/// The recorder's blocks, inside the safe area and named by position: [first]
/// is the leading or the upper block, [second] the other. A
/// [RecorderArrangement.column] has only [first], the whole screen.
@immutable
final class RecorderLayout {
  const RecorderLayout({required this.arrangement, required this.first, this.second});

  final RecorderArrangement arrangement;
  final Rect first;
  final Rect? second;

  @override
  bool operator ==(Object other) =>
      other is RecorderLayout &&
      other.arrangement == arrangement &&
      other.first == first &&
      other.second == second;

  @override
  int get hashCode => Object.hash(arrangement, first, second);

  @override
  String toString() => 'RecorderLayout(${arrangement.name}, $first, $second)';
}

/// Where everything goes on the current window.
@immutable
final class PaneLayout {
  const PaneLayout({
    required this.mode,
    required this.leading,
    required this.detail,
    required this.recorder,
    required this.modal,
    this.divider,
    this.fold,
    this.sideColumn,
  });

  /// Whether pushed pages cover the journal or open beside it.
  final PaneMode mode;

  /// The journal's pane. In [PaneMode.single] it is the window, the same as
  /// [detail].
  final Pane leading;

  /// Where a selection opens: beside the journal when split, the window when
  /// single.
  final Pane detail;

  /// The recorder's arrangement, whatever the [mode]: it is a full-window route.
  final RecorderLayout recorder;

  /// The rect sheets, menus and notices centre in: never across the fold and
  /// never over the side column.
  final Rect modal;

  /// The hairline between flat panes; null when single or when the fold
  /// already parts them.
  final Rect? divider;

  /// The fold while it reserves space, in either mode; null when the device is
  /// flat, closed, or reports no regions.
  final Fold? fold;

  /// The vertical bar's strip; null when the bar runs along the top.
  final SideColumn? sideColumn;

  @override
  bool operator ==(Object other) =>
      other is PaneLayout &&
      other.mode == mode &&
      other.leading == leading &&
      other.detail == detail &&
      other.recorder == recorder &&
      other.modal == modal &&
      other.divider == divider &&
      other.fold == fold &&
      other.sideColumn == sideColumn;

  @override
  int get hashCode =>
      Object.hash(mode, leading, detail, recorder, modal, divider, fold, sideColumn);

  @override
  String toString() =>
      'PaneLayout(${mode.name}, leading: $leading, detail: $detail, fold: $fold, '
      'side: $sideColumn, recorder: $recorder, modal: $modal)';
}
