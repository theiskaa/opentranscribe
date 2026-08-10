import AppIntents
import SwiftUI
import WidgetKit

/// The lock screen's corner slot, Control Center, and the Action button, from
/// one declaration.
///
/// A button and not a toggle: a toggle would have to answer "am I recording"
/// from this process, which has no access to the app's state, and the Live
/// Activity already shows that where the user is looking.
@available(iOS 18.0, *)
struct RecordControl: ControlWidget {
  /// Permanent. A changed kind drops the control out of every corner, Control
  /// Center and Action button someone has already put it in.
  private static let kind = "xyz.opentranscribe.record"

  /// Names the action, not the app: the gallery already groups controls under
  /// the app's own name and icon, so repeating it there says nothing and wraps
  /// mid-word in the slot's label.
  private static let name = "New entry"

  /// Must match the symbolset in this target's asset catalog; a rename fails
  /// silently, as an empty circle. A control draws symbol images only and shows
  /// a plain image asset as nothing, which is why the wave ships as a symbol.
  private static let symbol = "wave"

  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Self.kind) {
      ControlWidgetButton(action: StartRecordingIntent()) {
        Label(Self.name, image: Self.symbol)
      }
    }
    .displayName(LocalizedStringResource(stringLiteral: Self.name))
  }
}
