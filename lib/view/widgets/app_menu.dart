import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/core/utils/platform_caps.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/anchored_popup.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// One choice in a menu.
class AppMenuItem {
  const AppMenuItem({
    required this.label,
    this.id,
    this.icon,
    this.iconBytes,
    this.destructive = false,
    this.selected = false,
    this.keepsPresented = false,
    this.children = const [],
  }) : isDivider = false;

  /// A group separator, drawn between the groups it splits, at the top level
  /// and inside a submenu, by both menus (see [appMenuLayout]). Indices are
  /// unaffected. Carries nothing.
  const AppMenuItem.divider()
    : label = '',
      id = null,
      icon = null,
      iconBytes = null,
      destructive = false,
      selected = false,
      keepsPresented = false,
      children = const [],
      isDivider = true;

  final String label;

  /// Stable identity for selection, answered via [AppMenuButton.onSelectedId].
  /// Positional indices go stale when the item list rebuilds under an OPEN
  /// native menu (the menu shows the old snapshot, the closure resolves the
  /// new list); an id names the choice itself. Submenu children need one.
  final String? id;

  final IconData? icon;

  /// Raw image bytes (PNG) for a mark with no SF Symbol (a brand logo). iOS
  /// renders them as a template beside the label; the fallback tints them
  /// through [Image.memory]. Take precedence over [icon] where both are set.
  final Uint8List? iconBytes;

  /// Whether this entry is a group separator; see [AppMenuItem.divider].
  final bool isDivider;

  /// Marks what cannot be undone. It carries no colour: the app has none, so
  /// the confirm that follows does the warning.
  final bool destructive;

  /// Renders a selection checkmark on the NATIVE menu (UIMenu state). The
  /// fallback menu shows it only on a [keepsPresented] row; selection lists
  /// there run through the app's own dropdown instead.
  final bool selected;

  /// Keeps the NATIVE menu presented when this item is selected - a toggle
  /// row likely to be tapped again in the same visit - with its checkmark
  /// refreshing in place. On native such a row's leading image IS its mark
  /// (a checkmark, or a spacer when off), so any [icon] it carries is
  /// discarded there. The fallback marks it the same way, and stays open on
  /// it only when [showAppMenu] is given an `onToggle`.
  final bool keepsPresented;

  /// Nested choices. NATIVE menus render a real submenu whose children answer
  /// through [AppMenuButton.onSelectedId] (each needs an [id]); the fallback
  /// menu ignores children and fires the parent as a plain action (its id, or
  /// its index without one), so the caller opens its own follow-up surface
  /// there. One level only.
  final List<AppMenuItem> children;
}

/// The menu's own metrics.
const double _menuWidth = AppPopup.width;
const double _rowHeight = AppSizes.minTarget;
const double _menuGap = AppSpacing.sm;
const double _dividerHeight = AppSpacing.sm;

/// A row's glyph: the native menu's size (its label's), in a fixed column.
final double _iconSize = AppType.callout.fontSize!;
const double _iconSlot = AppSpacing.xxl;

/// Opens a menu ANCHORED to [anchor] (a global rect, usually the trigger's own
/// bounds) and resolves to the chosen index, or null if it was dismissed. It
/// grows out of the trigger rather than up from the bottom of the screen: a
/// menu belongs to the control that opened it.
///
/// With [onToggle], a [AppMenuItem.keepsPresented] row flips its check in
/// place and reports its index there, leaving the menu open as the native one
/// stays; the menu shows the flip itself, never waiting on the caller.
Future<int?> showAppMenu(
  BuildContext context, {
  required Rect anchor,
  required List<AppMenuItem> items,
  ValueChanged<int>? onToggle,
}) => showAnchoredPopup<int>(
  context,
  anchor: anchor,
  builder: (_) => _MenuBody(anchor: anchor, items: items, onToggle: onToggle),
);

/// The drawn menu's layout: the dividers that draw, by index, and the menu's
/// height. A divider draws only between two non-empty groups, as the native
/// menu groups them, so a leading, trailing or doubled one adds nothing.
({Set<int> dividers, double height}) appMenuLayout(List<AppMenuItem> items) {
  final dividers = <int>{};
  var rows = 0;
  int? pending;
  var groupHasRows = false;
  for (final (index, item) in items.indexed) {
    if (item.isDivider) {
      if (groupHasRows) pending ??= index;
      groupHasRows = false;
      continue;
    }
    if (pending != null) dividers.add(pending);
    pending = null;
    groupHasRows = true;
    rows++;
  }
  return (
    dividers: dividers,
    height: rows * _rowHeight + dividers.length * _dividerHeight + AppSpacing.sm * 2,
  );
}

class _MenuBody extends StatefulWidget {
  const _MenuBody({required this.anchor, required this.items, required this.onToggle});

