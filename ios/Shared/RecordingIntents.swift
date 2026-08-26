import AppIntents

/// Where an action lands the app. `OpenIntent` requires a target, and this app
/// offers system surfaces exactly one place to land.
enum RecorderScreen: String, AppEnum {
  case recorder

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Screen"
  static var caseDisplayRepresentations: [RecorderScreen: DisplayRepresentation] = [
    .recorder: "Recorder"
  ]
}

/// Starts a take from anywhere the system offers this app's actions: the lock
/// screen control, Control Center, the Action button, Shortcuts, Siri.
///
/// An `OpenIntent`, and every reason for that is a documented framework rule.
///
/// It performs in the app's process, which is what [PendingRecordingAction]'s
/// in-process slot depends on. A plain `AppIntent` performs wherever the system
/// ran it, and for a control or a widget that is the extension's process, whose
/// slot nothing drains.
///
/// It brings the app to the foreground to perform, which a take needs: iOS
/// refuses to activate a record session from the background, so capture can only
/// begin in the foreground, and from the lock screen that means the phone
/// authenticates first.
///
/// `openAppWhenRun` cannot do either job. The framework documents it as an error
/// when the intent runs in an app extension, and it is deprecated in favour of
/// `supportedModes`, which is iOS 26 and up. `OpenIntent` supplies it for us and
/// works back to the deployment target.
///
/// The type has to be a member of both the app and the extension target for the
/// system to open the app from a control; placing this file in Shared is what
/// gives it that.
struct StartRecordingIntent: OpenIntent {
  static var title: LocalizedStringResource = "Record"

  /// Optional to match the protocol requirement: a non-optional witness does
  /// not satisfy it, and the framework's nil default wins instead.
  static var description: IntentDescription? = IntentDescription("Start a new recording.")

  /// Carries its value from the start. A control and a widget hand the system a
  /// finished intent, and nothing on a lock screen can prompt for a parameter.
  @Parameter(title: "Screen", default: .recorder)
  var target: RecorderScreen

  func perform() async throws -> some IntentResult {
    PendingRecordingAction.shared.submit(.start)
    return .result()
  }
}
