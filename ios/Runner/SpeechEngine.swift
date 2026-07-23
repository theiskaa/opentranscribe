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
  case modelInstallFailed = "model_install_failed"
  case badArgs = "bad_args"

  /// The channel error for this code.
  func error(_ message: String) -> FlutterError {
    FlutterError(code: rawValue, message: message, details: nil)
  }
}

/// The in-stream error envelope, built in one place so the live paths and the
/// install stream cannot drift on its shape.
private func errorPayload(_ code: SpeechErrorCode, _ message: String) -> [String: Any] {
  ["type": "error", "code": code.rawValue, "message": message]
}

/// The one spelling of the denial message, shared by the classic resolver and the
/// two SpeechAnalyzer paths that check authorization directly.
private let speechNotAuthorizedMessage = "speech recognition not authorized"

/// The outcome of resolving a recognizer: ready, or the failing code/message pair.
private enum RecognizerResolution {
  case ready(SFSpeechRecognizer)
  case failed(SpeechErrorCode, String)

  /// The failure pair, or nil when ready. Convenience for the availability probe.
  var failure: (code: SpeechErrorCode, message: String)? {
    switch self {
    case .ready: return nil
    case .failed(let code, let message): return (code, message)
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
        deliver(.failed(.onDeviceUnavailable, "on-device recognition unavailable"))
      }
    default:
      deliver(.failed(.permissionDenied, speechNotAuthorizedMessage))
    }
  }
  let status = SFSpeechRecognizer.authorizationStatus()
  if status == .notDetermined {
    SFSpeechRecognizer.requestAuthorization(finish)
  } else {
    finish(status)
  }
}

/// A plain `String` view of an attributed transcript.
@available(iOS 15.0, *)
private extension AttributedString {
  var plainText: String { String(characters) }
}

/// Timed segments from the classic SFTranscription (pre-iOS-26). Carries per-segment
/// confidence, which the SpeechAnalyzer path ([analyzerSegments]) cannot. Same
/// defensive conversion as the analyzer path: a corrupt timestamp is skipped, never
/// allowed to trap the process.
private func segments(from transcription: SFTranscription) -> [[String: Any]] {
  transcription.segments.compactMap { segment in
    let start = segment.timestamp
    let end = segment.timestamp + segment.duration
    guard start.isFinite, end.isFinite, start >= 0, end >= start,
      let startMs = Int(exactly: (start * 1000).rounded()),
      let endMs = Int(exactly: (end * 1000).rounded())
    else { return nil }
    return [
      "text": segment.substring,
      "startMs": startMs,
      "endMs": endMs,
      "confidence": Double(segment.confidence),
    ]
  }
}

/// Timed segments from a SpeechAnalyzer result. With `attributeOptions:
/// [.audioTimeRange]`, each attributed run carries an `audioTimeRange`; map each to a
/// `{text, startMs, endMs}` (no confidence: SpeechAnalyzer provides none per run).
/// These are WORD-LEVEL and do NOT tile the full text: untimed runs (whitespace) and
/// runs with a missing, non-finite, or inverted range are dropped, so concatenating
/// segment texts does not reconstruct the transcript. The persisted `fullText` comes
/// from the result text directly, never rebuilt from these.
@available(iOS 26.0, *)
private func analyzerSegments(from text: AttributedString) -> [[String: Any]] {
  var segments: [[String: Any]] = []
  for run in text.runs {
    guard let range = run.audioTimeRange else { continue }
    let start = range.start.seconds
    let end = range.end.seconds
    guard start.isFinite, end.isFinite, start >= 0, end >= start else { continue }
    // Int(exactly:) rather than Int(_:), so a corrupt but finite-and-huge CMTime is
    // skipped rather than trapping the transcribe task.
    guard let startMs = Int(exactly: (start * 1000).rounded()),
      let endMs = Int(exactly: (end * 1000).rounded())
    else { continue }
    segments.append([
      "text": String(text[run.range].characters),
      "startMs": startMs,
      "endMs": endMs,
    ])
  }
  return segments
}

