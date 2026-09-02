import Foundation

/// Whether a file feeder must hold before appending more audio to a live
/// recognition request, which queues everything it is handed.
///
/// The recognizer reports how far it has heard only through a hypothesis
/// carrying real timings, which a take can go a whole utterance without
/// producing. So the feed stays a [window] behind where the recognizer is
/// assumed to be: its last reported position, plus [unheardSpeed] audio seconds
/// for every second since. That assumption is what keeps a silent recognizer
/// from stalling the feed for the length of the take, and extrapolating from
/// the position rather than from the clock is what stops the feed bursting
/// through the rest of the file the moment the position goes quiet.
///
/// [progress] is how far the recognizer says it has heard, 0 when it has not
/// said, and [progressAge] is how long ago that last moved.
public func feedHolds(
  fedSeconds: TimeInterval,
  progress: TimeInterval,
  progressAge: TimeInterval,
  window: TimeInterval = 30,
  unheardSpeed: TimeInterval = 4
) -> Bool {
  guard fedSeconds > window else { return false }
  return fedSeconds - (progress + progressAge * unheardSpeed) > window
}
