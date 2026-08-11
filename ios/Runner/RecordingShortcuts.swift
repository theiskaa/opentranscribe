import AppIntents

/// The app's Siri and Spotlight phrases. App-target only: a provider compiled
/// into the widget extension as well would offer the same shortcut from two
/// bundles.
struct RecordingShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartRecordingIntent(),
      phrases: [
        "Record in \(.applicationName)",
        "Start recording in \(.applicationName)",
      ],
      shortTitle: "Record",
      systemImageName: "waveform"
    )
  }
}
