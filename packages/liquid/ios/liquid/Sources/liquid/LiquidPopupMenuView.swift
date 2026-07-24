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
  private var items: [[String: Any]] = []
  private var buttonLabel: String?
  private var iconName: String?
  private var iconPointSize: CGFloat?

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
    if #available(iOS 15.0, *) {
      button.changesSelectionAsPrimaryAction = false
    }
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
    button.menu = buildMenu()
  }

  private func configureButtonAppearance() {
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
    } else if #available(iOS 15.0, *) {
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
    } else {
      // Фолбэк для очень старых iOS
      button.setTitle(nil, for: .normal)
      button.setImage(image, for: .normal)
      button.contentEdgeInsets = UIEdgeInsets(
        top: 10, left: 10, bottom: 10, right: 10
      )
      button.backgroundColor = .tertiarySystemFill
      button.tintColor = .label
    }

    // На случай, если конфигурация не до конца скруглит
    button.layer.cornerCurve = .continuous
  }

  private func buildMenu() -> UIMenu {
    // Group items by dividers to create visual separation
    let groups = groupItemsByDividers(items)

    if groups.count == 1 {
      // No dividers, just build children directly
      let children = groups[0].compactMap(buildMenuElement)
      return UIMenu(children: children)
    }

    // Multiple groups - wrap each in an inline menu for visual separation
    var menuChildren: [UIMenuElement] = []
    for group in groups {
      let groupElements = group.compactMap(buildMenuElement)
      if !groupElements.isEmpty {
        let inlineMenu = UIMenu(title: "", options: .displayInline, children: groupElements)
        menuChildren.append(inlineMenu)
      }
    }
    return UIMenu(children: menuChildren)
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

  private func buildMenuElement(from item: [String: Any]) -> UIMenuElement? {
    // Skip dividers - they are handled by grouping
    if isDivider(item) {
      return nil
    }

    let title = item["label"] as? String ?? ""
    let iconName = item["icon"] as? String
    let itemSymbolConfig = UIImage.SymbolConfiguration(
      pointSize: itemIconPointSize, weight: .regular, scale: .medium)
    let image = iconName.flatMap { UIImage(systemName: $0, withConfiguration: itemSymbolConfig) }
    let isDestructive = (item["isDestructive"] as? NSNumber)?.boolValue
      ?? (item["isDestructive"] as? Bool ?? false)

    if let nested = item["children"] as? [[String: Any]], !nested.isEmpty {
      let submenuChildren = nested.compactMap(buildMenuElement)
      if #available(iOS 13.0, *) {
        return UIMenu(
          title: title, image: image, identifier: nil, options: [], children: submenuChildren)
      }
      return UIMenu(title: title, children: submenuChildren)
    }

    let value = item["value"] as? String
    if #available(iOS 13.0, *) {
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
        // Delay callback to next runloop cycle to let UIMenu dismiss animation complete
        DispatchQueue.main.async {
          self.channel.invokeMethod("onSelected", arguments: value)
        }
      }
    }

    return UIAction(title: title, state: .off) { [weak self] _ in
      guard let self, let value else { return }
      // Delay callback to next runloop cycle to let UIMenu dismiss animation complete
      DispatchQueue.main.async {
        self.channel.invokeMethod("onSelected", arguments: value)
      }
    }
  }
}
