import ActivityKit
import Foundation

/// Drives the recording Live Activity off the capture session's status
/// strings, the same choke point Dart listens to. It keeps its own
/// banked-time/anchor pair from those transitions, so it needs nothing from
/// Dart: no channel, no extra state, and it can never disagree with what the
/// capture is actually doing. Display-only by design - the island shows, the
/// app controls; the clock ticks system-side, so a running take needs no
/// updates beyond pause, resume, end, and the hour rollover.
@available(iOS 16.2, *)
final class RecordingLiveActivityController {
  static let shared = RecordingLiveActivityController()

  private var activity: Activity<RecordingActivityAttributes>?

  /// Recorded time banked at the last pause; the current run adds to it from
  /// [runStart]. Mirrors the Dart clock's anchoring, independently derived.
  private var accumulated: TimeInterval = 0
  private var runStart: Date?

  /// One push at the hour mark: the widget keeps its timer range tight (so
  /// the compact island hugs "mm:ss") and this re-render is what lets it
  /// grow to hour form. Recording keeps the process alive, so the schedule
  /// always gets to fire. Main-queue only, like everything here.
  private var hourRollover: DispatchWorkItem?

  /// ActivityKit calls chained one behind another: independent Tasks may run
  /// out of order, and a resume's update landing before the pause's would
  /// freeze the island on the wrong state.
  private var updates: Task<Void, Never>?

  private init() {}

  /// Called on the main queue from the capture status fan-out.
  func handle(_ status: String) {
    switch status {
    case "recording": begin()
    case "paused": pause()
    case "interrupted", "stopped": end()
    default: break
    }
  }

  /// A fresh take starts an activity; a resume re-anchors the running one.
  private func begin() {
    // A handle that is still on screen (active, or merely stale - stale is still
    // updatable) is re-anchored and updated, never duplicated with a new request.
    if let activity = activity, activity.activityState != .ended, activity.activityState != .dismissed {
      runStart = Date()
      push(paused: false)
      scheduleHourRollover()
      return
    }
    // No live handle. A fresh take starts the clock at zero; a resume whose
    // island the system ended (the 8h ceiling) keeps its banked time so the new
    // island resumes the real clock. End the dead handle before requesting a new
    // one so two islands never coexist.
    if let dead = activity {
      enqueue { await dead.end(nil, dismissalPolicy: .immediate) }
      activity = nil
    } else {
      accumulated = 0
    }
    runStart = Date()
    // The user toggle (Settings > OpenTranscribe > Live Activities) can be
    // off; recording proceeds without an island, never the other way around.
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let state = RecordingActivityAttributes.ContentState(
      startedAt: (runStart ?? Date()).addingTimeInterval(-accumulated),
      accumulated: accumulated, paused: false)
    activity = try? Activity.request(
      attributes: RecordingActivityAttributes(),
      content: .init(state: state, staleDate: nil))
    scheduleHourRollover()
  }

  private func pause() {
    hourRollover?.cancel()
    hourRollover = nil
    guard activity != nil else { return }
    if let start = runStart { accumulated += Date().timeIntervalSince(start) }
    runStart = nil
    push(paused: true)
  }

  private func scheduleHourRollover() {
    hourRollover?.cancel()
    hourRollover = nil
    guard activity != nil, let start = runStart else { return }
    let elapsed = accumulated + Date().timeIntervalSince(start)
    let remaining = 60 * 60 - elapsed
    guard remaining > 0 else { return }
    let work = DispatchWorkItem { [weak self] in
      guard let self = self, self.runStart != nil else { return }
      self.push(paused: false)
    }
    hourRollover = work
    DispatchQueue.main.asyncAfter(deadline: .now() + remaining + 1, execute: work)
  }

  private func push(paused: Bool) {
    // A system-dismissed/ended handle is not updatable; skip it rather than spin
    // no-op updates. A resume then recreates via begin().
    guard let activity = activity,
      activity.activityState == .active || activity.activityState == .stale
    else { return }
    let state = RecordingActivityAttributes.ContentState(
      // Run start minus what is already banked: the island's system-side timer
      // reads the right total from the first frame. Anchoring to runStart (not
      // now) is what keeps the hour-rollover push honest - at rollover now is an
      // hour past runStart, so a now-based anchor would reset the clock to 0.
      // While paused runStart is nil and the fallback reproduces the old value;
      // the paused widget renders the static accumulated time anyway.
      startedAt: (runStart ?? Date()).addingTimeInterval(-accumulated),
      accumulated: accumulated,
      paused: paused)
    enqueue { await activity.update(.init(state: state, staleDate: nil)) }
  }

  private func end() {
    hourRollover?.cancel()
    hourRollover = nil
    accumulated = 0
    runStart = nil
    guard let activity = activity else { return }
    self.activity = nil
    enqueue { await activity.end(nil, dismissalPolicy: .immediate) }
  }

  /// Launch-time sweep: a killed process leaves its activity on the island
  /// over a microphone that is closed. End every activity this app ever
  /// started, except one this run already owns.
  func sweep() {
    let owned = activity?.id
    enqueue {
      for stale in Activity<RecordingActivityAttributes>.activities where stale.id != owned {
        await stale.end(nil, dismissalPolicy: .immediate)
      }
    }
  }

  private func enqueue(_ op: @escaping () async -> Void) {
    let previous = updates
    updates = Task {
      await previous?.value
      await op()
    }
  }
}
