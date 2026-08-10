import Foundation

/// What a system surface asked the recorder to do. Compiled into both the app
/// and the RecorderActivity extension, because the intent that carries it is.
enum RecordingAction: String {
  case start
}

/// The one hop between an App Intent and Dart.
///
/// An intent cannot reach the Flutter engine, and on a cold launch it runs
/// before the engine exists, so it drops its action here and returns. The app
/// drains the slot once Dart is listening. [didChange] only wakes a consumer
/// that is already running, so it must register for it before its first [take]:
/// a submission landing in between posts to nobody and waits for the next
/// drain.
///
/// In-process state on purpose: the intents that write here always perform in
/// the app's process, since iOS will not start a recording from the background
/// and they therefore open the app. Nothing needs an App Group, and a process
/// that dies with an undrained action replays nothing at next launch.
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
  /// Only `.start` can ever be the one replaced, because pause and stop are
  /// submitted from the Live Activity, which exists only once a take is running,
  /// so they cannot overtake the start that made them possible.
  func submit(_ action: RecordingAction) {
    assert(
      Bundle.main.bundleURL.pathExtension != "appex",
      "An extension's slot is a different instance, and nothing drains it")
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
