import ActivityKit
import SwiftUI
import WidgetKit

/// The recording indicator on the Dynamic Island and the lock screen: a
/// waveform mark and a running clock, display-only (tapping opens the app).
/// The clock ticks system-side (Text(timerInterval:)) so a running take needs
/// no updates from the app; the app only speaks on pause, resume, end, and
/// once at the hour mark (see the controller's rollover push).
struct RecorderActivityLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
      LockScreenCard(state: context.state)
    } dynamicIsland: { context in
      DynamicIsland {
        // One coherent row across the island's floor: the wave, the clock as
        // the hero, and the record dot. No labels; the three marks say
        // recording better than the word did.
        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 14) {
            WaveMark(paused: context.state.paused, pointSize: 26)
            TimerText(state: context.state, fit: .hero)
              .font(.system(size: 34, weight: .light).monospacedDigit())
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
            RecordDot(paused: context.state.paused, diameter: 10)
          }
          .padding(.horizontal, 6)
          .padding(.top, 8)
          .padding(.bottom, 2)
        }
      } compactLeading: {
        WaveMark(paused: context.state.paused, pointSize: 17)
      } compactTrailing: {
        TimerText(state: context.state, fit: .compact)
          .font(.callout.weight(.medium).monospacedDigit())
          .foregroundStyle(.white)
      } minimal: {
        WaveMark(paused: context.state.paused, pointSize: 15)
      }
    }
  }
}

/// The lock-screen banner: wave, state, clock, dot - the island's expanded
/// row with room to name the app.
private struct LockScreenCard: View {
  let state: RecordingActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: 14) {
      WaveMark(paused: state.paused, pointSize: 26)
      VStack(alignment: .leading, spacing: 2) {
        Text("OpenTranscribe")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(state.paused ? "Paused" : "Recording")
          .font(.headline)
      }
      Spacer()
      TimerText(state: state, fit: .hero)
        .font(.title2.weight(.medium).monospacedDigit())
      RecordDot(paused: state.paused, diameter: 9)
    }
    .padding(16)
  }
}

/// The waveform mark: the app's recording glyph, full white while capturing,
/// receding to secondary when paused.
private struct WaveMark: View {
  let paused: Bool
  let pointSize: CGFloat

  var body: some View {
    Image(systemName: "waveform")
      .font(.system(size: pointSize, weight: .semibold))
      .foregroundStyle(paused ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
  }
}

/// The record dot: red while capturing, secondary while paused. The one
/// piece of color on the surface, spent on what it means.
private struct RecordDot: View {
  let paused: Bool
  let diameter: CGFloat

  var body: some View {
    Circle()
      .fill(paused ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
      .frame(width: diameter, height: diameter)
  }
}

/// How much room the clock may claim; Text(timerInterval:) reserves the width
/// of the WIDEST string its range can produce, so the range must stay tight.
private enum TimerFit {
  case compact
  case hero
}

/// The take's clock: system-ticking from [startedAt] while running, a static
/// reading of [accumulated] while paused. The running range is capped at the
/// hour so the compact island hugs "mm:ss" instead of reserving "23:59:59";
/// the controller pushes once at the hour mark, after which the range (and
/// the reserved width) grows to fit real hours.
private struct TimerText: View {
  let state: RecordingActivityAttributes.ContentState
  let fit: TimerFit

  var body: some View {
    let longForm = Date().timeIntervalSince(state.startedAt) >= 3590
    let text: Text
    if state.paused {
      text = Text(Self.clock(state.accumulated))
    } else {
      let bound: TimeInterval = longForm ? 24 * 60 * 60 : 60 * 60
      text = Text(
        timerInterval: state.startedAt...state.startedAt.addingTimeInterval(bound),
        countsDown: false
      )
    }
    return
      text
      .multilineTextAlignment(fit == .compact ? .trailing : .center)
      .frame(width: fit == .compact ? (longForm ? 66 : 44) : nil)
      .minimumScaleFactor(0.7)
  }

  private static func clock(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    return hours > 0
      ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
      : String(format: "%d:%02d", minutes, seconds)
  }
}
