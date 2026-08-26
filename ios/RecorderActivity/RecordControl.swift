import AppIntents
import SwiftUI
import WidgetKit

/// The lock screen's corner slot, Control Center, and the Action button, from
/// one declaration.
///
/// A button and not a toggle: a toggle would have to answer "am I recording"
/// from this process, which has no access to the app's state.
@available(iOS 18.0, *)
struct RecordControl: ControlWidget {
  /// Permanent. A changed kind drops the control out of every corner, Control
  /// Center and Action button someone has already put it in.
  private static let kind = "xyz.opentranscribe.record"

  /// Literals at the API boundary, kept in the form the gallery was seen
  /// rendering: the gallery caches a control's preview hard, so any change here
  /// costs a reinstall to retest against a blank tile.
  ///
  /// The name is the action, not the app: the gallery already groups controls
  /// under the app's own name and icon, so repeating it there says nothing and
  /// wraps mid-word under the tile. "wave" is the symbolset in this target's
  /// catalog, and it has to be a symbol at all because a control draws symbol
  /// images only, showing a plain image asset as nothing.
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Self.kind) {
      ControlWidgetButton(action: StartRecordingIntent()) {
        Label("New entry", image: "wave")
      }
    }
    .displayName("New entry")
  }
}
