import Flutter
import UIKit

final class LiquidViewFactory: NSObject, FlutterPlatformViewFactory {
  private let registrar: FlutterPluginRegistrar
  private let viewType: String
  private let builder: (_ frame: CGRect, _ viewId: Int64, _ args: Any?) -> FlutterPlatformView

  init(
    registrar: FlutterPluginRegistrar,
    viewType: String,
    builder: @escaping (_ frame: CGRect, _ viewId: Int64, _ args: Any?) -> FlutterPlatformView
  ) {
    self.registrar = registrar
    self.viewType = viewType
    self.builder = builder
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    builder(frame, viewId, args)
  }
}

class LiquidNativeView: NSObject, FlutterPlatformView {
  let channel: FlutterMethodChannel
  let rootView: UIView

  init(registrar: FlutterPluginRegistrar, viewId: Int64, viewType: String, rootView: UIView) {
    self.rootView = rootView
    channel = FlutterMethodChannel(name: "liquid/\(viewType)_\(viewId)", binaryMessenger: registrar.messenger())
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "missing_host", message: "Platform view released", details: nil))
        return
      }
      switch call.method {
      case "update":
        if let params = call.arguments as? [String: Any] {
          self.update(with: params)
          result(nil)
        } else {
          result(FlutterError(code: "invalid_args", message: "Expected map for update", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // The messenger retains the handler until it is cleared, and every recreation
  // of a platform view mints a new channel, so a stale registration would leak
  // per navigation.
  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView {
    rootView
  }

  func update(with params: [String: Any]) {
    // Subclasses override to push updated state into the native view.
  }

  /// Applies the user interface style based on Flutter's isDark parameter.
  /// This ensures the native view matches Flutter's theme regardless of system settings.
  func applyUserInterfaceStyle(from params: [String: Any]) {
    // Check for isDark parameter from Flutter
    if let isDark = params["isDark"] as? Bool {
      rootView.overrideUserInterfaceStyle = isDark ? .dark : .light
    } else if let isDarkNS = params["isDark"] as? NSNumber {
      rootView.overrideUserInterfaceStyle = isDarkNS.boolValue ? .dark : .light
    }
    // If not specified, don't override (use system default)
  }

  /// Decodes a Flutter bool, which the codec bridges as either a native Bool or
  /// an NSNumber. Nil when the key is absent or holds neither.
  func boolValue(from params: [String: Any], key: String) -> Bool? {
    if let b = params[key] as? Bool { return b }
    if let n = params[key] as? NSNumber { return n.boolValue }
    return nil
  }
}
