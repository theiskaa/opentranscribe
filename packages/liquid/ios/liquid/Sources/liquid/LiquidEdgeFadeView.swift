import Flutter
import UIKit

/// The native material behind a screen-edge bar, built on the system's own
/// scroll-edge effect: a transparent proxy scroll view held in a scrolled
/// state so its top edge renders the iOS 26 progressive blur (the real
/// nav-bar melt, blur radius easing to nothing), washed with the theme tint.
/// Being a UIKit sibling it blurs platform views scrolling under the bar,
/// which a Flutter BackdropFilter cannot (the engine's injected blur breaks
/// iOS 26 glass into an opaque black rectangle). A gradient-masked
/// UIVisualEffectView cannot serve here either: a mask fades only its tint,
/// the blur clips instead of melting.
final class LiquidEdgeFadeView: LiquidNativeView {
  private let fade: EdgeFadeBackdropView

  init(registrar: FlutterPluginRegistrar, viewId: Int64, arguments: Any?) {
    let params = arguments as? [String: Any] ?? [:]
    fade = EdgeFadeBackdropView()
    super.init(registrar: registrar, viewId: viewId, viewType: "liquid_edge_fade", rootView: fade)
    apply(params)
  }

  override func update(with params: [String: Any]) {
    apply(params)
  }

  private func apply(_ params: [String: Any]) {
    applyUserInterfaceStyle(from: params)
    if let wash = UIColor(flutterARGBValue: params["color"]) {
      fade.wash = wash
    }
    if let fadeFrom = params["fadeFrom"] as? Double {
      fade.fadeFrom = CGFloat(fadeFrom)
    }
    if let chromeHeight = params["chromeHeight"] as? Double {
      fade.chromeHeight = CGFloat(chromeHeight)
    }
  }
}

private final class EdgeFadeBackdropView: UIView {
  private let proxy = UIScrollView()
  private let barContainer = UIView()
  private let washView = GradientWashView()

  var wash: UIColor = .clear {
    didSet { washView.apply(color: wash, fadeFrom: fadeFrom) }
  }

  var fadeFrom: CGFloat = 0.5 {
    didSet { washView.apply(color: wash, fadeFrom: fadeFrom) }
  }

  /// Where the bar's content region ends: the proxy's top inset, so the edge
  /// effect treats everything above it as "under the bar", and the frame of
  /// the container the effect shapes itself around.
  var chromeHeight: CGFloat = 0 {
    didSet { setNeedsLayout() }
  }

  init() {
    super.init(frame: .zero)
    isUserInteractionEnabled = false
    backgroundColor = .clear

    proxy.backgroundColor = .clear
    proxy.isScrollEnabled = false
    proxy.showsVerticalScrollIndicator = false
    proxy.showsHorizontalScrollIndicator = false
    proxy.contentInsetAdjustmentBehavior = .never
    if #available(iOS 26.0, *) {
      proxy.topEdgeEffect.style = .soft
      let interaction = UIScrollEdgeElementContainerInteraction()
      interaction.scrollView = proxy
      interaction.edge = .top
      barContainer.addInteraction(interaction)
    }
    addSubview(proxy)
    addSubview(barContainer)
    addSubview(washView)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func layoutSubviews() {
    super.layoutSubviews()
    proxy.frame = bounds
    proxy.contentInset = UIEdgeInsets(top: chromeHeight, left: 0, bottom: 0, right: 0)
    proxy.contentSize = CGSize(width: bounds.width, height: bounds.height * 3)
    // The effect only draws while content sits beyond the edge; the proxy is
    // held well past it so the material is always present. Over a resting
    // uniform background a blur of that background is invisible, matching the
    // drawn EdgeFade's at-rest behavior.
    proxy.contentOffset = CGPoint(x: 0, y: bounds.height)
    barContainer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: chromeHeight)
    washView.frame = bounds
  }
}

private final class GradientWashView: UIView {
  override class var layerClass: AnyClass { CAGradientLayer.self }

  /// The drawn EdgeFade's tint ramp: full wash to `fadeFrom`, then eased to
  /// clear. A straight ramp reads as a visible edge.
  func apply(color: UIColor, fadeFrom: CGFloat) {
    let alpha = color.cgColor.alpha
    let gradient = layer as! CAGradientLayer
    gradient.startPoint = CGPoint(x: 0.5, y: 0)
    gradient.endPoint = CGPoint(x: 0.5, y: 1)
    gradient.colors = [
      color.cgColor,
      color.cgColor,
      color.withAlphaComponent(alpha * 0xB0 / 255.0).cgColor,
      color.withAlphaComponent(0).cgColor,
    ]
    gradient.locations = [
      0,
      NSNumber(value: fadeFrom),
      NSNumber(value: fadeFrom + 0.5 * (1 - fadeFrom)),
      1,
    ]
  }
}
