import AVFoundation
import Flutter
import Speech

// Apple Speech behind the Dart TranscriptionEngine contract. Live: attaches to the
// shared capture session as a consumer, feeding buffers to an on-device recognition
// request and streaming TranscriptEvents back over an EventChannel. Batch:
// transcribes a kept file. On-device only; it never uses a server recognizer.

/// Channel error codes. This set is the cross-boundary contract with
/// apple_speech_engine.dart; keep them in sync.
private enum SpeechErrorCode: String {
  case permissionDenied = "permission_denied"
  case onDeviceUnavailable = "on_device_unavailable"
  case fileMissing = "file_missing"
  case transcribeError = "transcribe_error"
  case badArgs = "bad_args"

  /// The channel error for this code.
  func error(_ message: String) -> FlutterError {
    FlutterError(code: rawValue, message: message, details: nil)
  }
}

/// The outcome of resolving a recognizer: ready, or the reason it is not.
private enum RecognizerResolution {
  case ready(SFSpeechRecognizer)
  case denied
  case unavailable

  /// The failure code and message, or nil when ready. Keeps the code/message
  /// pairs (a cross-boundary contract) in one place.
  var failure: (code: SpeechErrorCode, message: String)? {
    switch self {
    case .ready: return nil
    case .denied: return (.permissionDenied, "speech recognition not authorized")
    case .unavailable: return (.onDeviceUnavailable, "on-device recognition unavailable")
    }
  }
}

/// An available on-device recognizer for the locale, or nil. The on-device guard is
/// the non-negotiable rule: refuse rather than fall back to a server recognizer.
private func onDeviceRecognizer(_ localeId: String) -> SFSpeechRecognizer? {
  guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId)),
    recognizer.isAvailable, recognizer.supportsOnDeviceRecognition
  else { return nil }
  return recognizer
}

/// Ensures speech-recognition authorization (requesting it once if undecided) and
/// resolves an on-device recognizer, always calling back on the main thread.
private func resolveRecognizer(
  _ localeId: String, _ completion: @escaping (RecognizerResolution) -> Void
) {
  let deliver: (RecognizerResolution) -> Void = { resolution in
    DispatchQueue.main.async { completion(resolution) }
  }
  let finish: (SFSpeechRecognizerAuthorizationStatus) -> Void = { status in
    switch status {
    case .authorized:
      if let recognizer = onDeviceRecognizer(localeId) {
        deliver(.ready(recognizer))
      } else {
        deliver(.unavailable)
      }
    default:
      deliver(.denied)
    }
  }
  let status = SFSpeechRecognizer.authorizationStatus()
  if status == .notDetermined {
    SFSpeechRecognizer.requestAuthorization(finish)
  } else {
    finish(status)
  }
}

private func segments(from transcription: SFTranscription) -> [[String: Any]] {
  transcription.segments.map { segment in
    [
      "text": segment.substring,
      "startMs": Int(segment.timestamp * 1000),
      "endMs": Int((segment.timestamp + segment.duration) * 1000),
      "confidence": Double(segment.confidence),
    ]
  }
}

