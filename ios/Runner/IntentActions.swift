import Flutter
import Foundation
import UIKit

/// Hands actions submitted by an App Intent to Dart, behind the Dart
/// IntentActions contract.
///
/// Two paths for two cases. A cold launch performs the intent long before Dart
/// exists, so that action stays in the slot until Dart asks for it
/// (`takePending`). An app that is already listening is pushed the action over
/// the event channel. Both read through `PendingRecordingAction.take()`, which
/// clears under a lock, so a tap cannot arrive twice.
final class IntentActionsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = IntentActionsPlugin()
    // Channel names + payload shapes: must match intent_actions.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/intents", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: methods)
    let events = FlutterEventChannel(
      name: "opentranscribe/intents/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(plugin)
  }

  private var sink: FlutterEventSink?

  override init() {
    super.init()
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(pendingChanged),
      name: PendingRecordingAction.didChange, object: nil)
    center.addObserver(
      self, selector: #selector(becameActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(enteredBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "takePending":
      // Same active-only rule as `flush`, and it cannot be assumed here: Dart
      // drains once the first frames are up, which is not a lifecycle event, so
      // it can land on an app that is foreground but inactive (a pulled-down
      // shade, the switcher, a call banner).
      guard UIApplication.shared.applicationState == .active else {
        result(nil)
        return
      }
      result(PendingRecordingAction.shared.take()?.rawValue)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError?
  {
    sink = eventSink
    // A tap that arrived while nothing was listening is served the moment
    // something is, rather than waiting for the next notification.
    flush()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  @objc private func pendingChanged() { flush() }

  @objc private func becameActive() { flush() }

  /// An action nobody drained is dropped here rather than carried into the next
  /// foreground: the microphone must not open on a launch the user did not ask
  /// to record in. A tap on an already-backgrounded app has no transition to
  /// catch it, so an abandoned authentication leaves it to age out of the slot
  /// instead, which is the honest reading: the user did ask to record, seconds
  /// ago.
  @objc private func enteredBackground() {
    _ = PendingRecordingAction.shared.take()
  }

  /// Active only, never merely foreground. `openAppWhenRun` performs the intent
  /// during the transition, and a start attempted before the app is active hits
  /// the refusal iOS gives a background recorder. Leaving the action in the slot
  /// costs nothing: becoming active flushes it.
  private func flush() {
    guard let sink else { return }
    guard UIApplication.shared.applicationState == .active else { return }
    guard let action = PendingRecordingAction.shared.take() else { return }
    sink(action.rawValue)
  }
}
