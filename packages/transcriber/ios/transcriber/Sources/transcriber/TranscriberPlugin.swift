import Flutter

/// The package's one registration point: the generated registrant calls this
/// and it fans out to the capture, speech, and player plugins on one registrar.
public class TranscriberPlugin: NSObject, FlutterPlugin {
  /// Capture status strings ("recording", "paused", "interrupted", "stopped"),
  /// delivered after Dart's own status sink so an observer only ever mirrors
  /// capture state. The host app sets this to drive surfaces the package must
  /// not know about, such as a Live Activity.
  public static var recordingStatusObserver: ((String) -> Void)?

  public static func register(with registrar: FlutterPluginRegistrar) {
    AudioRecorderPlugin.register(with: registrar)
    SpeechEnginePlugin.register(with: registrar)
    AudioPlayerPlugin.register(with: registrar)
  }
}
