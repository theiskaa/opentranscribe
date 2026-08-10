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

  /// The one string the API forces us to have, in the gallery and to VoiceOver.
  private static let name = "OpenTranscribe"

  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Self.kind) {
      ControlWidgetButton(action: StartRecordingIntent()) {
        // Stock symbol until the wave symbolset lands in this target's asset
        // catalog; a control draws symbol images only, so it becomes `image:`.
        Label(Self.name, systemImage: "waveform")
      }
    }
    .displayName(LocalizedStringResource(stringLiteral: Self.name))
  }
}
