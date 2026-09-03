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

  /// A group separator. The NATIVE menu draws a real divider between the groups
  /// it splits; the fallback menu drops it (item order is preserved and indices
  /// are unaffected, since it is simply not rendered). Carries nothing.
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
  /// fallback menu ignores it; selection lists there run through the app's
  /// own dropdown instead.
  final bool selected;

  /// Keeps the NATIVE menu presented when this item is selected - a toggle
  /// row likely to be tapped again in the same visit - with its checkmark
  /// refreshing in place. On native such a row's leading image IS its mark
  /// (a checkmark, or a spacer when off), so any [icon] it carries is
  /// discarded there. The fallback's surfaces are modal and still close.
  final bool keepsPresented;

  /// Nested choices. NATIVE menus render a real submenu whose children answer
  /// through [AppMenuButton.onSelectedId] (each needs an [id]); the fallback
  /// menu ignores children and fires the parent's index as a plain action, so
  /// the caller opens its own follow-up surface there. One level only.
  final List<AppMenuItem> children;
}

/// The menu's own metrics.
const double _menuWidth = 232;
const double _rowHeight = 44;
const double _menuGap = AppSpacing.sm;

/// Opens a menu ANCHORED to [anchor] (a global rect, usually the trigger's own
/// bounds) and resolves to the chosen index, or null if it was dismissed. It
/// grows out of the trigger rather than up from the bottom of the screen: a
/// menu belongs to the control that opened it.
Future<int?> showAppMenu(
  BuildContext context, {
  required Rect anchor,
  required List<AppMenuItem> items,
}) => showAnchoredPopup<int>(
  context,
  anchor: anchor,
  builder: (_) => _MenuBody(anchor: anchor, items: items),
);

class _MenuBody extends StatelessWidget {
  const _MenuBody({required this.anchor, required this.items});

  final Rect anchor;
  final List<AppMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    // Dividers are not rendered on the fallback (order is what matters here),
    // so only real rows count toward the menu's height.
    final rowCount = items.where((i) => !i.isDivider).length;
    final height = rowCount * _rowHeight + AppSpacing.sm * 2;

    // Below the trigger when there is room, above it when there is not.
    final below = anchor.bottom + _menuGap;
    final fits = below + height + insets.bottom + AppSpacing.md <= screen.height;
    final top = fits ? below : anchor.top - _menuGap - height;
    final left = (anchor.right - _menuWidth).clamp(
      AppSpacing.md,
      screen.width - _menuWidth - AppSpacing.md,
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top.clamp(insets.top + AppSpacing.md, screen.height - height),
          width: _menuWidth,
          child: PopupSurface(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, item) in items.indexed)
                    if (!item.isDivider)
                      _MenuRow(item: item, onTap: () => Navigator.of(context).pop(index)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});

  final AppMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // The native menu paints destructive rows red; the fallback must warn the
    // same way, or a pre-glass user meets an unmarked irreversible action.
    final color = item.destructive ? theme.danger : theme.text;
    final iconColor = item.destructive ? theme.danger : theme.textSecondary;
    return Touchable(
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
              if (item.iconBytes != null) ...[
                const SizedBox(width: AppSpacing.md),
                Image.memory(
                  item.iconBytes!,
                  width: 17,
                  height: 17,
                  color: iconColor,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ] else if (item.icon != null) ...[
                const SizedBox(width: AppSpacing.md),
                AppIcon(item.icon!, size: 17, color: iconColor),
              ],
            ],
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
    this.size = 44,
    this.iconSize = 20,
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
      items.every((item) => item.children.every((child) => child.id != null)),
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
        itemIconPointSize: AppType.callout.fontSize,
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
                        LiquidPopupButtonEntry(
                          value: '#${child.id ?? ''}',
                          label: child.label,
                          icon: _symbol(child.icon),
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
