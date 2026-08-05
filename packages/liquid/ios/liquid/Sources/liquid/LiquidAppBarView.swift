import Flutter
import UIKit

/// Native background for [LiquidAppBar].
///
/// Renders only the bar's glass/blur material surface.  All interactive
/// content (title, leading widget, trailing buttons) is drawn by Flutter on
/// top of this native layer.
///
/// - iOS 26+: an empty `UINavigationBar` whose built-in Liquid Glass
///   appearance provides the correct system aesthetic.
/// - Earlier iOS: a `UIVisualEffectView` with `.systemChromeMaterial` and a
///   hairline bottom separator.
final class LiquidAppBarView: LiquidNativeView {
  private var backgroundView: UIView?

  init(registrar: FlutterPluginRegistrar, viewId: Int64, arguments: Any?) {
    let root = UIView()
    root.backgroundColor = .clear
    root.clipsToBounds = false

    super.init(
      registrar: registrar,
      viewId: viewId,
      viewType: "liquid_app_bar",
      rootView: root
    )

    setupBackground()
    apply(arguments as? [String: Any] ?? [:])
  }

  override func update(with params: [String: Any]) {
    apply(params)
  }

  // MARK: - Setup

  private func setupBackground() {
    if #available(iOS 26.0, *) {
      setupGlassBackground()
    } else {
      setupBlurBackground()
    }
  }

  /// iOS 26+: use an empty `UINavigationBar`.
  ///
  /// A single empty `UINavigationItem` keeps the bar in an active state so
  /// UIKit renders the Liquid Glass background, but produces no visible
  /// native title or button chrome — Flutter's own widgets are layered on top.
  @available(iOS 26.0, *)
  private func setupGlassBackground() {
    let bar = UINavigationBar()
    bar.translatesAutoresizingMaskIntoConstraints = false
    bar.isTranslucent = true
    bar.items = [UINavigationItem()]

    rootView.addSubview(bar)
    NSLayoutConstraint.activate([
      bar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      bar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      bar.topAnchor.constraint(equalTo: rootView.topAnchor),
      bar.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
    ])
    backgroundView = bar
  }

  /// Pre-iOS 26: `UIVisualEffectView` with system chrome material.
  private func setupBlurBackground() {
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    blur.translatesAutoresizingMaskIntoConstraints = false

    // Hairline bottom separator that matches the system navigation bar style.
    let separator = UIView()
    separator.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
    separator.translatesAutoresizingMaskIntoConstraints = false
    blur.contentView.addSubview(separator)
    NSLayoutConstraint.activate([
      separator.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
      separator.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
      separator.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),
      separator.heightAnchor.constraint(equalToConstant: 0.5),
    ])

    rootView.addSubview(blur)
    NSLayoutConstraint.activate([
      blur.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      blur.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      blur.topAnchor.constraint(equalTo: rootView.topAnchor),
      blur.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
    ])
    backgroundView = blur
  }

  // MARK: - Apply

  private func apply(_ params: [String: Any]) {
    applyUserInterfaceStyle(from: params)
    if let isDark = boolValue(from: params, key: "isDark") {
      backgroundView?.overrideUserInterfaceStyle = isDark ? .dark : .light
    }
  }
}
