import AppIntents
import SwiftUI
import WidgetKit

/// The lock screen's widget row, under the clock: the wave, and a tap that
/// records. The row's other home on iOS 26 is the bottom of the screen, just
/// above the corner controls, so this and the control can sit together.
///
/// Action only, and that is a decision rather than an omission. Showing today's
/// count or the last entry's title would need an App Group and journal-derived
/// text written outside the encrypted store, in a second process; a button needs
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
    // Without this the button owns only the content area, and a tap in the
    // margin ring falls through to the default open-the-app, which authenticates
    // and then records nothing.
    .contentMarginsDisabled()
  }
}

private struct RecordEntry: TimelineEntry {
  let date: Date
}

/// One entry, never refreshed: with no data on the face there is nothing a later
/// timeline could say differently, and a button tap reloads it anyway.
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

  var body: some View {
    Button(intent: StartRecordingIntent()) {
      ZStack {
        // The circular slot is a well the system expects something to sit in;
        // the rectangular one is not, and a backdrop there reads as a card.
        if family == .accessoryCircular {
          AccessoryWidgetBackground()
        }
        // No weight: the symbolset carries only its Regular variants, so asking
        // for a heavier one draws the same glyph and reads as a knob that works.
        Image("wave")
          .font(.system(size: family == .accessoryCircular ? 32 : 28))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("New entry")
    // Required, including for accessory families: a widget that never adopts it
    // renders as the system's "Please adopt containerBackground API" placeholder,
    // whose own tap opens Apple's documentation instead of this app. Clear
    // because the circular family draws its own well above.
    .containerBackground(.clear, for: .widget)
  }
}
