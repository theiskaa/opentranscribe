import AppIntents

/// Starts a take from anywhere the system offers this app's actions: the lock
/// screen control, Control Center, the Action button, Shortcuts, Siri.
///
/// iOS refuses to activate a record session from the background, so a take can
/// only begin in the foreground. The intent therefore opens the app, which from
/// the lock screen means the phone authenticates first, and which is why
/// [perform] only ever runs in the app's process and never in the extension's.
struct StartRecordingIntent: AppIntent {
  static var title: LocalizedStringResource = "Record"

  /// Optional to match the protocol requirement: a non-optional witness does
  /// not satisfy it, and the framework's nil default wins instead.
  static var description: IntentDescription? = IntentDescription("Start a new recording.")

  /// `supportedModes` supersedes this on iOS 26, but it cannot be declared
  /// conditionally on one type, so it stays until the deployment target moves.
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    PendingRecordingAction.shared.submit(.start)
    return .result()
  }
}
