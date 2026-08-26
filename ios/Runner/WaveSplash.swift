import Flutter
import UIKit

/// The launch colours Dart mirrors into plain UserDefaults (launch_backdrop.dart
/// writes, this reads; the packed format is the contract). Resolved against the
/// live trait collection, because the system appearance can flip while the app
/// is terminated and a stored resolution would be stale.
enum LaunchBackdrop {
  private static let key = "flutter.launchBackdrop"

  static func colors(for traits: UITraitCollection) -> (background: UIColor, ink: UIColor) {
    let wantDark = traits.userInterfaceStyle == .dark
    guard let packed = UserDefaults.standard.string(forKey: key) else {
      return fallback(dark: wantDark, traits: traits)
    }
    let parts = packed.split(separator: ",").map(String.init)
    guard parts.count == 5 else { return fallback(dark: wantDark, traits: traits) }
    let dark = parts[0] == "dark" || (parts[0] != "light" && wantDark)
    guard
      let background = color(hex: dark ? parts[3] : parts[1]),
      let ink = color(hex: dark ? parts[4] : parts[2])
    else { return fallback(dark: wantDark, traits: traits) }
    return (background, ink)
  }

  /// The packed mode as a trait override for the splash window, so its status
  /// bar follows the app's forced appearance rather than the system's.
  static func interfaceStyle() -> UIUserInterfaceStyle {
    let mode = UserDefaults.standard.string(forKey: key)?.split(separator: ",").first
    switch mode {
    case "dark": return .dark
    case "light": return .light
    default: return .unspecified
    }
  }

  /// What the launch storyboard painted: the asset colour under the live
  /// traits, static like everything else here.
  static func storyboardColor(for traits: UITraitCollection) -> UIColor {
    UIColor(named: "LaunchBackground")?.resolvedColor(with: traits)
      ?? (traits.userInterfaceStyle == .dark ? UIColor(white: 0x11 / 255.0, alpha: 1) : .white)
  }

  /// No mirrored value, or one that fails to parse: the default palette.
  /// Resolved to a static colour so both paths return the same kind.
  private static func fallback(dark: Bool, traits: UITraitCollection)
    -> (background: UIColor, ink: UIColor)
  {
    let ink =
      dark
      ? UIColor(red: 0xF5 / 255.0, green: 0xF5 / 255.0, blue: 0xF5 / 255.0, alpha: 1)
      : UIColor(white: 0x11 / 255.0, alpha: 1)
    return (storyboardColor(for: traits), ink)
  }

  private static func color(hex: String) -> UIColor? {
    guard hex.count == 8, let argb = UInt32(hex, radix: 16) else { return nil }
    return UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255.0,
      green: CGFloat((argb >> 8) & 0xFF) / 255.0,
      blue: CGFloat(argb & 0xFF) / 255.0,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255.0)
  }
}

/// The native launch splash: the brand wave over the launch window while
/// Flutter boots, so the wait is spent watching the mark draw in instead of a
/// flat colour. Phase-driven, not a fixed timeline: the draw-in runs to
/// completion, the settled wave holds for as long as launch actually takes, and
/// [finish] plays the collapse and retires the view's window.
///
/// Every movement is a `CAAnimation`, never a main-thread tick: the render
/// server animates out of process, so the wave stays smooth while the engine
/// boot and `Deps.init` saturate the main thread. A `CADisplayLink` here janks
/// exactly like the Dart splash it replaces, and for the same reason.
///
/// The first frame matches the launch storyboard's colour exactly, and the
/// theme's background fades in from the first commit [arrive]: the storyboard
/// is SpringBoard's and can only follow the system appearance, so a theme that
/// disagrees with it would otherwise land as a hard cut at the hand-over. The
/// fade usually completes before the window is revealed, so the reveal shows
/// the theme; an eye that catches its tail sees a blend, never a cut.
///
/// This file owns the launch wave's geometry: seven bars in the brand SVG's
/// 492x481 box, width 42, pitch 75, stagger 0.09, ~730ms easeOutCubic draw,
/// ~200ms easeInOutCubic collapse. The in-app waves share only the bar pattern
/// (`kWavePattern` in pull_to_record.dart).
final class WaveSplashView: UIView {
  /// The one live splash, for the hand-off. Weak, so the collapse's removal
  /// clears it without ceremony.
  private(set) static weak var current: WaveSplashView?

  private static let pattern: [CGFloat] = [0.35, 0.65, 1.0, 0.7, 0.5, 0.85, 0.4]
  private static let stagger = 0.09
  private static let span = 1.0 - stagger * Double(pattern.count - 1)
  private static let drawDuration: CFTimeInterval = 0.73
  private static let collapseDuration: CFTimeInterval = 0.2

  private static let easeOutCubic = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
  private static let easeInOutCubic = CAMediaTimingFunction(controlPoints: 0.645, 0.045, 0.355, 1)

  /// A settle beat between the draw-in and a collapse that was asked during
  /// it, so the wave reads as arriving before it leaves.
  private static let settle: CFTimeInterval = 0.07

  /// The storyboard-to-theme background fade.
  private static let arriveDuration: CFTimeInterval = 0.25

  private let bars: [CALayer]
  private let reduceMotion = UIAccessibility.isReduceMotionEnabled

  private var settledBackground: UIColor = .white
  private var drawEnd: CFTimeInterval = 0
  private var begun = false
  private var finishAsked = false
  private var done: (() -> Void)?

