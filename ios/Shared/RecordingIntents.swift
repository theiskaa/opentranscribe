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

/// What actually pins [perform] to the app's process, which
/// [PendingRecordingAction]'s in-process slot depends on. Left to itself, App
/// Intents runs a type shared with a widget extension in the app only when the
/// app is already alive, and otherwise in the extension, whose slot nothing
/// drains. `openAppWhenRun` does not change that: it foregrounds the app, it
/// does not move the work.
///
/// Compiled out of the extension, and that absence is the mechanism: the
/// extension's copy of the type must NOT carry the conformance. It has to be
/// `#if`, not `@available(iOSApplicationExtension, unavailable)`: availability
/// only makes a use diagnosable, and the conformance record still lands in the
/// extension's binary, which was verifiable in the built appex.
/// WIDGET_EXTENSION is defined by the RecorderActivity target.
///
/// `supportedModes` with `.foreground(.dynamic)` supersedes this on iOS 26, and
/// like `openAppWhenRun` it cannot be declared conditionally, so it waits for the
/// deployment target.
#if !WIDGET_EXTENSION
  extension StartRecordingIntent: ForegroundContinuableIntent {}
#endif
