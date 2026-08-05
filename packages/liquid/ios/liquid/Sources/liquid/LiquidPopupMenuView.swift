import Flutter
import UIKit

private final class LiquidCircularMenuButton: UIButton {
  override func layoutSubviews() {
    super.layoutSubviews()

    let diameter = min(bounds.width, bounds.height)
    if diameter > 0 {
      layer.cornerRadius = diameter / 2
      layer.cornerCurve = .continuous
      clipsToBounds = false
      layer.masksToBounds = false
    }
  }
}

final class LiquidPopupMenuView: LiquidNativeView {
  private let root: UIView
  private let button: LiquidCircularMenuButton
  private var buttonSize: CGFloat = 44
  private var buttonWidthConstraint: NSLayoutConstraint?
  private var buttonHeightConstraint: NSLayoutConstraint?
  private var edgeConstraints: [NSLayoutConstraint] = []
  private var items: [[String: Any]] = []
  private var buttonLabel: String?
  private var iconName: String?
  private var iconPointSize: CGFloat?

  /// Bare mode: no glass, no glyph, the button fills the host invisibly. Lets
  /// arbitrary Flutter content (a settings row) act as the trigger of a REAL
  /// UIMenu, which UIKit only presents from a native control.
  private var bare = false

  /// Point size for the ITEM icons inside the menu. Without an explicit symbol
  /// configuration UIKit renders a menu image at the symbol's own intrinsic
  /// size, which on iOS 26 is noticeably larger than the row's label; a
  /// configuration pins it to the type it sits beside.
  private var itemIconPointSize: CGFloat = 17

  init(
    registrar: FlutterPluginRegistrar,
    viewId: Int64,
    viewType: String,
    arguments: Any?
  ) {
    // Без всяких LiquidGlassBridge — всегда UIButton
    root = UIView(frame: .zero)
    root.backgroundColor = .clear
    root.clipsToBounds = false

    button = LiquidCircularMenuButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(button)

    buttonWidthConstraint = button.widthAnchor.constraint(equalToConstant: buttonSize)
    buttonHeightConstraint = button.heightAnchor.constraint(equalToConstant: buttonSize)

    NSLayoutConstraint.activate([
      button.centerXAnchor.constraint(equalTo: root.centerXAnchor),
      button.centerYAnchor.constraint(equalTo: root.centerYAnchor),
      buttonWidthConstraint!,
      buttonHeightConstraint!,
    ])

    super.init(
      registrar: registrar,
      viewId: viewId,
      viewType: viewType,
      rootView: root
    )

    apply(arguments as? [String: Any] ?? [:])
    configureAction()
  }

  override func update(with params: [String: Any]) {
    apply(params)
  }

  private func configureAction() {
    // “More”-поведение: по тапу — сразу меню
    button.showsMenuAsPrimaryAction = true
    button.changesSelectionAsPrimaryAction = false
  }