/// Speech-recognition authorization as an async value (wrapping the callback API).
private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
  await withCheckedContinuation { continuation in
    SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
  }
}

/// Reserves the locale and returns the install request, or nil when the model is
/// already installed. Reserve first, else the request fails "not subscribed to
/// transcription.<lang>"; a repeat reservation is harmless. The one-time download is
/// the single dent in the airplane-mode promise; after it, transcription is offline.
@available(iOS 26.0, *)
private func reserveAndRequestInstall(_ transcriber: SpeechTranscriber, locale: Locale) async throws
  -> AssetInstallationRequest?
{
  do {
    try await AssetInventory.reserve(locale: locale)
  } catch {
    // Logged, not fatal: the install request below surfaces the attributable error.
    NSLog("AssetInventory.reserve(\(locale.identifier(.bcp47))) failed: \(error)")
  }
  return try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
}

/// Releases reservations for every locale but [locale]. AssetInventory caps how many
/// a process may hold, so repeated language switches would otherwise exhaust the cap
/// over the app's life, after which every install fails cryptically. Called ONLY from
/// the explicit install flow, never from transcribe paths, so a transcription of an
/// old entry in another locale cannot yank a reservation out from under an in-flight
/// download for the current one.
@available(iOS 26.0, *)
private func releaseOtherReservations(keeping locale: Locale) async {
  let target = locale.identifier(.bcp47)
  for reserved in await AssetInventory.reservedLocales
  where reserved.identifier(.bcp47) != target {
    await AssetInventory.release(reservedLocale: reserved)
  }
}

/// Installs the on-device model for a transcriber's locale on first use (batch/live).
@available(iOS 26.0, *)
private func installTranscriptionModel(_ transcriber: SpeechTranscriber, locale: Locale) async throws {
  if let request = try await reserveAndRequestInstall(transcriber, locale: locale) {
    try await request.downloadAndInstall()
  }
}

/// The transcriber used by both transcribing paths. Baking in `attributeOptions:
/// [.audioTimeRange]` here makes word timing a structural guarantee, so batch and live
/// cannot drift on it. [volatileResults] adds partials plus fast results, which only
/// the live path wants: SpeechAnalyzer settles text in accuracy-first waves, and
/// .fastResults tightens that cadence for the real-time UI. The small accuracy trade
/// is fine there because the persisted transcript comes from the batch pass, which
/// keeps the default (accuracy-first) reporting.
@available(iOS 26.0, *)
private func makeTimedTranscriber(locale: Locale, volatileResults: Bool = false)
  -> SpeechTranscriber
{
  SpeechTranscriber(
    locale: locale,
    transcriptionOptions: [],
    reportingOptions: volatileResults ? [.volatileResults, .fastResults] : [],
    attributeOptions: [.audioTimeRange])
}

/// Whether the on-device model for a locale is supported here (installed or
/// installable). Compared by BCP-47 so locale-identifier spelling does not matter.
@available(iOS 26.0, *)
private func modelLocaleSupported(_ localeId: String) async -> Bool {
  let target = Locale(identifier: localeId).identifier(.bcp47)
  let supported = await SpeechTranscriber.supportedLocales
  return supported.contains { $0.identifier(.bcp47) == target }
}

/// Whether the on-device model for a locale is downloaded and ready now.
@available(iOS 26.0, *)
private func modelLocaleInstalled(_ localeId: String) async -> Bool {
  let target = Locale(identifier: localeId).identifier(.bcp47)
  let installed = await SpeechTranscriber.installedLocales
  return installed.contains { $0.identifier(.bcp47) == target }
}

/// iOS 26 live transcription with SpeechAnalyzer. Attaches to the shared capture
/// session, converts each buffer to the analyzer's format, and streams volatile
/// (partial) then finalized text back as TranscriptEvents. On-device only. Live is
/// UI-only: the settled transcript still comes from the batch pass, so this can
/// degrade gracefully (e.g. while the model installs on first use) without loss.
@available(iOS 26.0, *)
final class SpeechAnalyzerLiveSession {
  private let localeId: String
  private let emit: ([String: Any]) -> Void
  private let emitError: (SpeechErrorCode, String) -> Void

