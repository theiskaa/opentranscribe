import Flutter
import UIKit

final class LiquidTabBarView: LiquidNativeView {
  private let glassControl: UIControl?
  private let tabBar: UITabBar?

  private var tabs: [[String: Any]] = []
  private var selectedIndex: Int = 0
  private var hasActionTab: Bool = false
  private var actionIconName: String = "plus"
  private var actionIconColor: UIColor?

  // Apply initialIndex only once; subsequent Flutter rebuilds must not reset selection.
  private var didApplyInitialIndex: Bool = false

  // Prevent duplicate callbacks
  private var lastNotifiedIndex: Int?

  // Diff tabs to avoid internal resets
  private var lastAppliedLabels: [String]?

  init(registrar: FlutterPluginRegistrar, viewId: Int64, arguments: Any?) {
    let rootView: UIView
    if #available(iOS 26.0, *), let glass = LiquidGlassBridge.tabBar() {
      glassControl = glass
      tabBar = nil
      rootView = glass
    } else {
      glassControl = nil
      let bar = UITabBar(frame: .zero)
      bar.isTranslucent = true
      tabBar = bar
      rootView = bar
    }

    super.init(
      registrar: registrar,
      viewId: viewId,
      viewType: "liquid_tab_bar",
      rootView: rootView
    )