  private func apply(_ params: [String: Any]) {
    // Apply theme from Flutter to ensure consistent appearance
    applyUserInterfaceStyle(from: params)

    // Also apply to the button itself - UIMenu inherits its appearance from the presenting view
    if let isDark = params["isDark"] as? Bool {
      button.overrideUserInterfaceStyle = isDark ? .dark : .light
    } else if let isDarkNS = params["isDark"] as? NSNumber {
      button.overrideUserInterfaceStyle = isDarkNS.boolValue ? .dark : .light
    }

    items = params["items"] as? [[String: Any]] ?? []

    let wantsBare = boolValue(from: params, key: "bare") ?? false
    if wantsBare != bare {
      bare = wantsBare
      applyLayoutMode()
    }

    if let size = params["size"] as? Double {
      buttonSize = CGFloat(size)
      buttonWidthConstraint?.constant = buttonSize
      buttonHeightConstraint?.constant = buttonSize
      root.setNeedsLayout()
    }

    let enabled = params["enabled"] as? Bool ?? true
    let semantics = params["semanticLabel"] as? String
    buttonLabel = params["buttonLabel"] as? String
    iconName = params["icon"] as? String

    if let size = params["iconPointSize"] as? Double {
      iconPointSize = CGFloat(size)
    } else {
      iconPointSize = nil
    }

    if let size = params["itemIconPointSize"] as? Double {
      itemIconPointSize = CGFloat(size)
    }

    button.isEnabled = enabled
    button.isUserInteractionEnabled = enabled

    // Кнопка в основном иконка, label — для VoiceOver
    button.accessibilityLabel = semantics ?? buttonLabel

    configureButtonAppearance()
    // The menu SHELL is set once and never reassigned: replacing a control's
    // menu while it is presented dismisses it, which would defeat
    // keepsMenuPresented toggles and blink an open menu on any Flutter
    // update. The deferred element re-resolves from the live items each
    // time the menu is DISPLAYED; a menu held open never re-resolves, which
    // is why keeps-presented toggles repaint through refreshVisibleMenu
    // instead.
    if button.menu == nil {
      button.menu = UIMenu(children: [
        UIDeferredMenuElement.uncached { [weak self] completion in
          completion(self?.buildMenuElements() ?? [])
        }
      ])
    }
  }

  /// Bare pins the button to the host's edges; the sized circle centers it.
  private func applyLayoutMode() {
    if edgeConstraints.isEmpty {
      edgeConstraints = [
        button.leadingAnchor.constraint(equalTo: root.leadingAnchor),
        button.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        button.topAnchor.constraint(equalTo: root.topAnchor),
        button.bottomAnchor.constraint(equalTo: root.bottomAnchor),
      ]
    }
    if bare {
      buttonWidthConstraint?.isActive = false
      buttonHeightConstraint?.isActive = false
      NSLayoutConstraint.activate(edgeConstraints)
    } else {
      NSLayoutConstraint.deactivate(edgeConstraints)
      buttonWidthConstraint?.isActive = true
      buttonHeightConstraint?.isActive = true
    }
    root.setNeedsLayout()
  }

  private func configureButtonAppearance() {
    if bare {
      // Invisible on purpose: the Flutter row underneath is the visible
      // control, and the menu itself is the feedback.
      var config = UIButton.Configuration.plain()
      config.image = nil
      config.title = nil
      config.baseBackgroundColor = .clear
      button.configuration = config
      button.backgroundColor = .clear
      button.tintColor = .clear
      return
    }
    let symbolName = iconName ?? "ellipsis"
    let pointSize = iconPointSize ?? 17
    let symbolConfig = UIImage.SymbolConfiguration(
      pointSize: pointSize,
      weight: .semibold
    )
    let image = UIImage(systemName: symbolName, withConfiguration: symbolConfig)

    button.contentHorizontalAlignment = .center
    button.contentVerticalAlignment = .center

    if #available(iOS 26.0, *) {
      // Та самая стеклянная круглая кнопка (Liquid Glass)
      var config = UIButton.Configuration.glass()
      config.image = image
      config.preferredSymbolConfigurationForImage = symbolConfig
      config.title = nil
      config.contentInsets = NSDirectionalEdgeInsets(
        top: 8, leading: 8, bottom: 8, trailing: 8
      )
      config.cornerStyle = .capsule
      button.configuration = config
    } else {
      // Старый стиль – tinted pill
      var config = UIButton.Configuration.tinted()
      config.image = image
      config.preferredSymbolConfigurationForImage = symbolConfig
      config.title = nil
      config.contentInsets = NSDirectionalEdgeInsets(
        top: 10, leading: 10, bottom: 10, trailing: 10
      )
      config.cornerStyle = .capsule
      button.configuration = config
      button.tintColor = .label
    }

