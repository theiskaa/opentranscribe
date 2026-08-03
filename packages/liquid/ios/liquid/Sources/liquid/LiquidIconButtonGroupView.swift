import Flutter
import UIKit

/// A native pill container that groups multiple icon buttons into a single
/// glass-material surface.
///
/// The pill is deliberately NOT a `UIToolbar`. A toolbar drags in the whole
/// adaptive bar stack (`_UIBarBackground`, scroll-edge machinery) whose
/// backdrop re-renders on every frame while Flutter content scrolls beneath
/// the platform view — measured as persistent scroll jank wherever the group
/// sat in a `LunaSliverAppBar`. Instead the pill is a single
/// `UIVisualEffectView` — `UIGlassEffect` on iOS 26+, `.systemThinMaterial`
/// blur earlier — with plain `UIButton`s inside: the same lightweight
/// construction as `LiquidIconButtonView`, which scrolls jank-free.
final class LiquidIconButtonGroupView: LiquidNativeView {
  private var pill: UIVisualEffectView?
  private var stackView: UIStackView?
  private var buttonViews: [UIView] = []

  init(registrar: FlutterPluginRegistrar, viewId: Int64, arguments: Any?) {
    let root = UIView()
    root.backgroundColor = .clear
    root.clipsToBounds = false

    super.init(
      registrar: registrar,
      viewId: viewId,
      viewType: "liquid_icon_button_group",
      rootView: root
    )

    apply(arguments as? [String: Any] ?? [:])
  }

  override func update(with params: [String: Any]) {
    apply(params)
  }

  // MARK: - Apply

  private func apply(_ params: [String: Any]) {
    applyUserInterfaceStyle(from: params)

    let height = params["height"] as? CGFloat ?? 44.0
    let isDark = params["isDark"] as? Bool
    let iconPointSize = params["iconPointSize"] as? Double ?? 17.0
    guard let rawItems = params["items"] as? [[String: Any]] else { return }

    applyPill(rawItems: rawItems, height: height, iconPointSize: CGFloat(iconPointSize), isDark: isDark)
  }

  // MARK: - Glass pill

