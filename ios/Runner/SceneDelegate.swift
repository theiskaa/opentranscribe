import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// One cold-start affair. A scene reconnect on a live process (multitasking
  /// churn) would replay the splash over a running app whose hand-off has long
  /// fired, and only the backstop would ever take it down.
  private static var splashPresented = false

  /// Backstop for a launch that never reaches the hand-off: LaunchFailureApp
  /// touches no channel by design, and its copy must not sit under a wave
  /// forever. Past the common launch path, not every path: a launch limping
  /// through several channel timeouts gets uncovered before it resolves, which
  /// beats hiding the failure copy.
  private static let backstop: TimeInterval = 10

  private weak var splash: WaveSplashView?
  private var splashWindow: UIWindow?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let windowScene = scene as? UIWindowScene, !Self.splashPresented else { return }
    Self.splashPresented = true
    // Its own window above the app's, not a subview of it: UIKit attaches the
    // root controller's view to the main window on its own schedule, over
    // whatever was added first, so a sibling subview cannot be trusted to stay
    // on top. A higher window can.
    let splash = WaveSplashView(frame: windowScene.coordinateSpace.bounds)
    let host = UIViewController()
    host.view = splash
    let overlay = UIWindow(windowScene: windowScene)
    overlay.windowLevel = UIWindow.Level(UIWindow.Level.normal.rawValue + 1)
    // Interactive on purpose: the app underneath is live once Dart paints, and
    // a tap at a screen the wave still covers must land nowhere, not on some
    // invisible control. The window is torn down with the wave.
    // The style override keeps the status bar with the app's forced mode; a
    // bare host controller would resolve it against the system instead.
    overlay.overrideUserInterfaceStyle = LaunchBackdrop.interfaceStyle()
    overlay.rootViewController = host
    overlay.isHidden = false
    self.splash = splash
    splashWindow = overlay
    splash.onRetired = { [weak self] in
      self?.splashWindow?.isHidden = true
      self?.splashWindow = nil
    }
    splash.arrive()
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.backstop) { [weak splash] in
      splash?.finish()
    }
  }

  /// The draw-in starts here, not at connect: SpringBoard shows the launch
  /// screen until well past the connect, and activation is the first moment
  /// the window is actually being revealed. Until then the splash is only the
  /// launch screen's own colour, so the reveal has no seam.
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    splash?.begin()
  }
}
