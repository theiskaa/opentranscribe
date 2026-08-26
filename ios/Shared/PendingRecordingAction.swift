import Foundation

/// What a system surface asked the recorder to do. Compiled into both the app
/// and the RecorderActivity extension, because the intent that carries it is.
enum RecordingAction: String {
  case start
}

extension RecordingAction {
  /// The widget row's way in: the action travels as a URL and the app decodes
  /// it back. Why a link rather than a button is stated at the widget.
  static let scheme = "opentranscribe"

  var url: URL? { URL(string: "\(Self.scheme)://\(rawValue)") }

  /// Accepts exactly the URLs [url] mints: nothing after the host.
  init?(url: URL) {
    guard url.scheme == Self.scheme, let host = url.host, url.path.isEmpty, url.query == nil,
      url.fragment == nil, url.port == nil
    else { return nil }
    self.init(rawValue: host)
  }
}

/// The one hop between a system surface and Dart.
///
/// An intent cannot reach the Flutter engine, and on a cold launch it runs
/// before the engine exists, so it drops its action here and returns. The app
/// drains the slot once Dart is listening. [didChange] only wakes a consumer
/// that is already running, so it must register for it before its first [take]:
/// a submission landing in between posts to nobody and waits for the next
/// drain.
///
/// In-process state on purpose: everything that writes here already runs in the
/// app's process, an `OpenIntent`'s `perform` or the app's own URL handler.
/// Nothing needs an App Group, and a process that dies with an undrained action
/// replays nothing at next launch.
final class PendingRecordingAction {
  static let shared = PendingRecordingAction()

  /// Posted on the main queue after an action lands. Advisory: every consumer
  /// reads through [take], so a post racing a drain cannot deliver twice.
  static let didChange = Notification.Name("opentranscribe.pendingRecordingAction")

  /// An action the app never got to is dropped rather than acted on. A tap that
  /// died in a failed launch must not open the microphone on some unrelated
  /// launch hours later. The window clears the worst honest cold launch:
  /// process start, `Deps.init()`'s 8s ceiling, and the first frames.
  private static let freshness: TimeInterval = 30

  private let lock = NSLock()
  private var action: RecordingAction?
  private var submittedAt: Date?

  private init() {}

  /// Replaces whatever was waiting: the newest tap is what was last asked for.
  func submit(_ action: RecordingAction) {
    // Logged, never trapped: this process also renders the Live Activity, and a
    // debug build that crashes it on every tap can leave the banner replaced by
    // the system's failed-widget placeholder. `StartRecordingIntent` is an
    // OpenIntent, so the framework performs it in the app; this says so out loud
    // if that ever stops holding.
    if Bundle.main.bundleURL.pathExtension == "appex" {
      NSLog("PendingRecordingAction: submitted in an extension, whose slot nothing drains")
    }
    lock.lock()
    self.action = action
    submittedAt = Date()
    lock.unlock()
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
  }

  /// Clears the slot either way, and refuses anything past [freshness].
  func take() -> RecordingAction? {
    lock.lock()
    defer {
      action = nil
      submittedAt = nil
      lock.unlock()
    }
    guard let submittedAt, Date().timeIntervalSince(submittedAt) <= Self.freshness else {
      return nil
    }
    return action
  }
}
