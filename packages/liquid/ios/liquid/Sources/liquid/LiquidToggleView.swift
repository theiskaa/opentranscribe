import Flutter
import UIKit

final class LiquidToggleView: LiquidNativeView {
  private let toggle: UISwitch

  // Last-applied styling, so a value flip (which re-sends every param) never
  // re-runs the expensive work. Setting overrideUserInterfaceStyle or the
  // accent color forces the glass material to recompute its blur; doing that a
  // frame into the knob's own slide is what read as a stutter. A theme flip
  // does change these for real, and the cache lets that through since the
  // values genuinely differ.
  private var appliedIsDark: Bool?
  private var appliedEnabled: Bool?
  private var appliedAccent: UIColor?
  private var appliedLabel: String?

  init(registrar: FlutterPluginRegistrar, viewId: Int64, arguments: Any?) {
    toggle = UISwitch(frame: .zero)

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
    let restyled = applyStyle(from: params)
    let retinted = applyAccent(from: params)
    applyLabel(from: params)
    let flips = pendingValue(params) != nil
    // A crossfade blends whatever else changes in the same pass: a flip would
    // show two knobs and a restyle would fade with it, so those snap the dim.
    applyEnabled(from: params, fade: !(restyled || retinted || flips))
    applyValue(from: params)
  }

  private func applyStyle(from params: [String: Any]) -> Bool {
    guard let isDark = boolValue(from: params, key: "isDark"), isDark != appliedIsDark else {
      return false
    }
    appliedIsDark = isDark
    toggle.overrideUserInterfaceStyle = isDark ? .dark : .light
    return true
  }

  private func applyEnabled(from params: [String: Any], fade: Bool) {
    let enabled = params["enabled"] as? Bool ?? true
    guard enabled != appliedEnabled else { return }
    let initial = appliedEnabled == nil
    appliedEnabled = enabled
    let duration = TimeInterval(params["enabledFadeMs"] as? Int ?? 0) / 1000
    if initial || !fade || duration <= 0 || toggle.window == nil {
      toggle.isEnabled = enabled
      return
    }
    // isEnabled is not animatable, so a crossfade catches however UIKit draws the dim.
    UIView.transition(
      with: toggle,
      duration: duration,
      options: [.transitionCrossDissolve, .allowUserInteraction],
      animations: { self.toggle.isEnabled = enabled }
    )
  }

  private func applyAccent(from params: [String: Any]) -> Bool {
    guard let accentColor = UIColor(flutterARGBValue: params["accentColor"]),
      !accentColor.isEqual(appliedAccent)
    else { return false }
    appliedAccent = accentColor

    toggle.onTintColor = accentColor
    return true
  }

  private func applyLabel(from params: [String: Any]) {
    let label = params["semanticLabel"] as? String
    guard label != appliedLabel else { return }
    appliedLabel = label
    toggle.accessibilityLabel = label
  }

  private func applyValue(from params: [String: Any]) {
    guard let value = pendingValue(params) else { return }
    setOn(value, animated: toggle.window != nil)
  }

  /// The value [params] asks for, only when it differs from the switch's own.
  private func pendingValue(_ params: [String: Any]) -> Bool? {
    guard let value = boolValue(from: params, key: "value"), value != currentValue() else {
      return nil
    }
    return value
  }

  /// A programmatic flip (a row tap round-tripping back, or a declined change
  /// reverting) should slide like a direct tap, not snap.
  private func setOn(_ value: Bool, animated: Bool) {
    toggle.setOn(value, animated: animated)
  }

  private func currentValue() -> Bool {
    toggle.isOn
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
