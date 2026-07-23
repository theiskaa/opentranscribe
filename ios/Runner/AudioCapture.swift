import AVFoundation
import Flutter

// Real audio capture behind the Dart `AudioRecorder` contract. One AVAudioEngine
// tap writes a kept m4a file and fans buffers out to consumers, so a streaming
// recognizer can attach to the SAME session in a later phase. This layer knows
// nothing about Speech: it captures and writes audio, nothing more.

/// Owns the capture session: engine, tap, m4a writer, and consumer fan-out.
final class AudioCaptureSession {
  private let engine = AVAudioEngine()
  private var audioFile: AVAudioFile?
  private var fileURL: URL?
  private var fileWriteError: String?
  private var startedAt: Date?
  private var isRunning = false

  // Results of the last finished capture, so stop() stays correct even when an
  // interruption already tore the session down.
  private var lastPath = ""
  private var lastDurationMs = 0
  private var lastWriteError: String?

  // Guards the file/consumer state shared with the realtime tap thread. isRunning
  // and startedAt are touched only on the main thread (start/stop/interruption all
  // hop to main), so they need no lock.
  private let lock = NSLock()
  private var consumers: [Int: Consumer] = [:]
  private var nextToken = 0

  /// A consumer of the live capture: each buffer plus the stop signal.
  private struct Consumer {
    let onBuffer: (AVAudioPCMBuffer) -> Void
    let onStop: () -> Void
  }

  /// Capture lifecycle strings sent to Dart: recording / interrupted / stopped.
  /// These strings must match _statusFrom in platform_audio_recorder.dart.
  var onStatus: ((String) -> Void)?

  /// Whether a capture is live now. Lets the plugin replay status to a late listener.
  var isCapturing: Bool { isRunning }

  enum CaptureError: LocalizedError {
    case alreadyRunning
    case noInput

    var code: String {
      switch self {
      case .alreadyRunning: return "already_running"
      case .noInput: return "no_input"
      }
    }

    var errorDescription: String? {
      switch self {
      case .alreadyRunning: return "capture already running"
      case .noInput: return "no audio input available"
      }
    }
  }

  /// Registers a consumer of buffers and the stop signal (a recognizer finalizes on
  /// stop). Returns a token to remove it. Subscriptions persist across start/stop
  /// cycles; removing them is the caller's responsibility.
  func addConsumer(
    onBuffer: @escaping (AVAudioPCMBuffer) -> Void, onStop: @escaping () -> Void
  ) -> Int {
    lock.lock()
    defer { lock.unlock() }
    let token = nextToken
    nextToken += 1
    consumers[token] = Consumer(onBuffer: onBuffer, onStop: onStop)
    return token
  }

  func removeConsumer(_ token: Int) {
    lock.lock()
    defer { lock.unlock() }
    consumers.removeValue(forKey: token)
  }

