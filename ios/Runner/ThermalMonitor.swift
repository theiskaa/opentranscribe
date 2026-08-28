import Flutter
import Foundation

// The device's thermal state, read locally from ProcessInfo. One scalar, no
// sockets, nothing leaves the device. Dart drives it through
// core/utils/thermal.dart.

final class ThermalMonitorPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    // Channel names + payload shapes: must match thermal.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/thermal", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "opentranscribe/thermal/events", binaryMessenger: registrar.messenger())
    let plugin = ThermalMonitorPlugin()
    registrar.addMethodCallDelegate(plugin, channel: methods)
    events.setStreamHandler(plugin)
  }

  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "state":
      result(Self.encode(ProcessInfo.processInfo.thermalState))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func encode(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "nominal"
    case .fair: return "fair"
    case .serious: return "serious"
    case .critical: return "critical"
    // A state this build does not know cannot prove pressure; read it as calm
    // rather than silently pausing bulk work forever.
    @unknown default: return "nominal"
    }
  }
}

extension ThermalMonitorPlugin: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = eventSink
    // queue: .main, because the notification can arrive on any thread and the
    // sink must be called on the platform thread.
    observer = NotificationCenter.default.addObserver(
      forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.sink?(Self.encode(ProcessInfo.processInfo.thermalState))
    }
    // The current answer rides the subscription, so Dart holds a fresh cache
    // without waiting for the first change.
    eventSink(Self.encode(ProcessInfo.processInfo.thermalState))
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
    sink = nil
    return nil
  }
}
