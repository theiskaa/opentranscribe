import Flutter
import UIKit

// Channel name and payloads must match core/app/app_icon.dart.

final class AppIconPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let methods = FlutterMethodChannel(
      name: "opentranscribe/icon", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AppIconPlugin(), channel: methods)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "current":
      result(UIApplication.shared.alternateIconName)
    case "set":
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(code: "unsupported", message: "alternate icons unavailable", details: nil))
        return
      }
      let name = (call.arguments as? [String: Any])?["name"] as? String
      UIApplication.shared.setAlternateIconName(name) { error in
        // UIKit does not promise the completion's queue; Flutter needs main.
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