  private func applyPill(
    rawItems: [[String: Any]],
    height: CGFloat,
    iconPointSize: CGFloat,
    isDark: Bool?
  ) {
    // Clear existing buttons.
    stackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
    buttonViews.removeAll()

    let radius = height / 2.0

    // Create the pill if needed.
    let blur: UIVisualEffectView
    if let existing = pill {
      blur = existing
    } else {
      let effect: UIVisualEffect
      if #available(iOS 26.0, *) {
        effect = UIGlassEffect()
      } else {
        effect = UIBlurEffect(style: .systemThinMaterial)
      }
      blur = UIVisualEffectView(effect: effect)
      blur.translatesAutoresizingMaskIntoConstraints = false
      blur.clipsToBounds = true

      let stack = UIStackView()
      stack.axis = .horizontal
      stack.distribution = .fill
      stack.alignment = .fill
      stack.spacing = 0
      stack.translatesAutoresizingMaskIntoConstraints = false
      blur.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
        stack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
        stack.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
        stack.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),
      ])

      rootView.addSubview(blur)
      NSLayoutConstraint.activate([
        blur.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
        blur.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        blur.topAnchor.constraint(equalTo: rootView.topAnchor),
        blur.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
      ])

      pill = blur
      stackView = stack
    }

    if #available(iOS 26.0, *) {
      // The capsule must be the glass material's own shape, not a layer mask:
      // when a native UIMenu presented from the pill dismisses, UIKit restores
      // the view by re-evaluating the glass, and a mask-only radius comes back
      // as a square that slowly morphs into shape. No border either — the
      // glass draws its own rim highlight.
      blur.cornerConfiguration = .capsule()
    } else {
      blur.layer.cornerRadius = radius
      blur.layer.cornerCurve = .continuous
      blur.layer.borderColor = UIColor.separator.withAlphaComponent(0.18).cgColor
      blur.layer.borderWidth = 0.5
    }

    guard let stack = stackView else { return }

    if let isDark {
      blur.overrideUserInterfaceStyle = isDark ? .dark : .light
    }

    // First pass: build and add all views to the stack (establishes common ancestor).
    for (index, item) in rawItems.enumerated() {
      let type = item["type"] as? String ?? "action"
      let iconName = item["icon"] as? String ?? "circle"
      let enabled = boolValue(from: item, key: "enabled") ?? true

      if index > 0 {
        stack.addArrangedSubview(makeSeparator(height: height))
      }

      let buttonView: UIView
      if type == "menu" {
        let menuItemsRaw = item["items"] as? [[String: Any]] ?? []
        buttonView = makeMenuButton(
          icon: iconName,
          enabled: enabled,
          iconPointSize: iconPointSize,
          menuItems: menuItemsRaw,
          isDark: isDark,
          index: index
        )
      } else {
        buttonView = makeActionButton(
          icon: iconName,
          enabled: enabled,
          iconPointSize: iconPointSize,
          index: index
        )
      }

      stack.addArrangedSubview(buttonView)
      buttonViews.append(buttonView)
    }

    // Second pass: equal-width constraints (buttons now share stack as ancestor).
    if buttonViews.count > 1 {
      let first = buttonViews[0]
      for bv in buttonViews.dropFirst() {
        bv.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true
      }
    }
  }

  // MARK: - Button factories

  private func makeActionButton(
    icon: String,
    enabled: Bool,
    iconPointSize: CGFloat,
    index: Int
  ) -> UIView {
    let button = makeBaseButton(icon: icon, enabled: enabled, iconPointSize: iconPointSize)
    let action = UIAction { [weak self] _ in
      self?.channel.invokeMethod("onTap_\(index)", arguments: nil)
    }
    button.addAction(action, for: .touchUpInside)
    return button
  }

  private func makeMenuButton(
    icon: String,
    enabled: Bool,
    iconPointSize: CGFloat,
    menuItems: [[String: Any]],
    isDark: Bool?,
    index: Int
  ) -> UIView {
    let button = makeBaseButton(icon: icon, enabled: enabled, iconPointSize: iconPointSize)
    button.showsMenuAsPrimaryAction = true
    if let isDark { button.overrideUserInterfaceStyle = isDark ? .dark : .light }
    button.menu = buildMenu(from: menuItems, index: index)
    return button
  }

  private func makeBaseButton(icon: String, enabled: Bool, iconPointSize: CGFloat) -> UIButton {
    let symbolConfig = UIImage.SymbolConfiguration(pointSize: iconPointSize, weight: .semibold)
    let image = UIImage(systemName: icon, withConfiguration: symbolConfig)

    let button = UIButton(type: .system)
    button.isEnabled = enabled
    button.translatesAutoresizingMaskIntoConstraints = false

    var config = UIButton.Configuration.plain()
    config.image = image
    config.preferredSymbolConfigurationForImage = symbolConfig
    config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
    button.configuration = config
    return button
  }

  // MARK: - Separator

  private func makeSeparator(height: CGFloat) -> UIView {
    let wrapper = UIView()
    wrapper.backgroundColor = .clear
    wrapper.translatesAutoresizingMaskIntoConstraints = false
    wrapper.widthAnchor.constraint(equalToConstant: 1).isActive = true

    let line = UIView()
    line.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
    line.translatesAutoresizingMaskIntoConstraints = false
    wrapper.addSubview(line)
    NSLayoutConstraint.activate([
      line.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
      line.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
      line.widthAnchor.constraint(equalToConstant: 0.5),
      line.heightAnchor.constraint(equalToConstant: height * 0.45),
    ])
    return wrapper
  }

  // MARK: - Menu building

  private func buildMenu(from items: [[String: Any]], index: Int) -> UIMenu {
    let groups = groupByDividers(items)
    guard groups.count > 1 else {
      let children = groups.first?.compactMap { buildMenuElement(from: $0, index: index) } ?? []
      return UIMenu(children: children)
    }
    let menuChildren: [UIMenuElement] = groups.compactMap { group in
      let elements = group.compactMap { buildMenuElement(from: $0, index: index) }
      guard !elements.isEmpty else { return nil }
      return UIMenu(title: "", options: .displayInline, children: elements)
    }
    return UIMenu(children: menuChildren)
  }

  private func groupByDividers(_ items: [[String: Any]]) -> [[[String: Any]]] {
    var groups: [[[String: Any]]] = []
    var current: [[String: Any]] = []
    for item in items {
      if isDivider(item) {
        if !current.isEmpty { groups.append(current); current = [] }
      } else {
        current.append(item)
      }
    }
    if !current.isEmpty { groups.append(current) }
    return groups.isEmpty ? [[]] : groups
  }

  private func isDivider(_ item: [String: Any]) -> Bool {
    boolValue(from: item, key: "isDivider") ?? false
  }

  private func buildMenuElement(from item: [String: Any], index: Int) -> UIMenuElement? {
    if isDivider(item) { return nil }

    let title = item["label"] as? String ?? ""
    let iconName = item["icon"] as? String
    let image = iconName.flatMap { UIImage(systemName: $0) }
    let isDestructive = boolValue(from: item, key: "isDestructive") ?? false

    if let nested = item["children"] as? [[String: Any]], !nested.isEmpty {
      let children = nested.compactMap { buildMenuElement(from: $0, index: index) }
      return UIMenu(title: title, image: image, identifier: nil, options: [], children: children)
    }

    let value = item["value"] as? String
    let attributes: UIMenuElement.Attributes = isDestructive ? [.destructive] : []
    return UIAction(
      title: title,
      image: image,
      identifier: nil,
      discoverabilityTitle: nil,
      attributes: attributes,
      state: .off
    ) { [weak self] _ in
      guard let self, let value else { return }
      DispatchQueue.main.async {
        self.channel.invokeMethod("onMenuSelected_\(index)", arguments: value)
      }
    }
  }

  // MARK: - Helpers

  private func boolValue(from dict: [String: Any], key: String) -> Bool? {
    if let b = dict[key] as? Bool { return b }
    if let n = dict[key] as? NSNumber { return n.boolValue }
    return nil
  }
}