  private let transcriber: SpeechTranscriber
  private let analyzer: SpeechAnalyzer

  // Guards the streaming state shared between setup, the realtime tap thread
  // (feed), the collector task, and teardown (finish/stop).
  private let lock = NSLock()
  private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
  private var analyzerFormat: AVAudioFormat?
  private var converter: AVAudioConverter?
  private var consumerToken: Int?
  private var runTask: Task<Void, Never>?
  private var collectorTask: Task<Void, Never>?
  // Set once teardown begins, so a stop() racing setup, a duplicate finish, and a
  // late buffer all become no-ops.
  private var finished = false

  fileprivate init(
    localeId: String,
    emit: @escaping ([String: Any]) -> Void,
    emitError: @escaping (SpeechErrorCode, String) -> Void
  ) {
    self.localeId = localeId
    self.emit = emit
    self.emitError = emitError
    self.transcriber = makeTimedTranscriber(
      locale: Locale(identifier: localeId), volatileResults: true)
    self.analyzer = SpeechAnalyzer(modules: [transcriber])
  }

  func start() {
    runTask = Task { await self.run() }
  }

  private func run() async {
    let locale = Locale(identifier: localeId)
    do {
      guard await requestSpeechAuthorization() == .authorized else {
        emitError(.permissionDenied, speechNotAuthorizedMessage)
        return
      }
      do {
        try await installTranscriptionModel(transcriber, locale: locale)
      } catch is CancellationError {
        abort()
        return
      } catch {
        // A first-use download failure is a model-install condition the app reasons
        // about (retry when online), not a generic transcription failure.
        emitError(.modelInstallFailed, "\(error)")
        abort()
        return
      }

      // No compatible on-device format means the model is not usable here. Degrade
      // silently (batch is the source of truth) rather than attach a collector that
      // would await results forever.
      guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
      else { return }

      // Bounded, dropping the newest when full: the tap produces ~47 buffers/sec
      // with no backpressure signal, so an analyzer running below realtime must not
      // grow memory without limit. 256 buffers is a few seconds of headroom; live is
      // UI-only, and the batch pass recovers anything dropped.
      let (inputSequence, builder) = AsyncStream<AnalyzerInput>.makeStream(
        bufferingPolicy: .bufferingOldest(256))
      lock.lock()
      // A stop() raced this setup: bail before attaching anything to tear down.
      if finished {
        lock.unlock()
        builder.finish()
        return
      }
      analyzerFormat = format
      inputBuilder = builder
      // Created under the lock so a stop() racing here reliably sees and cancels it.
      collectorTask = makeCollector()
      lock.unlock()

      try await analyzer.start(inputSequence: inputSequence)

      let token = CaptureHub.session.addConsumer(
        onBuffer: { [weak self] buffer in self?.feed(buffer) },
        onStop: { [weak self] in self?.finish() }
      )
      lock.lock()
      if finished {
        lock.unlock()
        CaptureHub.session.removeConsumer(token)
      } else {
        consumerToken = token
        lock.unlock()
        // Capture may have stopped during the long setup awaits above (auth, model
        // install). Its onStop already fired before we attached, so nothing would
        // ever finalize this session; do it ourselves.
        if !CaptureHub.session.isCapturing { finish() }
      }
    } catch is CancellationError {
      // Superseded or torn down mid-setup; not a failure to surface.
      abort()
    } catch {
      emitError(.transcribeError, "\(error)")
      abort()
    }
  }

