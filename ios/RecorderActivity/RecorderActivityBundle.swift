import SwiftUI
import WidgetKit

/// The extension's entry point: one bundle, one widget - the recording
/// Live Activity. Home-screen widgets, if they ever exist, join here.
@main
struct RecorderActivityBundle: WidgetBundle {
  var body: some Widget {
    RecorderActivityLiveActivity()
  }
}
