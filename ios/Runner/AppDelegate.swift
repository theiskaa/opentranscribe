import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // A killed process leaves its recording activity ticking on the island
    // over a closed microphone; sweep the leftovers before anything else.
    if #available(iOS 16.2, *) {
      RecordingLiveActivityController.shared.sweep()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)
    if let registrar = registry.registrar(forPlugin: "AudioRecorderPlugin") {
      AudioRecorderPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "SpeechEnginePlugin") {
      SpeechEnginePlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "AudioPlayerPlugin") {
      AudioPlayerPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "ReflectionEnginePlugin") {
      ReflectionEnginePlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "NotificationsPlugin") {
      NotificationsPlugin.register(with: registrar)
    }
  }
}
