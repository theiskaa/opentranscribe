import Flutter
import UIKit
import transcriber

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // A killed process leaves its recording activity ticking on the island
    // over a closed microphone; sweep the leftovers before anything else.
    RecordingLiveActivityController.shared.sweep()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)
    // The island mirrors capture state; the plugin fires this after Dart.
    TranscriberPlugin.recordingStatusObserver = { status in
      RecordingLiveActivityController.shared.handle(status)
    }
    if let registrar = registry.registrar(forPlugin: "NotificationsPlugin") {
      NotificationsPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "StorageKeyPlugin") {
      StorageKeyPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "ShareExportPlugin") {
      ShareExportPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "SplashHandoffPlugin") {
      SplashHandoffPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "IntentActionsPlugin") {
      IntentActionsPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "SupportStorePlugin") {
      SupportStorePlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "ThermalMonitorPlugin") {
      ThermalMonitorPlugin.register(with: registrar)
    }
  }
}