  /// Consumes the transcriber's results, emitting the growing text as partials and
  /// one final event when the stream ends (after the input is finalized). Partials
  /// carry no segments: volatile runs have unstable timing. The final event carries
  /// timed segments for parity, though the persisted transcript comes from the batch
  /// pass, not from here.
  private func makeCollector() -> Task<Void, Never> {
    Task { [weak self] in
      guard let self = self else { return }
      var finalized = AttributedString()
      do {
        for try await result in self.transcriber.results {
          // result.isFinal marks a finalized chunk, not the end of the session; every
          // in-stream event is a partial (isFinal: false) to Dart. The session-final
          // event is emitted once the results stream ends, below.
          if result.isFinal {
            finalized.append(result.text)
            self.emit(["text": finalized.plainText, "isFinal": false])
          } else {
            var display = finalized
            display.append(result.text)
            self.emit(["text": display.plainText, "isFinal": false])
          }
        }
        self.emit([
          "text": finalized.plainText,
          "isFinal": true,
          "segments": analyzerSegments(from: finalized),
        ])
      } catch is CancellationError {
        // A normal teardown, not a failure to surface.
      } catch {
        self.emitError(.transcribeError, "\(error)")
      }
    }
  }

  private func feed(_ buffer: AVAudioPCMBuffer) {
    lock.lock()
    let active = !finished
    let builder = inputBuilder
    let format = analyzerFormat
    lock.unlock()
    guard active, let builder = builder, let format = format else { return }

    // feed runs only on the single realtime tap thread, so the converter needs no
    // lock; building it here also keeps allocation off the teardown-contended lock.
    // Rebuilt if the input format changes mid-session (a route change that leaves
    // the engine running), else every later buffer would fail conversion and live
    // would die silently for the rest of the session.
    if converter == nil || converter?.inputFormat != buffer.format {
      converter = AVAudioConverter(from: buffer.format, to: format)
    }
    guard let converter = converter,
      let converted = Self.convert(buffer, using: converter, to: format)
    else { return }
    builder.yield(AnalyzerInput(buffer: converted))
  }

  /// Converts one capture buffer into the analyzer's format. Returns nil on failure
  /// so a single bad buffer is dropped rather than tearing the stream down.
  private static func convert(
    _ input: AVAudioPCMBuffer, using converter: AVAudioConverter, to format: AVAudioFormat
  ) -> AVAudioPCMBuffer? {
    let ratio = format.sampleRate / input.format.sampleRate
    // +1024 frames of headroom over the rate-scaled size: resampling can emit a
    // few more frames than the ratio predicts (filter tails, rounding).
    let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024
    guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
      return nil
    }
    var consumed = false
    var error: NSError?
    converter.convert(to: output, error: &error) { _, status in
      if consumed {
        status.pointee = .noDataNow
        return nil
      }
      consumed = true
      status.pointee = .haveData
      return input
    }
    return error == nil ? output : nil
  }

  /// Marks finished and detaches from capture under the lock. Returns whether
  /// teardown had already run (so the caller skips a second analyzer wind-down) and
  /// the collector task, so an aborting caller can cancel it.
  private func detach() -> (already: Bool, collector: Task<Void, Never>?) {
    lock.lock()
    let already = finished
    finished = true
    let builder = inputBuilder
    inputBuilder = nil
    let token = consumerToken
    consumerToken = nil
    let collector = collectorTask
    lock.unlock()

    if let token = token { CaptureHub.session.removeConsumer(token) }
    builder?.finish()
    return (already, collector)
  }

  /// Graceful end (capture stopped): finish the input and let the analyzer flush its
  /// pending audio so the collector reaches its natural end and emits the final
  /// event. Deliberately does not cancel the collector.
  private func finish() {
    let (already, _) = detach()
    guard !already else { return }
    Task { [analyzer] in try? await analyzer.finalizeAndFinishThroughEndOfInput() }
  }

  /// Tears down now without waiting for a final event, cancelling the collector.
  /// Idempotent with finish() and with itself.
  private func abort() {
    let (_, collector) = detach()
    // Cancel the collector even when finish() already ran: a graceful finalize that
    // is still flushing must not survive an abort, or its stale final event could
    // land in a NEWER session's stream (Dart would complete on it instantly).
    collector?.cancel()
    // And wind the analyzer down even then: with the collector gone, letting the
    // finalize flush run to completion would burn CPU and memory producing results
    // nobody consumes (or stall on framework backpressure). SpeechAnalyzer
    // serializes its operations; cancel supersedes an in-flight finish.
    Task { [analyzer] in try? await analyzer.cancelAndFinishNow() }
  }

  /// Cancel from outside: Dart unsubscribed, or a newer session started. Named
  /// cancel, not stop: elsewhere in this layer stop() means a graceful end, and
  /// this is the opposite (the graceful end is the internal finish()).
  func cancel() {
    runTask?.cancel()
    abort()
  }
}