  final Rect anchor;
  final List<AppMenuItem> items;
  final ValueChanged<int>? onToggle;

  @override
  State<_MenuBody> createState() => _MenuBodyState();
}

class _MenuBodyState extends State<_MenuBody> {
  /// The toggle rows flipped since the menu opened, against the snapshot it
  /// shows.
  final Set<int> _flipped = {};

  void _tap(int index) {
    final toggle = widget.onToggle;
    if (toggle != null && widget.items[index].keepsPresented) {
      setState(() {
        if (!_flipped.remove(index)) _flipped.add(index);
      });
      toggle(index);
      return;
    }
    Navigator.of(context).pop(index);
  }

  @override
  Widget build(BuildContext context) {
    final anchor = widget.anchor;
    final items = widget.items;
    final screen = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final bounds = popupBounds(context);
    final width = _menuWidth.clamp(0.0, bounds.width - AppSpacing.md * 2);
    final (:dividers, :height) = appMenuLayout(items);

    // Below the trigger when there is room, above it when there is not.
    final below = anchor.bottom + _menuGap;
    final fits = below + height + AppSpacing.md <= bounds.bottom;
    final top = fits ? below : anchor.top - _menuGap - height;
    final left = popupLeft(
      anchor: anchor,
      width: width,
      modal: bounds,
      windowWidth: screen.width,
      padding: insets,
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top.clamp(
            bounds.top + AppSpacing.md,
            (bounds.bottom - height).clamp(bounds.top + AppSpacing.md, bounds.bottom),
          ),
          width: width,
          height: height.clamp(0.0, bounds.height - AppSpacing.md * 2),
          child: PopupSurface(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (index, item) in items.indexed)
                      if (!item.isDivider)
                        _MenuRow(
                          item: item,
                          checked: item.selected != _flipped.contains(index),
                          onTap: () => _tap(index),
                        )
                      else if (dividers.contains(index))
                        const _MenuDivider(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A drawn divider: a hairline centred in its own band.
class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _dividerHeight,
      child: Center(child: Container(height: 1, color: context.theme.hairline)),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.checked, required this.onTap});

  final AppMenuItem item;

  /// A toggle row's state as the menu shows it; read only on such a row.
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // The native menu paints destructive rows red; the fallback must warn the
    // same way, or a pre-glass user meets an unmarked irreversible action.
    final color = item.destructive ? theme.danger : theme.text;
    final iconColor = item.destructive ? theme.danger : theme.textSecondary;
    return Semantics(
      checked: item.keepsPresented ? checked : null,
      child: Touchable(
        onTap: () {
          if (item.destructive) {
            Haptics.medium();
          } else {
            Haptics.selection();
          }
          onTap();
        },
        child: SizedBox(
          height: _rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(item.label, style: AppType.callout.copyWith(color: color)),
                ),
                // A toggle's mark is its state, as on native: a check, or the
                // bare slot when off.
                if (item.keepsPresented) ...[
                  const SizedBox(width: AppSpacing.md),
                  SizedBox.square(
                    dimension: _iconSlot,
                    child: Center(
                      child: checked
                          ? AppIcon(AppIcons.checkmark, size: AppIconSize.accessory, color: color)
                          : null,
                    ),
                  ),
                ] else if (item.iconBytes != null || item.icon != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  // A fixed slot, so glyphs of different widths share one column.
                  SizedBox.square(
                    dimension: _iconSlot,
                    child: Center(
                      child: item.iconBytes != null
                          ? Image.memory(
                              item.iconBytes!,
                              width: _iconSize,
                              height: _iconSize,
                              color: iconColor,
                              colorBlendMode: BlendMode.srcIn,
                            )
                          : AppIcon(item.icon!, size: _iconSize, color: iconColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bar control that owns a menu: the NATIVE popup button on iOS 26 (a real
/// UIMenu under a glass circle) and the app's own circle plus [showAppMenu]
/// everywhere else, so the behaviour is the same wherever it runs.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({
    required this.icon,
    required this.items,
    this.onSelected,
    this.onSelectedId,
    this.size = AppSizes.barControl,
    this.iconSize = AppIconSize.bar,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final List<AppMenuItem> items;

  /// What VoiceOver calls the button; null reads as the generic "More".
  final String? semanticLabel;

  /// Fired with the tapped item's position, for menus that answer by index.
  /// A menu whose every item carries an id answers through [onSelectedId]
  /// alone and leaves this null.
  final ValueChanged<int>? onSelected;

  /// Fired for items carrying an [AppMenuItem.id] (including native submenu
  /// children, which the fallback folds into the parent's plain action).
  final ValueChanged<String>? onSelectedId;

  final double size;
  final double iconSize;
  final Color? color;

  /// The SF Symbol name for an optional icon, or null when the row has none.
  static String? _symbol(IconData? icon) => icon == null ? null : AppIcons.sfSymbolName(icon);

  @override
  Widget build(BuildContext context) {
    assert(
      items.every((item) => item.children.every((child) => child.isDivider || child.id != null)),
      'Submenu children answer through ids; id-less ones collide on one value.',
    );
    final label = semanticLabel ?? AppLocalizations.of(context)!.menuButton;
    if (PlatformCaps.nativeGlass) {
      // The native menu answers with an entry's VALUE, not its position, so
      // positions are carried across as values ('i', or 'i.j' inside a
      // submenu) and handed back to the same callbacks the fallback uses.
      return LiquidPopupButton(
        icon: AppIcons.sfSymbolName(icon),
        iconPointSize: iconSize,
        // Sized to the row's own label, not to the symbol's intrinsic size,
        // which UIKit otherwise draws far larger than the words beside it.
        itemIconPointSize: _iconSize,
        // isDark keeps the glass and its menu in step with the chosen theme
        // family, not just the system appearance.
        isDark: context.theme.brightness == Brightness.dark,
        size: size,
        semanticLabel: label,
        items: [
          for (final (i, item) in items.indexed)
            item.isDivider
                ? const LiquidPopupButtonEntry.divider()
                : item.children.isEmpty
                ? LiquidPopupButtonEntry(
                    // An id when the item has one ('#' prefix keeps it apart
                    // from bare indices), else its position.
                    value: item.id == null ? '$i' : '#${item.id}',
                    label: item.label,
                    icon: _symbol(item.icon),
                    iconBytes: item.iconBytes,
                    isDestructive: item.destructive,
                    isSelected: item.selected,
                    keepsPresented: item.keepsPresented,
                  )
                : LiquidPopupButtonEntry(
                    // The parent never fires; its value's one job is the
                    // STABLE identifier the keeps-presented refresh matches
                    // the open submenu by, so the id beats the position.
                    value: item.id == null ? '$i' : '#${item.id}',
                    label: item.label,
                    icon: _symbol(item.icon),
                    children: [
                      for (final child in item.children)
                        child.isDivider
                            ? const LiquidPopupButtonEntry.divider()
                            : LiquidPopupButtonEntry(
                                value: '#${child.id ?? ''}',
                                label: child.label,
                                icon: _symbol(child.icon),
                                iconBytes: child.iconBytes,
                                isDestructive: child.destructive,
                                isSelected: child.selected,
                                keepsPresented: child.keepsPresented,
                              ),
                    ],
                  ),
        ],
        onSelected: (value) {
          if (value.startsWith('#')) {
            final id = value.substring(1);
            if (id.isNotEmpty) onSelectedId?.call(id);
            return;
          }
          final index = int.tryParse(value);
          if (index != null) onSelected?.call(index);
        },
      );
    }
    return _MenuTrigger(
      icon: icon,
      items: items,
      onSelected: onSelected,
      onSelectedId: onSelectedId,
      size: size,
      iconSize: iconSize,
      color: color,
      semanticLabel: label,
    );
  }
}

/// The non-native trigger. Stateful only to hold its own element, which is how
/// the menu learns where to grow from.
class _MenuTrigger extends StatefulWidget {
  const _MenuTrigger({
    required this.icon,
    required this.items,
    required this.onSelected,
    required this.onSelectedId,
    required this.size,
    required this.iconSize,
    required this.color,
    required this.semanticLabel,
  });

  final IconData icon;
  final List<AppMenuItem> items;
  final ValueChanged<int>? onSelected;
  final ValueChanged<String>? onSelectedId;
  final double size;
  final double iconSize;
  final Color? color;
  final String semanticLabel;

  @override
  State<_MenuTrigger> createState() => _MenuTriggerState();
}

class _MenuTriggerState extends State<_MenuTrigger> {
  Future<void> _open() async {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final origin = box.localToGlobal(Offset.zero);
    // The dialog displays this snapshot for its whole life while the route
    // below keeps rebuilding, so the answer must resolve against the SAME
    // list: the row the user tapped is the row they saw, not whatever a
    // rebuild put at that position meanwhile. The callbacks themselves are
    // read fresh off the widget, so handlers still see current state.
    final items = widget.items;
    final index = await showAppMenu(context, anchor: origin & box.size, items: items);
    if (index == null || index < 0 || index >= items.length) return;
    if (!mounted) return;
    final id = items[index].id;
    if (id != null) {
      widget.onSelectedId?.call(id);
      return;
    }
    widget.onSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: widget.icon,
      onTap: _open,
      size: widget.size,
      iconSize: widget.iconSize,
      foreground: widget.color,
      semanticLabel: widget.semanticLabel,
    );
  }
}
