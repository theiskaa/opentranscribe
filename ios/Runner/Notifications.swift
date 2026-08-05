import Flutter
import Foundation
import UserNotifications

// Local, on-device notifications behind the Dart NotificationScheduler contract.
// UNUserNotificationCenter schedules on the device: nothing is sent to a server,
// no network is touched, and airplane mode is unaffected. Title and body arrive
// generic from Dart and never carry reflection text.
final class NotificationsPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    // Channel name + payload shapes: must match notification_scheduler.dart.
    let channel = FlutterMethodChannel(
      name: "opentranscribe/notify", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NotificationsPlugin(), channel: channel)
  }

  private var center: UNUserNotificationCenter { .current() }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      requestPermission(result)
    case "authorizationStatus":
      authorizationStatus(result)
    case "scheduleDaily":
      scheduleDaily(call.arguments, result)
    case "scheduleWeekly":
      scheduleWeekly(call.arguments, result)
    case "scheduleMonthly":
      scheduleMonthly(call.arguments, result)
    case "cancel":
      cancel(call.arguments, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      DispatchQueue.main.async { result(granted) }
    }
  }

  private func authorizationStatus(_ result: @escaping FlutterResult) {
    center.getNotificationSettings { settings in
      let status: String
      switch settings.authorizationStatus {
      case .authorized: status = "authorized"
      case .provisional: status = "provisional"
      case .ephemeral: status = "ephemeral"
      case .denied: status = "denied"
      case .notDetermined: status = "notDetermined"
      @unknown default: status = "notDetermined"
      }
      DispatchQueue.main.async { result(status) }
    }
  }

  private func scheduleDaily(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
      let identifier = args["identifier"] as? String,
      let hour = args["hour"] as? Int,
      let minute = args["minute"] as? Int,
      let title = args["title"] as? String,
      let body = args["body"] as? String
    else {
      result(FlutterError(code: "bad_args", message: "scheduleDaily: missing arguments", details: nil))
      return
    }

    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    schedule(identifier: identifier, matching: components, title: title, body: body, result: result)
  }

  private func scheduleWeekly(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
      let identifier = args["identifier"] as? String,
      let weekday = args["weekday"] as? Int,
      let hour = args["hour"] as? Int,
      let minute = args["minute"] as? Int,
      let title = args["title"] as? String,
      let body = args["body"] as? String
    else {
      result(FlutterError(code: "bad_args", message: "scheduleWeekly: missing arguments", details: nil))
      return
    }

    var components = DateComponents()
    // Dart weekday is 1=Mon..7=Sun; UNCalendar wants 1=Sun..7=Sat.
    components.weekday = weekday == 7 ? 1 : weekday + 1
    components.hour = hour
    components.minute = minute
    schedule(identifier: identifier, matching: components, title: title, body: body, result: result)
  }

  private func scheduleMonthly(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
      let identifier = args["identifier"] as? String,
      let day = args["day"] as? Int,
      let hour = args["hour"] as? Int,
      let minute = args["minute"] as? Int,
      let title = args["title"] as? String,
      let body = args["body"] as? String
    else {
      result(FlutterError(code: "bad_args", message: "scheduleMonthly: missing arguments", details: nil))
      return
    }

    var components = DateComponents()
    components.day = day
    components.hour = hour
    components.minute = minute
    schedule(identifier: identifier, matching: components, title: title, body: body, result: result)
  }

  private func schedule(
    identifier: String, matching components: DateComponents,
    title: String, body: String, result: @escaping FlutterResult
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

    // Remove the pending request first so a reschedule is idempotent: the same
    // identifier never stacks a second notification.
    center.removePendingNotificationRequests(withIdentifiers: [identifier])
    center.add(request) { error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(code: "schedule_failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }

  private func cancel(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any], let identifier = args["identifier"] as? String
    else {
      result(FlutterError(code: "bad_args", message: "cancel: missing identifier", details: nil))
      return
    }
    center.removePendingNotificationRequests(withIdentifiers: [identifier])
    result(nil)
  }
}
