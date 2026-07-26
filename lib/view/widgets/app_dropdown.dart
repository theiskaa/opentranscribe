import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// One choice in a dropdown: a flagged, selectable row (see [SelectableRow]).
class AppDropdownItem {
  const AppDropdownItem({required this.label, required this.flag, this.selected = false});

  final String label;
  final String flag;
  final bool selected;
}

/// The dropdown's own metrics. The row estimate mirrors [SelectableRow]'s
/// intrinsics (12px vertical padding around a 32px chip) for placement math;
/// actual layout stays intrinsic.
const double _width = 264;
const double _rowEstimate = 56;
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
}) {
  // One-shot read: this runs from tap handlers, where select is illegal.
  final motion = context.motionNow;
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: const Color(0x00000000),
    transitionDuration: motion.indicator,
    pageBuilder: (context, animation, secondaryAnimation) =>
        _DropdownBody(anchor: anchor, items: items),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: motion.indicatorCurve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          // Out of the trigger's near corner, like the menu.
          alignment: anchor.center.dx > MediaQuery.sizeOf(context).width / 2
              ? Alignment.topRight
              : Alignment.topLeft,
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _DropdownBody extends StatefulWidget {
  const _DropdownBody({required this.anchor, required this.items});

  final Rect anchor;
  final List<AppDropdownItem> items;

  @override
  State<_DropdownBody> createState() => _DropdownBodyState();
}

class _DropdownBodyState extends State<_DropdownBody> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    // A long list opens AT the selection, not at the top of the alphabet.
    final selected = widget.items.indexWhere((item) => item.selected);
    _scroll = ScrollController(
      initialScrollOffset: selected <= 0 ? 0 : (selected - 2) * _rowEstimate,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final screen = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);

    final natural = widget.items.length * _rowEstimate + AppSpacing.sm * 2;
    final below = widget.anchor.bottom + _gap;
    final roomBelow = screen.height - insets.bottom - AppSpacing.md - below;
    final roomAbove = widget.anchor.top - _gap - insets.top - AppSpacing.md;
    // Below when there is reasonable room, above when it is the better half;
    // either way the height caps to the room on that side.
    final openBelow = roomBelow >= natural || roomBelow >= roomAbove;
    final height = natural.clamp(0.0, openBelow ? roomBelow : roomAbove);
    final top = openBelow ? below : widget.anchor.top - _gap - height;
    final left = (widget.anchor.right - _width).clamp(
      AppSpacing.md,
      screen.width - _width - AppSpacing.md,
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: _width,
          height: height,
          child: DecoratedBox(
            decoration: SuperellipseDecoration(
              borderRadius: AppRadius.card,
              color: theme.surface,
              border: BorderSide(color: theme.surfaceBorder),
              shadows: [
                BoxShadow(
                  color: theme.shadow.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
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