  func start() throws {
    guard !isRunning else { throw CaptureError.alreadyRunning }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth])
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw CaptureError.noInput
    }

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("otr-\(UUID().uuidString).m4a")
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: format.sampleRate,
      AVNumberOfChannelsKey: format.channelCount,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
    let file: AVAudioFile
    do {
      file = try AVAudioFile(forWriting: url, settings: settings)
    } catch {
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw error
    }

    lock.lock()
    audioFile = file
    fileURL = url
    fileWriteError = nil
    lock.unlock()

    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      guard let self = self else { return }
      self.lock.lock()
      let file = self.audioFile
      let canWrite = self.fileWriteError == nil
      let onBuffers = self.consumers.values.map { $0.onBuffer }
      self.lock.unlock()

      if let file = file, canWrite {
        do {
          try file.write(from: buffer)
        } catch {
          self.lock.lock()
          self.fileWriteError = "\(error)"
          self.lock.unlock()
          NSLog("AudioCaptureSession write error: \(error)")
        }
      }
      for onBuffer in onBuffers { onBuffer(buffer) }
    }

    engine.prepare()
    do {
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      lock.lock()
      audioFile = nil
      lock.unlock()
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw error
    }

    isRunning = true
    startedAt = Date()
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleInterruption(_:)),
      name: AVAudioSession.interruptionNotification, object: nil)
    onStatus?("recording")
  }

  struct Outcome {
    let path: String
    let durationMs: Int
    let writeError: String?
  }

  func stop() -> Outcome {
    teardown()
    onStatus?("stopped")
    lock.lock()
    defer { lock.unlock() }
    return Outcome(path: lastPath, durationMs: lastDurationMs, writeError: lastWriteError)
  }

  /// Finalizes the file and engine exactly once. Idempotent so a stop() after an
  /// interruption returns the already-captured result rather than re-running.
  /// Always called on the main thread.
  private func teardown() {
    guard isRunning else { return }
    isRunning = false

    if engine.isRunning { engine.stop() }
    engine.inputNode.removeTap(onBus: 0)

    lock.lock()
    let file = audioFile
    audioFile = nil
    lastWriteError = fileWriteError
    lastPath = fileURL?.path ?? ""
    lock.unlock()

    // Duration from encoded frames, not wall clock, so it matches the real file.
    if let file = file, file.processingFormat.sampleRate > 0 {
      lastDurationMs = Int(Double(file.length) / file.processingFormat.sampleRate * 1000)
    } else if let startedAt = startedAt {
      lastDurationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
    } else {
      lastDurationMs = 0
    }
    startedAt = nil

    lock.lock()
    let stops = consumers.values.map { $0.onStop }
    lock.unlock()
    for stop in stops { stop() }

    NotificationCenter.default.removeObserver(
      self, name: AVAudioSession.interruptionNotification, object: nil)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  @objc private func handleInterruption(_ note: Notification) {
    guard let info = note.userInfo,
      let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw), type == .began
    else { return }
    // iOS stops the engine on interruption. Finalize cleanly and end the capture,
    // preserving the kept audio up to this point. We do not auto-resume (that needs
    // a new file); the user restarts. Hop to main so this cannot race stop().
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.isRunning else { return }
      self.teardown()
      self.onStatus?("interrupted")
    }
  }
}

/// Requests and reports microphone permission. The mic grant has no "restricted"
/// state (that is a speech-authorization concept), so this only emits granted /
/// denied / undetermined.
enum AudioPermission {
  static func ensure(_ completion: @escaping (String) -> Void) {
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .granted: completion("granted")
      case .denied: completion("denied")
      case .undetermined:
        AVAudioApplication.requestRecordPermission { granted in
          DispatchQueue.main.async { completion(granted ? "granted" : "denied") }
        }
      @unknown default: completion("undetermined")
      }
    } else {
      let session = AVAudioSession.sharedInstance()
      switch session.recordPermission {
      case .granted: completion("granted")
      case .denied: completion("denied")
      case .undetermined:
        session.requestRecordPermission { granted in
          DispatchQueue.main.async { completion(granted ? "granted" : "denied") }
        }
      @unknown default: completion("undetermined")
      }
    }
  }
}

/// The one live capture session, shared so a speech engine can attach to the same
/// audio the recorder is writing. Capture stays engine-agnostic; the engine is a
/// consumer, not an owner.
enum CaptureHub {
  static let session = AudioCaptureSession()
}

/// Bridges the capture session to Dart: MethodChannel for control, EventChannel
/// for capture status.
final class AudioRecorderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let session = CaptureHub.session
  private var statusSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AudioRecorderPlugin()
    // Channel names + payload shapes — must match platform_audio_recorder.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/audio", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "opentranscribe/audio/status", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    registrar.addMethodCallDelegate(instance, channel: methods)
    instance.session.onStatus = { [weak instance] status in
      DispatchQueue.main.async { instance?.statusSink?(status) }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    statusSink = eventSink
    // Replay the live state so a listener that subscribed after start() is not stale.
    if session.isCapturing { eventSink("recording") }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    statusSink = nil
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ensurePermission":
      AudioPermission.ensure { result($0) }
    case "start":
      do {
        try session.start()
        result(nil)
      } catch let error as AudioCaptureSession.CaptureError {
        result(FlutterError(code: error.code, message: error.errorDescription, details: nil))
      } catch {
        result(FlutterError(code: "capture_failed", message: "\(error)", details: nil))
      }
    case "stop":
      let outcome = session.stop()
      if outcome.durationMs > 0 {
        // Keep the recording even if a write error truncated it: partial audio is
        // better than losing it, and it can be re-transcribed. Any write error was
        // already logged; we never fail a capture that produced audio.
        result(["path": outcome.path, "durationMs": outcome.durationMs])
      } else {
        // No audio at all (e.g. the file could not be created). This is a real failure.
        result(
          FlutterError(
            code: "capture_failed", message: outcome.writeError ?? "no audio captured",
            details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