final class SpeechEnginePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  // Guards live state shared between the EventChannel/recognition callbacks and the
  // realtime tap thread that calls the buffer consumer, plus the batch task registry
  // (batchTasks/nextBatchId), whose completions land on Speech's queue.
  private let lock = NSLock()
  private var liveRequest: SFSpeechAudioBufferRecognitionRequest?
  private var liveTask: SFSpeechRecognitionTask?
  private var consumerToken: Int?
  // Bumped on every start/stop (main-thread only). A pending async resolve compares
  // against it and abandons itself if it was superseded, so a cancel racing the
  // resolve cannot leave an orphaned consumer/task with no teardown path.
  private var liveGeneration = 0

  // The iOS 26 SpeechAnalyzer live session. Stored untyped because its type is
  // availability-gated; cast on use.
  private var analyzerLive: AnyObject?

  // Batch tasks are retained by id so overlapping calls do not drop each other.
  private var batchTasks: [Int: SFSpeechRecognitionTask] = [:]
  private var nextBatchId = 0

  // Streams model-install progress on its own channel. Held here so it lives as long
  // as the plugin.
  private let modelInstaller = ModelInstallStreamHandler()

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SpeechEnginePlugin()
    // Channel names + payload shapes: must match apple_speech_engine.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/speech", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "opentranscribe/speech/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    let modelEvents = FlutterEventChannel(
      name: "opentranscribe/speech/model", binaryMessenger: registrar.messenger())
    modelEvents.setStreamHandler(instance.modelInstaller)
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
    emit(errorPayload(code, message))
  }

  /// Delivers a live payload on main only if [generation] is still current, so a
  /// superseded session's late partials or its cancellation error can never leak
  /// into the next session's stream.
  private func emitLive(_ payload: [String: Any], generation: Int) {
    DispatchQueue.main.async {
      guard generation == self.liveGeneration else { return }
      self.eventSink?(payload)
    }
  }

  private func startLive(localeId: String) {
    // Re-entrancy guard: a new live session tears down any previous one first.
    stopLive()
    // One generation for BOTH paths: task cancellation is best-effort, so a
    // superseded session (classic or analyzer) can still be mid-emit; the guard at
    // delivery time is what actually keeps stale text, finals, and cancellation
    // errors out of the next session's stream.
    liveGeneration += 1
    let generation = liveGeneration
    // iOS 26 streams via SpeechAnalyzer; the classic buffer recognizer below is the
    // pre-26 path (which also does not run on the simulator).
    if #available(iOS 26.0, *) {
      #if targetEnvironment(simulator)
        // No on-device model on the simulator; fail fast instead of hanging on a
        // model download that never completes.
        emitError(.onDeviceUnavailable, "on-device speech is unavailable on the simulator")
        return
      #else
        let session = SpeechAnalyzerLiveSession(
          localeId: localeId,
          emit: { [weak self] payload in self?.emitLive(payload, generation: generation) },
          emitError: { [weak self] code, message in
            self?.emitLive(errorPayload(code, message), generation: generation)
          })
        analyzerLive = session
        session.start()
        return
      #endif
    }
    resolveRecognizer(localeId) { [weak self] resolution in
      guard let self = self else { return }
      // Abandon if a stop or a newer start superseded this resolve while it ran.
      guard generation == self.liveGeneration else { return }
      switch resolution {
      case .ready(let recognizer):
        self.beginLive(recognizer: recognizer, generation: generation)
      case .failed(let code, let message):
        // Through the generation guard, not emitError: this delivery is a later
        // main-queue turn than the check above, so an unguarded emit could land a
        // stale failure in a successor session's stream.
        self.emitLive(errorPayload(code, message), generation: generation)
      }
    }
  }

  private func beginLive(recognizer: SFSpeechRecognizer, generation: Int) {
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true

    // Generation-guarded emits: after stopLive cancels this task, Speech still
    // delivers a "canceled" error asynchronously; without the guard it would fault
    // the NEXT session's fresh stream.
    let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self = self else { return }
      if let result = result {
        var payload: [String: Any] = [
          "text": result.bestTranscription.formattedString,
          "isFinal": result.isFinal,
        ]
        if result.isFinal { payload["segments"] = segments(from: result.bestTranscription) }
        self.emitLive(payload, generation: generation)
      }
      if let error = error {
        self.emitLive(errorPayload(.transcribeError, "\(error)"), generation: generation)
      }
    }

    // Store the request before attaching to capture: a capture stop landing between
    // attach and store would otherwise read a nil request and drop endAudio(), so
    // the recognizer would never finalize.
    lock.lock()
    liveRequest = request
    liveTask = task
    lock.unlock()

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
    consumerToken = token
    lock.unlock()

    // Capture may have stopped during the async resolve; its onStop fired before we
    // attached, so nothing would ever finalize the request. End the audio ourselves
    // so the recognizer settles instead of waiting forever.
    if !CaptureHub.session.isCapturing { request.endAudio() }
  }

  private func stopLive() {
    liveGeneration += 1
    if #available(iOS 26.0, *) {
      (analyzerLive as? SpeechAnalyzerLiveSession)?.cancel()
      analyzerLive = nil
    }
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
      if #available(iOS 26.0, *) {
        // iOS 26 transcribes with SpeechAnalyzer, so availability tracks its model,
        // not the classic recognizer. Available = authorized and the locale is
        // supported (the model downloads once on first use if not yet installed).
        Task {
          let authorized = await requestSpeechAuthorization() == .authorized
          let status =
            !authorized
            ? SpeechErrorCode.permissionDenied.rawValue
            : (await modelLocaleSupported(localeId)
              ? "available" : SpeechErrorCode.onDeviceUnavailable.rawValue)
          DispatchQueue.main.async { result(["status": status]) }
        }
      } else {
        resolveRecognizer(localeId) { resolution in
          result(["status": resolution.failure?.code.rawValue ?? "available"])
        }
      }
    case "isModelInstalled":
      let localeId = (call.arguments as? [String: Any])?["localeId"] as? String ?? "en-US"
      if #available(iOS 26.0, *) {
        Task {
          let installed = await modelLocaleInstalled(localeId)
          DispatchQueue.main.async { result(installed) }
        }
      } else {
        // No app-managed model before iOS 26; treat the system recognizer as the model.
        result(onDeviceRecognizer(localeId) != nil)
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
      case .failed(let code, let message):
        result(code.error(message))
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
      self.lock.unlock()
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
      // Create the task OUTSIDE the lock: the same lock serves the realtime buffer
      // consumer, and holding it across an opaque framework call would contend with
      // the audio tap thread. `replied` closes the store-vs-reply ordering instead.
      let task = recognizer.recognitionTask(with: request) { recognitionResult, error in
        if let error = error {
          reply(SpeechErrorCode.transcribeError.error("\(error)"))
          return
        }
        guard let recognitionResult = recognitionResult, recognitionResult.isFinal else { return }
        reply([
          "text": recognitionResult.bestTranscription.formattedString,
          "segments": segments(from: recognitionResult.bestTranscription),
        ])
      }
      self.lock.lock()
      if !replied { self.batchTasks[id] = task }
      self.lock.unlock()
    }
  }

  /// iOS 26 on-device batch transcription with SpeechAnalyzer (the dispatcher above
  /// fails fast on the simulator before reaching here). The first call for a locale
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
      var collected: Task<AttributedString, Error>?
      do {
        guard await requestSpeechAuthorization() == .authorized else {
          reply(SpeechErrorCode.permissionDenied.error(speechNotAuthorizedMessage))
          return
        }

        // supportedLocales is empty on the simulator, so we do not gate on it. Install
        // the model for the requested locale directly; if no asset exists the download
        // or the analysis below surfaces the real error.
        let transcriber = makeTimedTranscriber(locale: locale)
        do {
          try await installTranscriptionModel(transcriber, locale: locale)
        } catch {
          // Distinct code: a download failure has a different retry story than a
          // broken transcription.
          reply(SpeechErrorCode.modelInstallFailed.error("\(error)"))
          return
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: url)

        let collector = Task { () -> AttributedString in
          var text = AttributedString()
          for try await item in transcriber.results where item.isFinal {
            text.append(item.text)
          }
          return text
        }
        collected = collector

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
          try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
          // No analyzable audio at all. Cancel and reply the valid empty result
          // directly, rather than awaiting a collector whose stream a cancellation
          // may end with CancellationError (misreported as a transcribe error).
          await analyzer.cancelAndFinishNow()
          collector.cancel()
          reply(["text": "", "segments": [[String: Any]]()])
          return
        }

        let text = try await collector.value
        // Timed segments come from the attributed runs (attributeOptions
        // [.audioTimeRange]); the full text is the result text directly.
        reply(["text": text.plainText, "segments": analyzerSegments(from: text)])
      } catch {
        collected?.cancel()
        reply(SpeechErrorCode.transcribeError.error("\(error)"))
      }
    }
  }
}

