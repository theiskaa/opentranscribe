import 'package:flutter/cupertino.dart' show CupertinoTheme, CupertinoThemeData;
import 'package:flutter/material.dart' show AdaptiveTextSelectionToolbar, SelectionArea;
import 'package:flutter/widgets.dart';

/// Marks a reading region as selectable, so its prose selects and copies with
/// the platform's own handles and menu. [SelectionArea] lives in material.dart;
/// its colors are set in [SelectionTheme], not here, because the handles and
/// menu render in the app's root overlay.
///
/// Wrap the whole scrollable reading region, not each `Text`: a [SelectableRegion]
/// only clears its selection on a tap that lands INSIDE it, so a region hugging
/// the text can never be dismissed by tapping the surrounding page.
///
/// Pass a [focusNode] to clear the selection from outside the region: a
/// [SelectableRegion] drops its selection when its focus node loses focus, so an
/// owner can `focusNode.unfocus()` to dismiss a lingering selection before an
/// action that would otherwise capture it.
class SelectableProse extends StatelessWidget {
  const SelectableProse({required this.child, this.focusNode, super.key});

  final Widget child;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) =>
      SelectionArea(focusNode: focusNode, contextMenuBuilder: _contextMenu, child: child);

  static Widget _contextMenu(BuildContext context, SelectableRegionState state) =>
      AdaptiveTextSelectionToolbar.buttonItems(
        anchors: state.contextMenuAnchors,
        buttonItems: copyDismissesSelection(state.contextMenuButtonItems, state.clearSelection),
      );
}

/// Rebuilds toolbar [items] so Copy also clears the selection after it runs.
/// A [SelectableRegion] clears the selection on copy on Android and desktop
/// but deliberately leaves it standing on iOS and macOS; native iOS dismisses
/// it on copy, so this restores that, leaving every other action as it was.
@visibleForTesting
List<ContextMenuButtonItem> copyDismissesSelection(
  List<ContextMenuButtonItem> items,
  VoidCallback clearSelection,
) => [
  for (final item in items)
    if (item.type == ContextMenuButtonType.copy && item.onPressed != null)
      ContextMenuButtonItem(
        type: item.type,
        label: item.label,
        onPressed: () {
          item.onPressed!();
          clearSelection();
        },
      )
    else
      item,
];

/// Tints the platform selection handles, caret, and toolbar from the theme.
/// Must wrap the app above the router's navigator (see App.build): the selection
/// UI renders in the root overlay and reads its theme from there, so anywhere
/// lower leaves the handles system blue.
class SelectionTheme extends StatelessWidget {
  const SelectionTheme({
    required this.accent,
    required this.brightness,
    required this.child,
    super.key,
  });

  final Color accent;
  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      // selectionHandleColor does not derive from primaryColor; brightness drives
      // the copy toolbar's light/dark background.
      data: CupertinoThemeData(
        brightness: brightness,
        primaryColor: accent,
        selectionHandleColor: accent,
      ),
      child: DefaultSelectionStyle(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.25),
        child: child,
      ),
    );
  }
}
