import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/anchored_popup.dart';
import 'package:opentranscribe/view/widgets/glass_icon_button.dart';
import 'package:opentranscribe/view/widgets/side_column.dart';

enum PageBarPlacement { horizontal, vertical }

enum PagePaneRole { sidebar, detail, single }

PagePaneRole pagePaneRole({required PaneMode mode, required PaneTouch? touch}) =>
    mode != PaneMode.split
    ? PagePaneRole.single
    : touch == PaneTouch.journal
    ? PagePaneRole.sidebar
    : PagePaneRole.detail;

bool? pageBarCovered({required PagePaneRole role, required bool fullScreenCovered}) =>
    role == PagePaneRole.sidebar ? fullScreenCovered : null;

PageBarPlacement pageBarPlacement({
  required PaneLayout layout,
  required PagePaneRole role,
  required BarSide edge,
  required bool settled,
  PageBarPlacement previous = PageBarPlacement.horizontal,
}) {
  if (!settled) return previous;
  if (edge == BarSide.none || layout.sideColumn == null) return PageBarPlacement.horizontal;
  if (layout.mode == PaneMode.split && role == PagePaneRole.sidebar) {
    return PageBarPlacement.horizontal;
  }
  return PageBarPlacement.vertical;
}

class PageBarScope extends StatefulWidget {
  const PageBarScope({required this.child, super.key});

  final Widget child;

  static PageBarPlacement placementOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_PageBars>();
    if (scope == null) return PageBarPlacement.horizontal;
    final panes = PaneLayoutScope.of(context);
    final pane = PaneScope.maybeOf(context);
    final role = pagePaneRole(mode: panes.layout.mode, touch: pane?.touch);
    return scope.placements[role]!;
  }

  @override
  State<PageBarScope> createState() => _PageBarScopeState();
}

class _PageBarScopeState extends State<PageBarScope> {
  final _placements = <PagePaneRole, PageBarPlacement>{
    for (final role in PagePaneRole.values) role: PageBarPlacement.horizontal,
  };

  @override
  Widget build(BuildContext context) {
    final panes = PaneLayoutScope.of(context);
    for (final role in PagePaneRole.values) {
      _placements[role] = pageBarPlacement(
        layout: panes.layout,
        role: role,
        edge: panes.layout.sideColumn?.side ?? BarSide.none,
        settled: panes.settled,
        previous: _placements[role]!,
      );
    }
    return _PageBars(placements: Map.unmodifiable(_placements), child: widget.child);
  }
}

class _PageBars extends InheritedWidget {
  const _PageBars({required this.placements, required super.child});

  final Map<PagePaneRole, PageBarPlacement> placements;

  @override
  bool updateShouldNotify(_PageBars oldWidget) =>
      PagePaneRole.values.any((role) => placements[role] != oldWidget.placements[role]);
}

// The overlay clears the pane clip while retaining the page's inherited state.
class PageBarControls extends StatefulWidget {
  const PageBarControls({
    required this.controls,
    required this.vertical,
    required this.child,
    super.key,
  });

  final List<Widget> controls;
  final bool vertical;
  final Widget child;

  @override
  State<PageBarControls> createState() => _PageBarControlsState();
}

class _PageBarControlsState extends State<PageBarControls> {
  final _controller = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _controller.show();
  }

  @override
  Widget build(BuildContext context) {
    final active = ModalRoute.isCurrentOf(context) ?? false;
    final panes = PaneLayoutScope.of(context);
    final pane = PaneScope.maybeOf(context);
    final role = pagePaneRole(mode: panes.layout.mode, touch: pane?.touch);
    final visible = !(pane?.detailRoot == true && pane?.touch == null);
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) => _ColumnPageBar(
        controls: widget.vertical && active && visible ? widget.controls : const [],
      ),
      child: LiquidRouteVisibility(
        covered: pageBarCovered(role: role, fullScreenCovered: panes.covered),
        child: widget.child,
      ),
    );
  }
}

class _ColumnPageBar extends StatefulWidget {
  const _ColumnPageBar({required this.controls});

  final List<Widget> controls;

  @override
  State<_ColumnPageBar> createState() => _ColumnPageBarState();
}

class _ColumnPageBarState extends State<_ColumnPageBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final controls = widget.controls;
    final panes = PaneLayoutScope.of(context);
    final column = panes.layout.sideColumn;
    if (column == null || controls.isEmpty) return const SizedBox.shrink();
    final slots = columnBarSlots(column, controls.length);
    return MediaQuery(
      data: panes.media,
      child: Stack(
        children: [
          const SideColumnGround(window: true),
          for (final (index, rect) in slots.visible.indexed)
            Positioned.fromRect(rect: rect, child: controls[index]),
          if (slots.overflow != null)
            Positioned.fromRect(
              rect: slots.overflow!,
              child: AppGlassIconButton(
                icon: AppIcons.ellipsis,
                semanticLabel: AppLocalizations.of(context)!.menuButton,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ),
          if (_expanded && slots.overflow != null) ...[
            ModalBarrier(onDismiss: () => setState(() => _expanded = false)),
            Positioned.fromRect(
              rect: panes.layout.modal,
              child: SafeArea(
                child: Align(
                  alignment: column.side == BarSide.left ? Alignment.topLeft : Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: PopupSurface(
                      child: SingleChildScrollView(
                        child: _ColumnOverflow(controls: controls.sublist(slots.visible.length)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColumnOverflow extends StatelessWidget {
  const _ColumnOverflow({required this.controls});

  final List<Widget> controls;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final control in controls)
        Padding(padding: const EdgeInsets.all(AppSpacing.md), child: control),
    ],
  );
}