    // На случай, если конфигурация не до конца скруглит
    button.layer.cornerCurve = .continuous
  }

  private func buildMenuElements() -> [UIMenuElement] {
    // Group items by dividers to create visual separation
    let groups = groupItemsByDividers(items)

    if groups.count == 1 {
      // No dividers, just build children directly
      return groups[0].compactMap(buildMenuElement)
    }

    // Multiple groups - wrap each in an inline menu for visual separation
    var menuChildren: [UIMenuElement] = []
    for (index, group) in groups.enumerated() {
      let groupElements = group.compactMap(buildMenuElement)
      if !groupElements.isEmpty {
        let inlineMenu = UIMenu(
          title: "",
          identifier: UIMenu.Identifier("liquid.group.\(index)"),
          options: .displayInline,
          children: groupElements
        )
        menuChildren.append(inlineMenu)
      }
    }
    return menuChildren
  }

  private func isDivider(_ item: [String: Any]) -> Bool {
    // Flutter passes booleans as NSNumber through platform channels
    if let nsNumber = item["isDivider"] as? NSNumber {
      return nsNumber.boolValue
    }
    return item["isDivider"] as? Bool ?? false
  }

  private func groupItemsByDividers(_ items: [[String: Any]]) -> [[[String: Any]]] {
    var groups: [[[String: Any]]] = []
    var currentGroup: [[String: Any]] = []

    for item in items {
      if isDivider(item) {
        if !currentGroup.isEmpty {
          groups.append(currentGroup)
          currentGroup = []
        }
      } else {
        currentGroup.append(item)
      }
    }

    if !currentGroup.isEmpty {
      groups.append(currentGroup)
    }

    return groups.isEmpty ? [[]] : groups
  }

  /// Decodes raw image bytes and returns them as a template scaled to a square
  /// of [pointSize], so a brand logo tints like a symbol and matches the row
  /// type rather than rendering at its own intrinsic size.
  private func templateImage(data: Data, pointSize: CGFloat) -> UIImage? {
    guard let raw = UIImage(data: data), raw.size.width > 0, raw.size.height > 0 else {
      return nil
    }
    let side = max(pointSize, 1)
    let canvas = CGSize(width: side, height: side)
    let scaled = UIGraphicsImageRenderer(size: canvas).image { context in
      // High-quality downscale from the large master, so the mark stays crisp
      // at the row's small point size on every display scale.
      context.cgContext.interpolationQuality = .high
      // Aspect-fit and center: the mark is never stretched or clipped, whatever
      // the source's proportions, and it can never render larger than the row.
      let scale = min(side / raw.size.width, side / raw.size.height)
      let w = raw.size.width * scale
      let h = raw.size.height * scale
      raw.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
    }
    return scaled.withRenderingMode(.alwaysTemplate)
  }

  private func buildMenuElement(from item: [String: Any]) -> UIMenuElement? {
    // Skip dividers - they are handled by grouping
    if isDivider(item) {
      return nil
    }

    let title = item["label"] as? String ?? ""
    let iconName = item["icon"] as? String
    let iconBytes = item["iconBytes"] as? FlutterStandardTypedData
    let itemSymbolConfig = UIImage.SymbolConfiguration(
      pointSize: itemIconPointSize, weight: .regular, scale: .medium)
    // A raster mark (a brand logo with no SF Symbol) arrives as bytes and wins
    // over a symbol; it is drawn as a template at the row's type size so it sits
    // like a symbol beside the label.
    var image: UIImage?
    if let iconBytes {
      image = templateImage(data: iconBytes.data, pointSize: itemIconPointSize)
    } else {
      image = iconName.flatMap { UIImage(systemName: $0, withConfiguration: itemSymbolConfig) }
    }
    let isDestructive = boolValue(from: item, key: "isDestructive") ?? false

    if let nested = item["children"] as? [[String: Any]], !nested.isEmpty {
      let submenuChildren = nested.compactMap(buildMenuElement)
      return UIMenu(
        title: title,
        image: image,
        identifier: (item["value"] as? String).map { UIMenu.Identifier("liquid.menu.\($0)") },
        options: [],
        children: submenuChildren)
    }

    let value = item["value"] as? String
    let isSelected = boolValue(from: item, key: "isSelected") ?? false
    let keeps = boolValue(from: item, key: "keepsPresented") ?? false
    var attributes: UIMenuElement.Attributes = isDestructive ? [.destructive] : []
    if keeps, #available(iOS 16.0, *) {
      attributes.insert(.keepsMenuPresented)
      // A keeps-presented toggle wears its mark as an IMAGE, never UIMenu
      // state: only a structural update repaints a held-open menu, and a
      // re-laid level factors a state column into its header that the first
      // presentation did not - the sideways header jump. Image-column
      // layout is identical in both passes, so the checkmark (a clear
      // spacer when off, keeping the titles aligned) can change freely.
      // Sized and weighted like the native state tick, not like the icon
      // column: a full-size regular symbol reads as a giant checkmark. The
      // spacer keeps the full column width, so the smaller tick centers on
      // the same grid.
      let tickConfig = UIImage.SymbolConfiguration(
        pointSize: itemIconPointSize * 0.7, weight: .semibold)
      image = isSelected
        ? UIImage(systemName: "checkmark", withConfiguration: tickConfig)
        : Self.clearSpacer(pointSize: itemIconPointSize)
    }
    let action = UIAction(
      title: title,
      image: image,
      identifier: value.map { UIAction.Identifier("liquid.action.\($0)") },
      discoverabilityTitle: nil,
      attributes: attributes,
      state: !keeps && isSelected ? .on : .off
    ) { [weak self] _ in
      guard let self, let value else { return }
      if keeps {
        // The menu stays up, so the flipped state must reach the PRESENTED
        // tree itself: deferred re-resolution does not run while a menu is
        // held open, and updateVisibleMenu is the one channel UIKit gives
        // for rewriting it in place. No round trip waited.
        self.flipSelected(value: value)
        self.refreshVisibleMenu()
      }
      // Deferred a runloop so the callback never lands while UIKit is mid
      // dismissal or mid visible-menu update.
      DispatchQueue.main.async {
        self.channel.invokeMethod("onSelected", arguments: value)
      }
    }
    return action
  }

  /// A transparent square at the symbol size: the unchecked toggle's image,
  /// so checked and unchecked rows share one title column.
  private static func clearSpacer(pointSize: CGFloat) -> UIImage {
    let side = max(pointSize, 1)
    return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in }
  }

  /// Repaints the held-open toggle list: only a structural update repaints
  /// a presented menu (element mutation is ignored), so the matched level's
  /// children are replaced - and ONLY that level's; every other level is
  /// handed back untouched so nothing else re-lays. Keeps-presented toggles
  /// must therefore live under an identified submenu: the presented root's
  /// identifier is auto-generated and never matches a rebuilt one, so a
  /// top-level toggle would flip its stored state without repainting.
  private func refreshVisibleMenu() {
    guard let interaction = button.contextMenuInteraction else { return }
    let rebuiltRoot = UIMenu(children: buildMenuElements())
    interaction.updateVisibleMenu { visible in
      guard let match = Self.menu(with: visible.identifier, in: rebuiltRoot) else {
        return visible
      }
      return visible.replacingChildren(match.children)
    }
  }

  private static func menu(with identifier: UIMenu.Identifier, in tree: UIMenu) -> UIMenu? {
    if tree.identifier == identifier { return tree }
    for child in tree.children {
      if let sub = child as? UIMenu, let found = menu(with: identifier, in: sub) {
        return found
      }
    }
    return nil
  }

  /// Flips [value]'s selection in the stored items, top level or one level
  /// deep, mirroring the toggle the action just asked Flutter to make.
  private func flipSelected(value: String) {
    for i in items.indices {
      if items[i]["value"] as? String == value {
        items[i]["isSelected"] = !(boolValue(from: items[i], key: "isSelected") ?? false)
        return
      }
      if var nested = items[i]["children"] as? [[String: Any]] {
        for j in nested.indices where nested[j]["value"] as? String == value {
          nested[j]["isSelected"] = !(boolValue(from: nested[j], key: "isSelected") ?? false)
          items[i]["children"] = nested
          return
        }
      }
    }
  }
}
