import Flutter
import UIKit

final class LiquidToggleView: LiquidNativeView {
  private let toggle: UIControl

  // Last-applied styling, so a value flip (which re-sends every param) never
  // re-runs the expensive work. Setting overrideUserInterfaceStyle or the
  // accent color forces the glass material to recompute its blur; doing that a
  // frame into the knob's own slide is what read as a stutter.
  private var appliedIsDark: Bool?
  private var appliedEnabled: Bool?
  private var appliedAccent: UIColor?
  private var appliedLabel: String?

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
    applyStyle(from: params)
    applyEnabled(from: params)
    applyAccent(from: params)
    applyLabel(from: params)
    applyValue(from: params)
  }

  private func applyStyle(from params: [String: Any]) {
    let isDark: Bool?
    if let flag = params["isDark"] as? Bool {
      isDark = flag
    } else if let flag = params["isDark"] as? NSNumber {
      isDark = flag.boolValue
    } else {
      isDark = nil
    }
    guard let isDark, isDark != appliedIsDark else { return }
    appliedIsDark = isDark
    toggle.overrideUserInterfaceStyle = isDark ? .dark : .light
  }

  private func applyEnabled(from params: [String: Any]) {
    let enabled = params["enabled"] as? Bool ?? true
    guard enabled != appliedEnabled else { return }
    appliedEnabled = enabled
    toggle.isUserInteractionEnabled = enabled
    (toggle as? UISwitch)?.isEnabled = enabled
  }

  private func applyAccent(from params: [String: Any]) {
    guard let accentColor = UIColor(flutterARGBValue: params["accentColor"]),
      accentColor.isEqual(appliedAccent) == false
    else { return }
    appliedAccent = accentColor

    if let nativeToggle = toggle as? UISwitch {
      nativeToggle.onTintColor = accentColor
      return
    }
    let setter = NSSelectorFromString("setAccentColor:")
    if toggle.responds(to: setter) {
      toggle.perform(setter, with: accentColor)
    } else {
      toggle.tintColor = accentColor
    }
  }

  private func applyLabel(from params: [String: Any]) {
    let label = params["semanticLabel"] as? String
    guard label != appliedLabel else { return }
    appliedLabel = label
    toggle.accessibilityLabel = label
  }

  private func applyValue(from params: [String: Any]) {
    guard let value = params["value"] as? Bool, currentValue() != value else { return }
    setOn(value, animated: toggle.window != nil)
  }

  /// A programmatic flip (a row tap round-tripping back, or a declined change
  /// reverting) should slide like a direct tap, not snap. UISwitch and the
  /// glass control both mirror the UIKit `setOn:animated:` API; KVC is the
  /// last resort for a control that lacks it, and only ever lands unanimated.
  private func setOn(_ value: Bool, animated: Bool) {
    if let nativeToggle = toggle as? UISwitch {
      nativeToggle.setOn(value, animated: animated)
      return
    }
    let selector = NSSelectorFromString("setOn:animated:")
    if animated, toggle.responds(to: selector), let imp = toggle.method(for: selector) {
      typealias SetOnAnimated = @convention(c) (AnyObject, Selector, Bool, Bool) -> Void
      let call = unsafeBitCast(imp, to: SetOnAnimated.self)
      call(toggle, selector, value, true)
      return
    }
    toggle.setValue(value, forKey: "isOn")
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