  /// The presenter's teardown: the view lives in its own window, and hiding
  /// a root view does not take the window with it.
  var onRetired: (() -> Void)?

  override init(frame: CGRect) {
    bars = Self.pattern.map { _ in CALayer() }
    super.init(frame: frame)
    let colors = LaunchBackdrop.colors(for: traitCollection)
    settledBackground = colors.background
    // The first committed frame continues the launch storyboard, seam-free;
    // the theme's background arrives in [arrive].
    backgroundColor = LaunchBackdrop.storyboardColor(for: traitCollection)
    for bar in bars {
      bar.backgroundColor = colors.ink.cgColor
      layer.addSublayer(bar)
    }
    Self.current = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  /// Fades the background from the storyboard's colour to the theme's. Called
  /// as soon as the view is in its window, so the fade plays against the first
  /// commits, before the window is revealed. A fade even under Reduce Motion,
  /// which stills movement, not crossfades; themes that match the system make
  /// it a no-op either way.
  func arrive() {
    let fade = CABasicAnimation(keyPath: "backgroundColor")
    fade.fromValue = layer.backgroundColor
    fade.toValue = settledBackground.cgColor
    fade.duration = Self.arriveDuration
    fade.timingFunction = Self.easeInOutCubic
    backgroundColor = settledBackground
    layer.add(fade, forKey: "arrive")
  }

  /// Starts the draw-in; under Reduce Motion the wave shows whole instead.
  ///
  /// Called at scene activation, not scene connect: SpringBoard is still
  /// showing the launch screen when the scene connects, and a draw-in anchored
  /// there plays to nobody. Until this runs the view is only its background.
  func begin() {
    guard !begun else { return }
    begun = true
    let glyphHeight = min(176, max(104, min(bounds.width, bounds.height) * 0.3))
    let glyphWidth = glyphHeight * 492 / 481
    let originX = (bounds.width - glyphWidth) / 2
    let centerY = bounds.height / 2
    let barWidth = glyphWidth * 42 / 492

    let now = CACurrentMediaTime()
    drawEnd = now + Self.drawDuration

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for (i, bar) in bars.enumerated() {
      let height = glyphHeight * Self.pattern[i]
      // The model is the settled wave; the animations only cover the way in.
      bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: height)
      bar.position = CGPoint(x: originX + glyphWidth * CGFloat(75 * i) / 492 + barWidth / 2,
                             y: centerY)
      bar.cornerRadius = barWidth / 2
      if reduceMotion { continue }

      let start = now + Double(i) * Self.stagger * Self.drawDuration
      let grow = CABasicAnimation(keyPath: "bounds.size.height")
      grow.fromValue = barWidth
      grow.toValue = height
      grow.duration = Self.span * Self.drawDuration
      grow.beginTime = start
      grow.timingFunction = Self.easeOutCubic
      grow.fillMode = .backwards
      bar.add(grow, forKey: "grow")

      // Before its stagger slot the bar does not exist; it then pops in as a
      // dot and grows.
      let appear = CABasicAnimation(keyPath: "opacity")
      appear.fromValue = 0
      appear.toValue = 1
      appear.duration = 0.01
      appear.beginTime = start
      appear.fillMode = .backwards
      bar.add(appear, forKey: "appear")
    }
    CATransaction.commit()
    if finishAsked { leave() }
  }

  /// Collapses the wave, hides the view and retires its window through
  /// [onRetired], calling [completion] after. Asked before the draw-in has run
  /// or finished, the draw plays out first: the stroke is never cut, and a
  /// launch that beats the eye still shows the whole arrival. The wait runs on
  /// the main queue, so a stall there only lengthens the hold.
  func finish(completion: (() -> Void)? = nil) {
    guard !finishAsked else { return }
    finishAsked = true
    done = completion
    if begun { leave() }
  }

  private func leave() {
    if reduceMotion {
      UIView.animate(
        withDuration: Self.collapseDuration, delay: 0, options: [],
        animations: { self.alpha = 0 },
        completion: { _ in self.retire() })
      return
    }
    let remaining = max(0, drawEnd - CACurrentMediaTime()) + Self.settle
    DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
      self?.collapse()
    }
  }

  private func retire() {
    isHidden = true
    onRetired?()
    onRetired = nil
    done?()
    done = nil
  }

  private func collapse() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    CATransaction.setCompletionBlock { [weak self] in
      self?.retire()
    }
    for bar in bars {
      let shrink = CABasicAnimation(keyPath: "bounds.size.height")
      shrink.fromValue = bar.bounds.height
      shrink.toValue = 0
      shrink.duration = Self.collapseDuration
      shrink.timingFunction = Self.easeInOutCubic
      bar.bounds.size.height = 0

      let round = CABasicAnimation(keyPath: "cornerRadius")
      round.fromValue = bar.cornerRadius
      round.toValue = 0
      round.duration = Self.collapseDuration
      round.timingFunction = Self.easeInOutCubic
      bar.cornerRadius = 0

      bar.add(shrink, forKey: "shrink")
      bar.add(round, forKey: "round")
    }
    CATransaction.commit()
  }
}

/// Dart's side of the splash: `splash_handoff.dart` calls `finish` after home's
/// first frame, and the wave collapses over a journal that is already painted.
final class SplashHandoffPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    // Channel name: must match splash_handoff.dart.
    let channel = FlutterMethodChannel(
      name: "opentranscribe/splash", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SplashHandoffPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "finish":
      WaveSplashView.current?.finish()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
