import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:opentranscribe/view/widgets/duo_style.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/anchored_popup.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/side_column.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';

/// One choice in a dropdown: a selectable row (see [SelectableRow]). [flag] is
/// the leading flag chip for a language row; null for a plain choice (a
/// reflection option) that shows just the label and its checkmark.
class AppDropdownItem {
  const AppDropdownItem({required this.label, this.flag, this.selected = false});

  final String label;
  final String? flag;
  final bool selected;
}

/// The screen-space rect to grow a dropdown from: [key]'s render box, or a
/// top-right fallback when it is not laid out yet. Shared by the bar menus that
/// open a fallback dropdown anchored to their own button. [context] must see
/// the window's MediaQuery (a bar's, never one under `SafeSides`): the
/// fallback is in window coordinates.
Rect dropdownAnchorRect(GlobalKey key, BuildContext context) {
  final box = key.currentContext?.findRenderObject();
  if (box is RenderBox && box.attached) return box.localToGlobal(Offset.zero) & box.size;
  final scope = PaneScope.maybeOf(context);
  final layout = PaneLayoutScope.maybeOf(context)?.layout;
  if (layout?.mode == PaneMode.split && scope?.pane.barToSideColumn == true) {
    final column = layout!.sideColumn!;
    final controls = [
      if (!scope!.detailRoot) const Size.square(AppSizes.barControl),
      const Size.square(AppSizes.barControl),
    ];
    return sideColumnSlots(column.upperSlot, controls).last;
  }
  return barControlFallbackRect(
    window: MediaQuery.sizeOf(context),
    padding: MediaQuery.paddingOf(context),
    rowHeight: context.theme.topBar.height,
  ).shift(scope?.pane.rect.topLeft ?? Offset.zero);
}

/// Where a bar's trailing control sits in a [window] whose safe area is
/// [padding]: the compact row's last seat, inside the right safe inset.
Rect barControlFallbackRect({
  required Size window,
  required EdgeInsets padding,
  required double rowHeight,
}) {
  const side = AppSizes.barControl;
  final left = window.width - padding.right - AppTopBar.edgeInset - side;
  final top = padding.top + (rowHeight - side) / 2;
  return Rect.fromLTWH(left, top, side, side);
}

/// The dropdown's own metrics.
const double _width = AppPopup.width;
const double _gap = AppSpacing.sm;

/// Opens a selection dropdown ANCHORED to [anchor] (the tapped control's
/// global rect) and resolves to the chosen index, or null if dismissed. The
/// same grows-out-of-the-trigger vocabulary as the app menu: a choice belongs
/// to the control that asked for it, below it when there is room, above when
/// not. Long lists scroll, opened AT the current selection.
Future<int?> showAppDropdown(
  BuildContext context, {
  required Rect anchor,
  required List<AppDropdownItem> items,
}) => showAnchoredPopup<int>(
  context,
  anchor: anchor,
  builder: (_) => _DropdownBody(anchor: anchor, items: items),
);

Rect dropdownRect({required Rect anchor, required Rect bounds, required double naturalHeight}) {
  final horizontalMargin = math.min(AppSpacing.md, bounds.width / 2);
  final verticalMargin = math.min(AppSpacing.md, bounds.height / 2);
  final available = Rect.fromLTRB(
    bounds.left + horizontalMargin,
    bounds.top + verticalMargin,
    bounds.right - horizontalMargin,
    bounds.bottom - verticalMargin,
  );
  final below = anchor.bottom + _gap;
  final above = anchor.top - _gap;
  final roomBelow = (available.bottom - below).clamp(0.0, available.height);
  final roomAbove = (above - available.top).clamp(0.0, available.height);
  final openBelow = roomBelow >= naturalHeight || roomBelow >= roomAbove;
  final height = naturalHeight.clamp(0.0, openBelow ? roomBelow : roomAbove);
  final width = _width.clamp(0.0, available.width);
  final top = (openBelow ? below : above - height).clamp(available.top, available.bottom - height);
  final left = (anchor.right - width).clamp(available.left, available.right - width);
  return Rect.fromLTWH(left, top, width, height);
}

class _DropdownBody extends StatefulWidget {
  const _DropdownBody({required this.anchor, required this.items});

  final Rect anchor;
  final List<AppDropdownItem> items;

  @override
  State<_DropdownBody> createState() => _DropdownBodyState();
}

class _DropdownBodyState extends State<_DropdownBody> {
  ScrollController? _scrollOrNull;
  ScrollController get _scroll => _scrollOrNull!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A long list opens AT the selection, not at the top of the alphabet.
    final selected = widget.items.indexWhere((item) => item.selected);
    _scrollOrNull ??= ScrollController(
      initialScrollOffset: selected <= 0 ? 0 : (selected - 2) * _rowHeight(context, widget.items),
    );
  }

  /// One row's height, exactly as [SelectableRow] lays it out: a dropdown's
  /// rows are all flagged or all plain.
  static double _rowHeight(BuildContext context, List<AppDropdownItem> items) =>
      selectableRowHeight(
        context.theme.settings,
        scaler: MediaQuery.textScalerOf(context),
        ambientHeight: DefaultTextStyle.of(context).style.height,
        tile: items.any((item) => item.flag != null),
        inner: duoInnerNow(context),
      );

  @override
  void dispose() {
    _scrollOrNull?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = popupBounds(context);
    final natural = widget.items.length * _rowHeight(context, widget.items) + AppSpacing.sm * 2;
    final rect = dropdownRect(anchor: widget.anchor, bounds: bounds, naturalHeight: natural);

    return Stack(
      children: [
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: PopupSurface(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  for (final (index, item) in widget.items.indexed)
                    SelectableRow(
                      label: item.label,
                      flag: item.flag,
                      selected: item.selected,
                      onTap: () => Navigator.of(context).pop(index),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
