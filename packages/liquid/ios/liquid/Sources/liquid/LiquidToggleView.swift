import Flutter
import UIKit

final class LiquidToggleView: LiquidNativeView {
  private let toggle: UIControl

  // Apply initialValue only once; subsequent Flutter rebuilds must not reset selection.
  private var didApplyInitialValue: Bool = false

  init(registrar: FlutterPluginRegistrar, viewId: Int64, arguments: Any?) {
    if #available(iOS 26.0, *), let control = LiquidGlassBridge.toggle() {
      toggle = control
    } else {
      toggle = UISwitch(frame: .zero)
    }

    super.init(registrar: registrar, viewId: viewId, viewType: "liquid_toggle", rootView: toggle)

    apply(arguments as? [String: Any] ?? [:])
    configureAction()
  }

  override func update(with params: [String: Any]) {
    apply(params)
  }

  private func configureAction() {
    let action = UIAction { [weak self] _ in
      guard let self else { return }
      let current = self.currentValue()
      self.channel.invokeMethod("onChanged", arguments: current)
    }

    toggle.addAction(action, for: .valueChanged)
  }

  private func apply(_ params: [String: Any]) {
    // Apply theme from Flutter to ensure consistent appearance
    applyUserInterfaceStyle(from: params)

    let requestedInitialValue = (params["initialValue"] as? Bool) ?? (params["value"] as? Bool)
    let isOn: Bool
    if !didApplyInitialValue {
      isOn = requestedInitialValue ?? false
      didApplyInitialValue = true
    } else {
      isOn = currentValue()
    }
    let enabled = params["enabled"] as? Bool ?? true
    let semantics = params["semanticLabel"] as? String
    let accentColor = UIColor(liquidFlutterARGBValue: params["accentColor"])

    toggle.isUserInteractionEnabled = enabled
    toggle.accessibilityLabel = semantics

    if let nativeToggle = toggle as? UISwitch {
      nativeToggle.isOn = isOn
      nativeToggle.isEnabled = enabled
      if let accentColor {
        nativeToggle.onTintColor = accentColor
      } else {
        nativeToggle.onTintColor = nil
      }
    } else {
      toggle.setValue(isOn, forKey: "isOn")

      guard let accentColor else { return }

      let setter = NSSelectorFromString("setAccentColor:")
      if toggle.responds(to: setter) {
        // LiquidGlass / новые контролы: используем только их родной accentColor
        toggle.perform(setter, with: accentColor)
      } else {
        // Фолбэк для каких-то других кастомных контролов
        toggle.tintColor = accentColor
      }
    }
  }

  private func currentValue() -> Bool {
    if let nativeToggle = toggle as? UISwitch {
      return nativeToggle.isOn
    }

    if let value = toggle.value(forKey: "isOn") as? Bool {
      return value
    }

    return false
  }
}

extension UIColor {
  /// Creates a UIColor from a Flutter `Color.value` int in AARRGGBB format.
  fileprivate convenience init?(liquidFlutterARGBValue: Any?) {
    let argb: Int64?
    switch liquidFlutterARGBValue {
    case let v as Int:
      argb = Int64(v)
    case let v as Int64:
      argb = v
    case let v as NSNumber:
      argb = v.int64Value
    default:
      argb = nil
    }

    guard let argb else { return nil }

    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0

    self.init(red: r, green: g, blue: b, alpha: a)
  }
}