final class SpeechEnginePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  // Guards live state shared between the EventChannel/recognition callbacks and the
  // realtime tap thread that calls the buffer consumer.
  private let lock = NSLock()
  private var liveRequest: SFSpeechAudioBufferRecognitionRequest?
  private var liveTask: SFSpeechRecognitionTask?
  private var consumerToken: Int?
  // Bumped on every start/stop (main-thread only). A pending async resolve compares
  // against it and abandons itself if it was superseded, so a cancel racing the
  // resolve cannot leave an orphaned consumer/task with no teardown path.
  private var liveGeneration = 0

  // Batch tasks are retained by id so overlapping calls do not drop each other.
  private var batchTasks: [Int: SFSpeechRecognitionTask] = [:]
  private var nextBatchId = 0

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SpeechEnginePlugin()
    // Channel names + payload shapes — must match apple_speech_engine.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/speech", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "opentranscribe/speech/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    registrar.addMethodCallDelegate(instance, channel: methods)
  }

  // Live recognition is tied to the Dart subscription: onListen starts it (so the
  // sink is set before any partial), onCancel tears it down.
  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self.eventSink = eventSink
    let localeId = (arguments as? [String: Any])?["localeId"] as? String ?? "en-US"
    startLive(localeId: localeId)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopLive()
    eventSink = nil
    return nil
  }

  private func emit(_ payload: [String: Any]) {
    DispatchQueue.main.async { self.eventSink?(payload) }
  }

  private func emitError(_ code: SpeechErrorCode, _ message: String) {
    emit(["type": "error", "code": code.rawValue, "message": message])
  }

  private func startLive(localeId: String) {
    // Re-entrancy guard: a new live session tears down any previous one first.
    stopLive()
    // The classic buffer recognizer does not run on the simulator and is superseded
    // by SpeechAnalyzer on iOS 26. Real-time UI streaming via SpeechAnalyzer is a
    // follow-up; the settled transcript comes from the batch pass regardless, so we
    // simply do not stream live on iOS 26 rather than surface a recognizer error.
    if #available(iOS 26.0, *) { return }
    liveGeneration += 1
    let generation = liveGeneration
    resolveRecognizer(localeId) { [weak self] resolution in
      guard let self = self else { return }
      // Abandon if a stop or a newer start superseded this resolve while it ran.
      guard generation == self.liveGeneration else { return }
      switch resolution {
      case .ready(let recognizer):
        self.beginLive(recognizer: recognizer)
      case .denied, .unavailable:
        if let failure = resolution.failure { self.emitError(failure.code, failure.message) }
      }
    }
  }

  private func beginLive(recognizer: SFSpeechRecognizer) {
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true

    let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self = self else { return }
      if let result = result {
        var payload: [String: Any] = [
          "text": result.bestTranscription.formattedString,
          "isFinal": result.isFinal,
        ]
        if result.isFinal { payload["segments"] = segments(from: result.bestTranscription) }
        self.emit(payload)
      }
      if let error = error {
        self.emitError(.transcribeError, error.localizedDescription)
      }
    }

    // Attach to the shared capture session: feed its buffers, finalize on stop.
    let token = CaptureHub.session.addConsumer(
      onBuffer: { [weak self] buffer in
        self?.lock.lock()
        let request = self?.liveRequest
        self?.lock.unlock()
        request?.append(buffer)
      },
      onStop: { [weak self] in
        self?.lock.lock()
        let request = self?.liveRequest
        self?.lock.unlock()
        request?.endAudio()
      }
    )

    lock.lock()
    liveRequest = request
    liveTask = task
    consumerToken = token
    lock.unlock()
  }

  private func stopLive() {
    liveGeneration += 1
    lock.lock()
    let token = consumerToken
    let request = liveRequest
    let task = liveTask
    consumerToken = nil
    liveRequest = nil
    liveTask = nil
    lock.unlock()

    if let token = token { CaptureHub.session.removeConsumer(token) }
    request?.endAudio()
    task?.cancel()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkAvailability":
      let localeId = (call.arguments as? [String: Any])?["localeId"] as? String ?? "en-US"
      resolveRecognizer(localeId) { resolution in
        result(["status": resolution.failure?.code.rawValue ?? "available"])
      }
    case "transcribeFile":
      guard let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(SpeechErrorCode.badArgs.error("path required"))
        return
      }
      let localeId = args["localeId"] as? String ?? "en-US"
      transcribeFile(path: path, localeId: localeId, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Picks the batch strategy: the simulator has no model, iOS 26 uses SpeechAnalyzer,
  /// older iOS uses the classic recognizer.
  private func transcribeFile(path: String, localeId: String, result: @escaping FlutterResult) {
    guard FileManager.default.fileExists(atPath: path) else {
      result(SpeechErrorCode.fileMissing.error(path))
      return
    }
    #if targetEnvironment(simulator)
      // The simulator ships no on-device speech model, so transcription cannot run
      // here. Fail fast instead of hanging on a model download that never completes.
      result(SpeechErrorCode.onDeviceUnavailable.error("on-device speech is unavailable on the simulator"))
    #else
      if #available(iOS 26.0, *) {
        transcribeFileWithAnalyzer(path: path, localeId: localeId, result: result)
      } else {
        transcribeFileClassic(path: path, localeId: localeId, result: result)
      }
    #endif
  }

  /// Classic (pre-iOS-26) on-device batch: SFSpeechURLRecognitionRequest.
  private func transcribeFileClassic(
    path: String, localeId: String, result: @escaping FlutterResult
  ) {
    resolveRecognizer(localeId) { [weak self] resolution in
      guard let self = self else { return }
      let recognizer: SFSpeechRecognizer
      switch resolution {
      case .ready(let value):
        recognizer = value
      case .denied, .unavailable:
        if let failure = resolution.failure { result(failure.code.error(failure.message)) }
        return
      }

      let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: path))
      request.requiresOnDeviceRecognition = true
      request.shouldReportPartialResults = false

      // Reply at most once, on the main thread, and remove the retained task under
      // the lock (the completion runs on Speech's queue, not main).
      self.lock.lock()
      let id = self.nextBatchId
      self.nextBatchId += 1
      var replied = false
      let reply: (Any) -> Void = { value in
        self.lock.lock()
        if replied {
          self.lock.unlock()
          return
        }
        replied = true
        self.batchTasks.removeValue(forKey: id)
        self.lock.unlock()
        DispatchQueue.main.async { result(value) }
      }
      let task = recognizer.recognitionTask(with: request) { recognitionResult, error in
        if let error = error {
          reply(SpeechErrorCode.transcribeError.error(error.localizedDescription))
          return
        }
        guard let recognitionResult = recognitionResult, recognitionResult.isFinal else { return }
        reply([
          "text": recognitionResult.bestTranscription.formattedString,
          "segments": segments(from: recognitionResult.bestTranscription),
        ])
      }
      self.batchTasks[id] = task
      self.lock.unlock()
    }
  }

  /// iOS 26 on-device batch transcription with SpeechAnalyzer. Works where the
  /// classic recognizer will not (e.g. the simulator). The first call for a locale
  /// downloads Apple's on-device model once (this needs the network that one time,
  /// the single dent in the airplane-mode promise); after that it runs fully offline.
  @available(iOS 26.0, *)
  private func transcribeFileWithAnalyzer(
    path: String, localeId: String, result: @escaping FlutterResult
  ) {
    let url = URL(fileURLWithPath: path)
    let locale = Locale(identifier: localeId)
    Task {
      func reply(_ value: Any) { DispatchQueue.main.async { result(value) } }
      // Consumes transcriber.results; cancelled on any failure so it does not hang
      // awaiting a results stream that never finalizes.
      var collected: Task<String, Error>?
      do {
        let authorized = await withCheckedContinuation { continuation in
          SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard authorized == .authorized else {
          reply(SpeechErrorCode.permissionDenied.error("speech recognition not authorized"))
          return
        }

        // supportedLocales is empty on the simulator, so we do not gate on it. Try to
        // install the model for the requested locale directly; if no asset exists the
        // download or the analysis below surfaces the real error.
        let transcriber = SpeechTranscriber(
          locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        // Reserve (subscribe) the locale asset first, else the install status check
        // fails with "not subscribed to transcription.<lang>". Best-effort: a repeat
        // reservation is harmless.
        try? await AssetInventory.reserve(locale: locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
          try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: url)

        let collector = Task { () -> String in
          var text = AttributedString()
          for try await item in transcriber.results where item.isFinal {
            text.append(item.text)
          }
          return String(text.characters)
        }
        collected = collector

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
          try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
          await analyzer.cancelAndFinishNow()
        }

        let text = try await collector.value
        // SpeechAnalyzer yields text only here, so segments are intentionally empty
        // (the classic path returns timed segments; parity is a follow-up).
        reply(["text": text, "segments": [[String: Any]]()])
      } catch {
        collected?.cancel()
        reply(SpeechErrorCode.transcribeError.error("\(error)"))
      }
    }
  }
}
