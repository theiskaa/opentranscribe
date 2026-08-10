import SwiftUI
import WidgetKit

/// The extension's entry point. The control is gated rather than the bundle:
/// controls are iOS 18 and the deployment target is 17, and the builder's
/// limited-availability branch lets the Live Activity keep serving iOS 17.
@main
struct RecorderActivityBundle: WidgetBundle {
  var body: some Widget {
    RecorderActivityLiveActivity()
    if #available(iOS 18.0, *) {
      RecordControl()
    }
  }
}