/// Streams on-device model-install progress for the requested locale over the
/// `opentranscribe/speech/model` EventChannel. Single-flight: a new listen supersedes
/// any in-flight install and abandons its stream (the app installs one language at a
/// time). Payloads: {fraction, done:false} while installing, then a terminal
/// {fraction:1, done:true}; {type:error,...} on failure.
final class ModelInstallStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var task: Task<Void, Never>?
  // Bumped on every listen (main-thread only). A superseded install compares against
  // it and drops its emits, so a slow prior download cannot leak progress into a
  // newer listener's stream.
  private var generation = 0

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError?
  {
    cancel()
    generation += 1
    let gen = generation
    sink = eventSink
    let localeId = (arguments as? [String: Any])?["localeId"] as? String ?? "en-US"
    if #available(iOS 26.0, *) {
      #if targetEnvironment(simulator)
        // No on-device model on the simulator; fail fast instead of sitting at 0%.
        emit(
          errorPayload(.modelInstallFailed, "model install is unavailable on the simulator"),
          generation: gen)
      #else
        task = Task { await self.install(localeId: localeId, generation: gen) }
      #endif
    } else {
      // No app-managed model before iOS 26; nothing to download.
      emit(["fraction": 1.0, "done": true], generation: gen)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    cancel()
    sink = nil
    return nil
  }

  private func cancel() {
    task?.cancel()
    task = nil
  }

  @available(iOS 26.0, *)
  private func install(localeId: String, generation gen: Int) async {
    let locale = Locale(identifier: localeId)
    let transcriber = SpeechTranscriber(
      locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
    do {
      // The explicit install flow is the one place other locales' reservations are
      // released, so language switches cannot exhaust the reservation cap.
      await releaseOtherReservations(keeping: locale)
      guard let downloader = try await reserveAndRequestInstall(transcriber, locale: locale) else {
        emit(["fraction": 1.0, "done": true], generation: gen)  // already installed
        return
      }
      // Observe fractionCompleted (KVO); the observation is torn down when install()
      // returns or throws.
      let observation = downloader.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
        self?.emit(["fraction": progress.fractionCompleted, "done": false], generation: gen)
      }
      defer { observation.invalidate() }
      try await downloader.downloadAndInstall()
      emit(["fraction": 1.0, "done": true], generation: gen)
    } catch is CancellationError {
      // Normal teardown (Dart unsubscribed), not a failure.
    } catch {
      emit(errorPayload(.modelInstallFailed, "\(error)"), generation: gen)
    }
  }

  /// Delivers on the main thread, dropping the write if a newer listen has superseded
  /// this install, so a stale task never emits into another listener's stream.
  private func emit(_ payload: [String: Any], generation gen: Int) {
    DispatchQueue.main.async {
      guard gen == self.generation else { return }
      self.sink?(payload)
    }
  }
}
