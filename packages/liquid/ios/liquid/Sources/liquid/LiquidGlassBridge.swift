import UIKit

enum LiquidGlassBridge {
  @available(iOS 26.0, *)
  static func toggle() -> UIControl? {
    guard let toggleType = NSClassFromString("LiquidGlass.LiquidToggle") as? UIControl.Type else {
      return nil
    }
    return toggleType.init()
  }

  @available(iOS 26.0, *)
  static func tabBar() -> UIControl? {
    // LiquidGlass tab bars are exposed as UIControl-compatible components.
    if let tabBarType = NSClassFromString("LiquidGlass.LiquidTabBar") as? UIControl.Type {
      return tabBarType.init()
    }
    return nil
  }

  @available(iOS 26.0, *)
  static func popupButton() -> UIControl? {
    if let buttonType = NSClassFromString("LiquidGlass.LiquidPopupButton") as? UIControl.Type {
      return buttonType.init()
    }
    return nil
  }
}
