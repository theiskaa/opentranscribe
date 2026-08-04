import Flutter
import UIKit

final class LiquidToggleView: LiquidNativeView {
  private let toggle: UIControl

  init(registrar: FlutterPluginRegistrar, viewId: Int64, arguments: Any?) {
    if #available(iOS 26.0, *), let control = LiquidGlassBridge.toggle() {
      toggle = control
    } else {
      toggle = UISwitch(frame: .zero)
    }

    super.init(
      registrar: registrar, viewId: viewId, viewType: "liquid_toggle",
      rootView: ToggleHostView(control: toggle))

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
    applyUserInterfaceStyle(from: params)

    let value = params["value"] as? Bool
    let enabled = params["enabled"] as? Bool ?? true
    let accentColor = UIColor(flutterARGBValue: params["accentColor"])

    toggle.isUserInteractionEnabled = enabled
    toggle.accessibilityLabel = params["semanticLabel"] as? String

    if let nativeToggle = toggle as? UISwitch {
      if let value, nativeToggle.isOn != value {
        nativeToggle.setOn(value, animated: nativeToggle.window != nil)
      }
      nativeToggle.isEnabled = enabled
      nativeToggle.onTintColor = accentColor
      return
    }

    if let value, currentValue() != value {
      toggle.setValue(value, forKey: "isOn")
    }

    guard let accentColor else { return }
    let setter = NSSelectorFromString("setAccentColor:")
    if toggle.responds(to: setter) {
      toggle.perform(setter, with: accentColor)
    } else {
      toggle.tintColor = accentColor
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

/// A UISwitch draws at its intrinsic size regardless of the frame the platform
/// view is given; centered and scaled down (never up) to fit, so it cannot
/// overflow the box Flutter reserves for it.
private final class ToggleHostView: UIView {
  private let control: UIControl

  init(control: UIControl) {
    self.control = control
    super.init(frame: .zero)
    backgroundColor = .clear
    addSubview(control)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func layoutSubviews() {
    super.layoutSubviews()
    var size = control.intrinsicContentSize
    if size.width <= 0 || size.height <= 0 {
      size = control.sizeThatFits(bounds.size)
    }
    guard size.width > 0, size.height > 0 else { return }
    control.bounds = CGRect(origin: .zero, size: size)
    control.center = CGPoint(x: bounds.midX, y: bounds.midY)
    let scale = min(1, min(bounds.width / size.width, bounds.height / size.height))
    control.transform = CGAffineTransform(scaleX: scale, y: scale)
  }
}
