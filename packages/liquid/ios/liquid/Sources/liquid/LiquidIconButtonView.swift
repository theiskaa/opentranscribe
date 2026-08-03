import Flutter
import UIKit

private final class LiquidCircularButton: UIButton {
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

final class LiquidIconButtonView: LiquidNativeView {
  private let root: UIView
  private let button: LiquidCircularButton
  private var buttonSize: CGFloat = 44
  private var buttonWidthConstraint: NSLayoutConstraint?
  private var buttonHeightConstraint: NSLayoutConstraint?
  private var iconName: String = "ellipsis"
  private var iconPointSize: CGFloat = 17
  private var iconWeight: UIImage.SymbolWeight = .semibold
  private var tintColor: UIColor?

  init(
    registrar: FlutterPluginRegistrar,
    viewId: Int64,
    arguments: Any?
  ) {
    root = UIView(frame: .zero)
    root.backgroundColor = .clear
    root.clipsToBounds = false

    button = LiquidCircularButton(type: .system)
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
      viewType: "liquid_icon_button",
      rootView: root
    )

    apply(arguments as? [String: Any] ?? [:])
    configureAction()
  }

  override func update(with params: [String: Any]) {
    apply(params)
  }

  private func configureAction() {
    let action = UIAction { [weak self] _ in
      self?.channel.invokeMethod("onTap", arguments: nil)
    }
    button.addAction(action, for: .touchUpInside)
  }

  private func apply(_ params: [String: Any]) {
    // Apply theme from Flutter to ensure consistent appearance
    applyUserInterfaceStyle(from: params)

    if let size = params["size"] as? Double {
      buttonSize = CGFloat(size)
      buttonWidthConstraint?.constant = buttonSize
      buttonHeightConstraint?.constant = buttonSize
      root.setNeedsLayout()
    }

    let enabled = params["enabled"] as? Bool ?? true
    let semantics = params["semanticLabel"] as? String

    if let icon = params["icon"] as? String {
      iconName = icon
    }

    if let size = params["iconPointSize"] as? Double {
      iconPointSize = CGFloat(size)
    }

    if let weight = params["iconWeight"] as? String {
      iconWeight = Self.symbolWeight(from: weight)
    }

    tintColor = UIColor(flutterARGBValue: params["tintColor"])

    button.isEnabled = enabled
    button.isUserInteractionEnabled = enabled
    button.accessibilityLabel = semantics

    configureButtonAppearance()
  }

  private static func symbolWeight(from name: String) -> UIImage.SymbolWeight {
    switch name {
    case "ultraLight": return .ultraLight
    case "thin": return .thin
    case "light": return .light
    case "regular": return .regular
    case "medium": return .medium
    case "semibold": return .semibold
    case "bold": return .bold
    case "heavy": return .heavy
    case "black": return .black
    default: return .semibold
    }
  }

  private func configureButtonAppearance() {
    let symbolConfig = UIImage.SymbolConfiguration(
      pointSize: iconPointSize,
      weight: iconWeight
    )
    let image = UIImage(systemName: iconName, withConfiguration: symbolConfig)

    button.contentHorizontalAlignment = .center
    button.contentVerticalAlignment = .center

    if #available(iOS 26.0, *) {
      // LiquidGlass circular button
      var config = UIButton.Configuration.glass()
      // The glass configuration ignores baseForegroundColor, so tint the
      // symbol image itself.
      if let tintColor {
        config.image = image?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
      } else {
        config.image = image
      }
      config.preferredSymbolConfigurationForImage = symbolConfig
      config.title = nil
      config.contentInsets = NSDirectionalEdgeInsets(
        top: 8, leading: 8, bottom: 8, trailing: 8
      )
      config.cornerStyle = .capsule
      button.configuration = config
    } else {
      // Fallback: tinted pill style
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

    button.layer.cornerCurve = .continuous
  }
}
