import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/anchored_popup.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

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
  return barControlFallbackRect(
    window: MediaQuery.sizeOf(context),
    padding: MediaQuery.paddingOf(context),
    rowHeight: context.theme.topBar.height,
  );
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
      );

  @override
  void dispose() {
    _scrollOrNull?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);

    final natural = widget.items.length * _rowHeight(context, widget.items) + AppSpacing.sm * 2;
    final below = widget.anchor.bottom + _gap;
    final roomBelow = screen.height - insets.bottom - AppSpacing.md - below;
    final roomAbove = widget.anchor.top - _gap - insets.top - AppSpacing.md;
    // Below when there is reasonable room, above when it is the better half;
    // either way the height caps to the room on that side.
    final openBelow = roomBelow >= natural || roomBelow >= roomAbove;
    final height = natural.clamp(0.0, openBelow ? roomBelow : roomAbove);
    final top = openBelow ? below : widget.anchor.top - _gap - height;
    final left = popupLeft(
      anchor: widget.anchor,
      width: _width,
      windowWidth: screen.width,
      padding: insets,
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: _width,
          height: height,
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
