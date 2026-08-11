import AppIntents
import SwiftUI
import WidgetKit

/// The lock screen's widget row, under the clock: the wave, and a tap that
/// records. The row's other home on iOS 26 is the bottom of the screen, just
/// above the corner controls, so this and the control can sit together.
///
/// Action only, and that is a decision rather than an omission. Showing today's
/// count or the last entry's title would need an App Group and journal-derived
/// text written outside the encrypted store, in a second process; a link needs
/// neither. No `description` either: with accessory-only families the widget
/// never reaches the gallery that renders one.
struct RecordWidget: Widget {
  /// Permanent. WidgetKit matches placed instances by kind, so changing it
  /// empties every lock screen slot someone has already configured.
  private static let kind = "xyz.opentranscribe.newEntry"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: RecordProvider()) { _ in
      RecordWidgetView()
    }
    .configurationDisplayName("New entry")
    .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    // The accessory row is tight enough that the system's margins cost a line of
    // the rectangular face. The whole widget is the link either way.
    .contentMarginsDisabled()
  }
}

private struct RecordEntry: TimelineEntry {
  let date: Date
}

/// One entry, never refreshed: with no data on the face there is nothing a later
/// timeline could say differently.
private struct RecordProvider: TimelineProvider {
  func placeholder(in context: Context) -> RecordEntry {
    RecordEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (RecordEntry) -> Void) {
    completion(RecordEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RecordEntry>) -> Void) {
    completion(Timeline(entries: [RecordEntry(date: Date())], policy: .never))
  }
}

private struct RecordWidgetView: View {
  @Environment(\.widgetFamily) private var family

  /// A link, not a `Button(intent:)`. A widget's buttons and toggles are inert on
  /// a locked device until someone unlocks it, and the lock screen is the only
  /// place this widget lives, so a button here is a tap that does nothing. The
  /// framework's answer for an interaction whose job is to open the app is
  /// `widgetURL`, and the app turns that URL back into the action.
  var body: some View {
    face
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityLabel("New entry")
      // Required, including for accessory families: a widget that never adopts it
      // renders as the system's "Please adopt containerBackground API" placeholder,
      // whose own tap opens Apple's documentation instead of this app. Clear
      // because the circular face draws its own well and the rectangular face
      // deliberately has none.
      .containerBackground(.clear, for: .widget)
      .widgetURL(RecordingAction.start.url)
  }

  /// The rectangular slot is 160 by 72 and shares the row with other widgets, so
  /// it carries no well: a filled card there reads as a floating panel next to
  /// the system's own transparent rows. Two short lines and a small mark are what
  /// fits; anything larger wraps, which is what "New entry" did at subheadline.
  ///
  /// The circular slot is the opposite case, a well the system expects something
  /// to sit in, and the mark alone is the whole of it.
  @ViewBuilder private var face: some View {
    switch family {
    case .accessoryRectangular:
      HStack(spacing: 8) {
        Image("wave").font(.system(size: 22))
        VStack(alignment: .leading, spacing: 0) {
          Text("New entry").font(.footnote.weight(.semibold))
          Text("Tap to record").font(.caption2).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    default:
      ZStack {
        AccessoryWidgetBackground()
        Image("wave").font(.system(size: 32))
      }
    }
  }
}
