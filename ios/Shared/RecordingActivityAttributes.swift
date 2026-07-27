import ActivityKit
import Foundation

/// The recording Live Activity's contract, compiled into BOTH the app and the
/// RecorderActivity extension: ActivityKit matches the two processes by this
/// type's shape, so the one definition must be shared, never duplicated.
@available(iOS 16.2, *)
struct RecordingActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// The instant the take's clock reads zero from: now minus the time
    /// already recorded. The island's timer ticks from it SYSTEM-side
    /// (Text(timerInterval:)), so a running clock needs no updates at all.
    var startedAt: Date

    /// Recorded time banked at the last pause, shown as a static clock while
    /// [paused]; pauses never count toward the take.
    var accumulated: TimeInterval

    var paused: Bool
  }
}