    apply(arguments as? [String: Any] ?? [:])
    configureTabAction()
  }

  override func update(with params: [String: Any]) {
    apply(params)
  }

  // MARK: - Tab action wiring

  private func configureTabAction() {
    if let glassControl {
      // Tap commit: notify Flutter AFTER the tap ends (fixes "tap morph + Flutter setActiveIndex" glitch window)
      let commitAction = UIAction { [weak self] _ in
        guard let self else { return }
        let index = self.currentIndex()

        // Next runloop tick: lets native finalize its internal state before Flutter rebuild triggers anything
        DispatchQueue.main.async { [weak self] in
          self?.notifyFlutterIfNeeded(index: index)
        }
      }
      glassControl.addAction(commitAction, for: .touchUpInside)
      glassControl.addAction(commitAction, for: .touchUpOutside)
      glassControl.addAction(commitAction, for: .touchCancel)

      return
    }

    tabBar?.delegate = self
  }

  private func notifyFlutterIfNeeded(index: Int) {
    if isActionSlot(index) {
      channel.invokeMethod("onActionPressed", arguments: nil)
      restoreSelectedTab()
      return
    }

    let normalizedIndex = normalizeIndex(index)
    guard normalizedIndex != lastNotifiedIndex else { return }
    lastNotifiedIndex = normalizedIndex
    selectedIndex = normalizedIndex
    channel.invokeMethod("onTabSelected", arguments: normalizedIndex)
  }

  // MARK: - Apply params

  private func apply(_ params: [String: Any]) {
    // Apply theme from Flutter to ensure consistent appearance
    applyUserInterfaceStyle(from: params)

    tabs = params["tabs"] as? [[String: Any]] ?? []

    // Preserve current selection unless this is the first apply.
    let requestedInitialIndex =
      (params["initialIndex"] as? Int) ?? (params["selectedIndex"] as? Int)

    let enabled = params["enabled"] as? Bool ?? true
    let semantics = params["semanticLabel"] as? String
    let activeIconColor = UIColor(flutterARGBValue: params["activeIconColor"])
    let inactiveIconColor = UIColor(flutterARGBValue: params["inactiveIconColor"])

    if let icon = params["actionIcon"] as? String, !icon.isEmpty {
      hasActionTab = true
      actionIconName = icon
    } else {
      hasActionTab = false
    }
    actionIconColor = UIColor(flutterARGBValue: params["actionIconColor"])

    if let glassControl {
      glassControl.isUserInteractionEnabled = enabled
      glassControl.accessibilityLabel = semantics
      glassControl.isEnabled = enabled
      if let activeIconColor { glassControl.tintColor = activeIconColor }

      let payload: [Any]
      if #available(iOS 26.0, *) {
        payload = buildUITabs()
      } else {
        payload = buildLabels()
      }

      let preservedIndex: Int = {
        let current = currentIndex()
        return isActionSlot(current) ? normalizeIndex(selectedIndex) : normalizeIndex(current)
      }()

      let desiredIndex: Int
      if !didApplyInitialIndex {
        desiredIndex = requestedInitialIndex ?? 0
        didApplyInitialIndex = true
      } else {
        desiredIndex = preservedIndex
      }

      let clampedIndex = normalizeIndex(desiredIndex)
      selectedIndex = clampedIndex

      // Apply tabs only when labels or the action icon appearance changed
      var labelsFingerprint = buildLabels()
      if hasActionTab {
        labelsFingerprint.append("\(actionIconName)|\(actionIconColor?.description ?? "")")
      }
      if labelsFingerprint != lastAppliedLabels {
        glassControl.setValue(payload, forKey: "tabs")
        lastAppliedLabels = labelsFingerprint
      }

      // IMPORTANT: do not fight the control while user is tracking.
      if glassControl.isTracking {
        return
      }

      let current = glassControl.value(forKey: "selectedIndex") as? Int ?? selectedIndex
      if current != selectedIndex {
        DispatchQueue.main.async { [weak glassControl] in
          glassControl?.setValue(clampedIndex, forKey: "selectedIndex")
        }
      }
      return
    }

    if let tabBar {
      tabBar.isUserInteractionEnabled = enabled
      tabBar.accessibilityLabel = semantics
      if let activeIconColor { tabBar.tintColor = activeIconColor }
      if let inactiveIconColor { tabBar.unselectedItemTintColor = inactiveIconColor }

      let preservedRawIndex = tabBar.selectedItem?.tag ?? selectedIndex
      let preservedIndex = isActionSlot(preservedRawIndex)
        ? normalizeIndex(selectedIndex)
        : normalizeIndex(preservedRawIndex)

      var items: [UITabBarItem] = tabs.enumerated().map { index, tab in
        let rawTitle = tab["label"] as? String
        let title: String? = {
          guard let rawTitle, !rawTitle.isEmpty else { return nil }
          return rawTitle
        }()

        let image: UIImage? = {
          if let assetName = tab["asset"] as? String, !assetName.isEmpty {
            return UIImage(named: assetName)?.withRenderingMode(.alwaysTemplate)
          }
          if let iconName = tab["icon"] as? String, !iconName.isEmpty {
            return UIImage(systemName: iconName)?.withRenderingMode(.alwaysTemplate)
          }
          return nil
        }()

        let item = UITabBarItem(title: title, image: image, tag: index)
        item.isEnabled = enabled
        return item
      }

      if hasActionTab {
        let actionItem = UITabBarItem(tabBarSystemItem: .search, tag: actionSlotIndex)
        if let actionImage = makeActionImage() {
          actionItem.image = actionImage
          actionItem.selectedImage = actionImage
        }
        actionItem.isEnabled = enabled
        items.append(actionItem)
      }

      tabBar.items = items
      let desiredIndex: Int
      if !didApplyInitialIndex {
        desiredIndex = requestedInitialIndex ?? 0
        didApplyInitialIndex = true
      } else {
        desiredIndex = preservedIndex
      }

      let clampedIndex = normalizeIndex(desiredIndex)
      selectedIndex = clampedIndex
      tabBar.selectedItem = items.isEmpty ? nil : items[min(clampedIndex, items.count - 1)]
    }
  }

  // MARK: - Tab building

  private func buildLabels() -> [String] {
    var labels: [String] = tabs.map { ($0["label"] as? String) ?? "" }
    if hasActionTab { labels.append("") }
    return labels
  }

  @available(iOS 26.0, *)
  private func buildUITabs() -> [UITab] {
    var displayTabs: [UITab] = tabs.enumerated().map { index, tab in
      let title = (tab["label"] as? String) ?? ""
      let image: UIImage? = {
        if let assetName = tab["asset"] as? String, !assetName.isEmpty {
          return UIImage(named: assetName)
        }
        if let iconName = tab["icon"] as? String, !iconName.isEmpty {
          return UIImage(systemName: iconName)
        }
        return nil
      }()
      return UITab(
        title: title,
        image: image,
        identifier: "liquid_tab_\(index)",
        viewControllerProvider: nil
      )
    }

    if hasActionTab {
      let searchTab = UISearchTab(viewControllerProvider: nil)
      searchTab.preferredPlacement = .pinned
      if let image = makeActionImage() {
        searchTab.image = image
      }
      displayTabs.append(searchTab)
    }

    return displayTabs
  }

  // MARK: - Helpers

  /// The pinned action icon, tinted with [actionIconColor] when provided.
  ///
  /// Tinting uses `.alwaysOriginal` because the tab bar would otherwise
  /// re-template the image with its own tint color.
  private func makeActionImage() -> UIImage? {
    guard let image = UIImage(systemName: actionIconName) else { return nil }
    if let actionIconColor {
      return image.withTintColor(actionIconColor, renderingMode: .alwaysOriginal)
    }
    return image.withRenderingMode(.alwaysTemplate)
  }

  private var actionSlotIndex: Int { tabs.count }

  private func isActionSlot(_ index: Int) -> Bool {
    hasActionTab && index == actionSlotIndex
  }

  private func normalizeIndex(_ index: Int) -> Int {
    max(0, min(index, max(0, tabs.count - 1)))
  }

  private func restoreSelectedTab() {
    let idx = normalizeIndex(selectedIndex)
    if let glassControl {
      guard !glassControl.isTracking else { return }
      DispatchQueue.main.async { [weak glassControl] in
        glassControl?.setValue(idx, forKey: "selectedIndex")
      }
      return
    }
    if let tabBar, let items = tabBar.items, !items.isEmpty {
      tabBar.selectedItem = items[min(idx, items.count - 1)]
    }
  }

  private func currentIndex() -> Int {
    if let glassControl {
      return glassControl.value(forKey: "selectedIndex") as? Int ?? selectedIndex
    }
    if let tabBar, let selectedItem = tabBar.selectedItem {
      return selectedItem.tag
    }
    return selectedIndex
  }
}

extension LiquidTabBarView: UITabBarDelegate {
  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    // UITabBar selection is already committed; still post async to match glass behavior
    let index = item.tag
    DispatchQueue.main.async { [weak self] in
      self?.notifyFlutterIfNeeded(index: index)
    }
  }
}
