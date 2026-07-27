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
  case reservationCap = "reservation_cap"
  case badArgs = "bad_args"

  /// The channel error for this code. [details] carries structured extras
  /// (asset status, reserved tags) so Dart never parses message strings.
  func error(_ message: String, details: Any? = nil) -> FlutterError {
    FlutterError(code: rawValue, message: message, details: details)
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

/// Converts one PCM buffer into [format]. Returns nil on failure so a single
/// bad buffer is dropped rather than tearing its stream down. Shared by the
/// live tap feed and the ranged batch feed; the CALLER owns the converter, so
/// resampler state carries across consecutive buffers.
private func convertBuffer(
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

/// The chunk one slice read asks for at a time (~0.7s at 48kHz).
private let sliceChunkFrames: AVAudioFrameCount = 32_768

/// Reads the next raw chunk of a slice, shrinking [remaining]. Nil on the end
/// of the slice, a truncated file (a header claiming more than is stored), or
/// a read error: what WAS read still transcribes, like the whole-file path.
private func readSliceChunk(
  from file: AVAudioFile, remaining: inout AVAudioFramePosition
) -> AVAudioPCMBuffer? {
  guard remaining > 0 else { return nil }
  let ask = AVAudioFrameCount(min(AVAudioFramePosition(sliceChunkFrames), remaining))
  guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: ask)
  else { return nil }
  do {
    try file.read(into: buffer, frameCount: ask)
  } catch {
    remaining = 0
    return nil
  }
  if buffer.frameLength == 0 {
    remaining = 0
    return nil
  }
  remaining -= AVAudioFramePosition(buffer.frameLength)
  return buffer
}

/// Drains an [AVAudioConverter]'s buffered tail (the resampler filter holds a
/// few ms) once its input is exhausted, so span-boundary words keep their end.
private func flushConverter(
  _ converter: AVAudioConverter, to format: AVAudioFormat
) -> AVAudioPCMBuffer? {
  guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else { return nil }
  var error: NSError?
  converter.convert(to: output, error: &error) { _, status in
    status.pointee = .endOfStream
    return nil
  }
  return error == nil ? output : nil
}

/// Pull-based analyzer input for one file slice: each chunk is read and
/// converted only when the analyzer asks for it, so memory stays one chunk
/// deep however long the span (a pushed AsyncStream would buffer the whole
/// slice at disk speed). Single consumer by contract - the analyzer iterates
/// it once - hence the unchecked Sendable over the file and converter.
@available(iOS 26.0, *)
private final class SliceFeed: AsyncSequence, @unchecked Sendable {
  typealias Element = AnalyzerInput

  private let file: AVAudioFile
  private let format: AVAudioFormat
  private let converter: AVAudioConverter?
  private var head: AVAudioPCMBuffer?
  private var remaining: AVAudioFramePosition
  private var flushed = false

  init(
    file: AVAudioFile, format: AVAudioFormat, converter: AVAudioConverter?,
    head: AVAudioPCMBuffer, remaining: AVAudioFramePosition
  ) {
    self.file = file
    self.format = format
    self.converter = converter
    self.head = head
    self.remaining = remaining
  }

  func makeAsyncIterator() -> Iterator { Iterator(feed: self) }

  struct Iterator: AsyncIteratorProtocol {
    let feed: SliceFeed
    mutating func next() async -> AnalyzerInput? { feed.nextInput() }
  }

  private func nextInput() -> AnalyzerInput? {
    while let raw = nextRaw() {
      guard let converter else { return AnalyzerInput(buffer: raw) }
      // A chunk the converter drops is skipped, not fatal, like the live tap.
      if let converted = convertBuffer(raw, using: converter, to: format),
        converted.frameLength > 0
      {
        return AnalyzerInput(buffer: converted)
      }
    }
    if !flushed, let converter {
      flushed = true
      if let tail = flushConverter(converter, to: format), tail.frameLength > 0 {
        return AnalyzerInput(buffer: tail)
      }
    }
    return nil
  }

  private func nextRaw() -> AVAudioPCMBuffer? {
    if let pending = head {
      head = nil
      return pending
    }
    return readSliceChunk(from: file, remaining: &remaining)
  }
}

/// Speech-recognition authorization as an async value (wrapping the callback API).
private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
  await withCheckedContinuation { continuation in
    SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
  }
}

/// The channel's status strings; one spelling with apple_speech_engine.dart.
@available(iOS 26.0, *)
private func statusName(_ status: AssetInventory.Status) -> String {
  switch status {
  case .installed: return "installed"
  case .downloading: return "downloading"
  case .supported: return "supported"
  case .unsupported: return "unsupported"
  @unknown default: return "supported"
  }
}

/// This app's reserved locales as sorted bcp47 tags.
@available(iOS 26.0, *)
private func reservedTagList() async -> [String] {
  await AssetInventory.reservedLocales.map { $0.identifier(.bcp47) }.sorted()
}

/// The per-app language cap is full. Its own type because the fix is an
/// eviction choice by the user, not a retry; carries the current holdings so
/// the UI can offer them.
@available(iOS 26.0, *)
private struct ReservationCapError: Error {
  let reservedTags: [String]
}

/// A model download failure with the PRE-install asset status attached: a
/// stuck download, an asset the CDN does not have, and an ordinary network
/// failure all fail downstream with the same error, and only this status
/// tells them apart in reports.
@available(iOS 26.0, *)
private struct ModelInstallError: Error {
  let underlying: Error
  let status: AssetInventory.Status

  var message: String {
    "\((underlying as NSError).localizedDescription) (status before install: \(status))"
  }
}

@available(iOS 26.0, *)
private func isReservationCapError(_ error: Error) -> Bool {
  let base = error as NSError
  return base.domain == SFSpeechErrorDomain
    && base.code == SFSpeechError.Code.tooManyAssetLocalesAllocated.rawValue
}

/// Folds any install-path failure into the (code, message, extras) all THREE
/// surfaces share - the method-channel reply, the install stream, and the
/// live stream - so their shapes cannot drift.
@available(iOS 26.0, *)
private func installFailure(_ error: Error) -> (
  code: SpeechErrorCode, message: String, extras: [String: Any]
) {
  if let cap = error as? ReservationCapError {
    return (
      .reservationCap,
      "language limit reached; reserved: \(cap.reservedTags.joined(separator: ", "))",
      ["reservedTags": cap.reservedTags]
    )
  }
  if let install = error as? ModelInstallError {
    return (.modelInstallFailed, install.message, ["status": statusName(install.status)])
  }
  return (.modelInstallFailed, "\(error)", [:])
}

/// Reserves the locale and returns the install request, or nil when the model is
/// already installed. Reserve first, else the request fails "not subscribed to
/// transcription.<lang>"; a repeat reservation is harmless. The one-time download is
/// the single dent in the airplane-mode promise; after it, transcription is offline.
/// Reservations accumulate deliberately (multi-language is the point); the only
/// release is the explicit removeLanguage call, and a full cap surfaces as the
/// typed [ReservationCapError] so the UI can run an eviction, never a cryptic
/// install failure.
@available(iOS 26.0, *)
private func reserveAndRequestInstall(_ transcriber: SpeechTranscriber, locale: Locale) async throws
  -> AssetInstallationRequest?
{
  do {
    try await AssetInventory.reserve(locale: locale)
  } catch let error where isReservationCapError(error) {
    throw ReservationCapError(reservedTags: await reservedTagList())
  } catch {
    // Logged, not fatal: the install request below surfaces the attributable error.
    NSLog("AssetInventory.reserve(\(locale.identifier(.bcp47))) failed: \(error)")
  }
  do {
    return try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
  } catch let error where isReservationCapError(error) {
    throw ReservationCapError(reservedTags: await reservedTagList())
  }
}

/// Reads and logs the asset status for a transcriber before an install attempt.
/// Field diagnosis hinges on it: a download stuck from an earlier attempt
/// (.downloading) and an asset the CDN simply does not have fail downstream with
/// the same "Not Installing" error; only this status tells them apart.
@available(iOS 26.0, *)
private func loggedAssetStatus(_ transcriber: SpeechTranscriber, locale: Locale) async
  -> AssetInventory.Status
{
  let status = await AssetInventory.status(forModules: [transcriber])
  NSLog("AssetInventory status for \(locale.identifier(.bcp47)) before install: \(status)")
  return status
}

/// Installs the on-device model for a transcriber's locale on first use (batch/live).
/// Throws [ReservationCapError] on a full cap, [ModelInstallError] on a download
/// failure (status attached), and lets CancellationError pass untouched: callers
/// branch on its type for quiet teardown.
@available(iOS 26.0, *)
private func installTranscriptionModel(_ transcriber: SpeechTranscriber, locale: Locale) async throws {
  let status = await loggedAssetStatus(transcriber, locale: locale)
  if let request = try await reserveAndRequestInstall(transcriber, locale: locale) {
    do {
      try await request.downloadAndInstall()
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw ModelInstallError(underlying: error, status: status)
    }
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

/// The nearest supported model locale for a requested tag (de-AT finds de-DE), or
/// the request unchanged when nothing matches, so an unsupported language fails
/// honestly downstream instead of silently becoming another language.
@available(iOS 26.0, *)
private func resolvedLocale(_ localeId: String) async -> Locale {
  let requested = Locale(identifier: localeId)
  return await SpeechTranscriber.supportedLocale(equivalentTo: requested) ?? requested
}

/// Whether the on-device model for a locale is downloaded and ready now.
/// Callers pass the RESOLVED locale's tag so a near variant counts as installed.
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
  private let emitError: (SpeechErrorCode, String, [String: Any]) -> Void

  // The PREVIOUS session's analyzer wind-down, awaited once before this session's
  // own analyzer.start(). Two SpeechAnalyzer instances contending for the shared
  // on-device recognizer can stall the new start() indefinitely - the new take's
  // live window then stays blank while the batch pass still works. A rapid restart
  // (a mid-take language switch, or stop-then-record-again) is exactly when they
  // overlap, so serialize them.
  private let priorTeardown: Task<Void, Never>?

  // Built in run(), not init: the locale must first resolve (async) to the
  // nearest supported model. Guarded by the lock like the other streaming state.
  private var transcriber: SpeechTranscriber?
  private var analyzer: SpeechAnalyzer?

  // Guards the streaming state shared between setup, the realtime tap thread
  // (feed), the collector task, and teardown (finish/stop).
  private let lock = NSLock()
  private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
  private var analyzerFormat: AVAudioFormat?
  private var converter: AVAudioConverter?
  private var consumerToken: Int?
  private var runTask: Task<Void, Never>?
  private var collectorTask: Task<Void, Never>?
  // Set once teardown begins, so a cancel() racing setup, a duplicate finish,
  // and a late buffer all become no-ops.
  private var finished = false
  // One-shot latch for the feed diagnostic below: touched only on the single
  // realtime tap thread (like converter), so it needs no lock.
  private var feedFailureReported = false
  // The analyzer wind-down this session launches on finish()/abort(), handed to
  // the NEXT session as its priorTeardown so the two never overlap. Guarded by lock.
  private var teardownTask: Task<Void, Never>?
  // True once analyzer.start() has returned. A session torn down BEFORE this never
  // started an analyzer, so it winds nothing down (no cancelAndFinishNow on an
  // unstarted analyzer) and instead chains its own priorTeardown forward, so the
  // older analyzer it was still waiting on is not orphaned. Guarded by lock.
  private var analyzerStarted = false

  fileprivate init(
    localeId: String,
    emit: @escaping ([String: Any]) -> Void,
    emitError: @escaping (SpeechErrorCode, String, [String: Any]) -> Void,
    priorTeardown: Task<Void, Never>? = nil
  ) {
    self.localeId = localeId
    self.emit = emit
    self.emitError = emitError
    self.priorTeardown = priorTeardown
  }

  // The wind-down a successor must await before starting its analyzer. Chains this
  // session's own teardown BEHIND its priorTeardown: if this session was superseded
  // before it started (own teardown nil/trivial), the older analyzer it was still
  // waiting on is carried forward through prior, so the chain never drops a
  // still-running analyzer under a rapid burst of restarts.
  var pendingTeardown: Task<Void, Never>? {
    lock.lock()
    let own = teardownTask
    lock.unlock()
    let prior = priorTeardown
    if own == nil && prior == nil { return nil }
    return Task {
      await prior?.value
      await own?.value
    }
  }

  func start() {
    runTask = Task { await self.run() }
  }

  private func run() async {
    do {
      guard await requestSpeechAuthorization() == .authorized else {
        emitError(.permissionDenied, speechNotAuthorizedMessage, [:])
        return
      }
      // Resolve to the nearest supported model, then build the pipeline for it.
      let locale = await resolvedLocale(localeId)
      let transcriber = makeTimedTranscriber(locale: locale, volatileResults: true)
      let analyzer = SpeechAnalyzer(modules: [transcriber])
      lock.lock()
      if finished {
        lock.unlock()
        return
      }
      self.transcriber = transcriber
      self.analyzer = analyzer
      lock.unlock()

      do {
        try await installTranscriptionModel(transcriber, locale: locale)
      } catch is CancellationError {
        abort()
        return
      } catch {
        // A first-use download failure is a model-install condition the app reasons
        // about (retry when online, or evict a language), not a generic failure.
        let failure = installFailure(error)
        emitError(failure.code, failure.message, failure.extras)
        abort()
        return
      }

      // No compatible on-device format means the model is not usable here. Batch is
      // still the source of truth, so this never fails the take; surface why live is
      // blank (temporary diagnostic) instead of degrading silently.
      guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
      else {
        emitError(.transcribeError, "live: no compatible on-device audio format", [:])
        // Wind the (created but never started) analyzer down like the sibling
        // early-returns above, so this session does not sit half-initialized.
        abort()
        return
      }

      // Bounded, dropping the newest when full: the tap produces ~47 buffers/sec
      // with no backpressure signal, so an analyzer running below realtime must not
      // grow memory without limit. 256 buffers is a few seconds of headroom; live is
      // UI-only, and the batch pass recovers anything dropped.
      let (inputSequence, builder) = AsyncStream<AnalyzerInput>.makeStream(
        bufferingPolicy: .bufferingOldest(256))
      lock.lock()
      // A cancel() raced this setup: bail before attaching anything to tear down.
      if finished {
        lock.unlock()
        builder.finish()
        return
      }
      analyzerFormat = format
      inputBuilder = builder
      // Created under the lock so a cancel() racing here reliably sees and cancels it.
      collectorTask = makeCollector()
      lock.unlock()

      // Wait out the previous session's analyzer wind-down before starting ours,
      // so the two never contend for the shared recognizer (which stalls this
      // start() and leaves live blank). A completed teardown returns instantly.
      await priorTeardown?.value
      if Task.isCancelled {
        abort()
        return
      }

      try await analyzer.start(inputSequence: inputSequence)
      lock.lock()
      analyzerStarted = true
      lock.unlock()

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
      emitError(.transcribeError, "\(error)", [:])
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
      self.lock.lock()
      let transcriber = self.transcriber
      self.lock.unlock()
      guard let transcriber = transcriber else { return }
      var finalized = AttributedString()
      do {
        for try await result in transcriber.results {
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
        self.emitError(.transcribeError, "\(error)", [:])
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
    guard let converter = converter else {
      reportFeedFailure("live: could not build audio converter for capture format")
      return
    }
    guard let converted = convertBuffer(buffer, using: converter, to: format) else {
      reportFeedFailure("live: audio conversion failed")
      return
    }
    builder.yield(AnalyzerInput(buffer: converted))
  }

  // Surface the first feed failure once (temporary diagnostic): a converter that
  // will not build, or conversion that fails, silently starves the analyzer so
  // the live window stays blank while the batch pass still succeeds. One emit per
  // session; the Dart side clears it as soon as live text resumes.
  private func reportFeedFailure(_ message: String) {
    guard !feedFailureReported else { return }
    feedFailureReported = true
    emitError(.transcribeError, message, [:])
  }

  // Conversion lives in the shared file-scope convertBuffer helper, which the
  // ranged batch feed drives through the same analyzer format.

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
    lock.lock()
    let analyzer = self.analyzer
    let started = analyzerStarted
    lock.unlock()
    guard let analyzer = analyzer, started else { return }
    let task = Task { _ = try? await analyzer.finalizeAndFinishThroughEndOfInput() }
    lock.lock()
    teardownTask = task
    lock.unlock()
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
    lock.lock()
    let analyzer = self.analyzer
    let started = analyzerStarted
    lock.unlock()
    // An unstarted analyzer has nothing to wind down; skip it so we never await a
    // cancelAndFinishNow() on an analyzer that never ran (its priorTeardown chains
    // forward via pendingTeardown instead).
    guard let analyzer = analyzer, started else { return }
    // Overwrites any finish() task on purpose: a cancel supersedes a graceful
    // finalize, and this is the wind-down the next session must wait on.
    let task = Task { _ = try? await analyzer.cancelAndFinishNow() }
    lock.lock()
    teardownTask = task
    lock.unlock()
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

  // The current live session token from Dart. The events channel is listened
  // once and never cancelled per-take; sessions are driven by startLive/stopLive
  // method calls, and every emit is tagged with this token so Dart routes each
  // take's stream to only its own events. -1 = no session.
  private var liveSession = -1

  // The iOS 26 SpeechAnalyzer live session. Stored untyped because its type is
  // availability-gated; cast on use.
  private var analyzerLive: AnyObject?

  // The outgoing analyzer session's wind-down, captured in stopLive and handed to
  // the next session (startLive) so a new analyzer never starts while the old one
  // is still tearing down. Main-thread only, like startLive/stopLive.
  private var pendingAnalyzerTeardown: Task<Void, Never>?

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

  // The events channel is listened once for the app's lifetime: onListen only
  // stores the sink, and recognition is driven by the startLive/stopLive method
  // calls. This decouples session lifecycle from the channel subscription, so
  // consecutive takes never race each other's listen/cancel.
  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self.eventSink = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  /// Delivers a live payload on main only if [generation] is still current, so a
  /// superseded session's late partials or its cancellation error can never leak
  /// into the next session's stream. Tags each event with the owning session so
  /// Dart routes it to that take's stream and no other.
  private func emitLive(_ payload: [String: Any], generation: Int) {
    DispatchQueue.main.async {
      guard generation == self.liveGeneration else { return }
      var tagged = payload
      tagged["session"] = self.liveSession
      self.eventSink?(tagged)
    }
  }

  private func startLive(localeId: String, session: Int) {
    // Re-entrancy guard: a new live session tears down any previous one first.
    stopLive()
    liveSession = session
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
        // model download that never completes. Tagged (via emitLive) so Dart
        // routes it to this session's stream.
        emitLive(
          errorPayload(.onDeviceUnavailable, "on-device speech is unavailable on the simulator"),
          generation: generation)
        return
      #else
        let analyzerSession = SpeechAnalyzerLiveSession(
          localeId: localeId,
          emit: { [weak self] payload in self?.emitLive(payload, generation: generation) },
          emitError: { [weak self] code, message, extras in
            // Structured extras (asset status, reserved tags) ride the live
            // surface too, so all THREE error surfaces stay in one shape.
            var payload = errorPayload(code, message)
            for (key, value) in extras { payload[key] = value }
            self?.emitLive(payload, generation: generation)
          },
          priorTeardown: pendingAnalyzerTeardown)
        // Ownership moves to the new session; a stale (already-finished) task here
        // would just resolve instantly, but clear it so it is never awaited twice.
        pendingAnalyzerTeardown = nil
        analyzerLive = analyzerSession
        analyzerSession.start()
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
      let live = analyzerLive as? SpeechAnalyzerLiveSession
      live?.cancel()
      // Hand this session's wind-down to the next startLive to await.
      pendingAnalyzerTeardown = live?.pendingTeardown
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
          // Supported means a model exists for the language, including near
          // variants (de-AT counts via de-DE); a wholly unsupported language
          // reports unavailable rather than ever falling back silently.
          let supported =
            await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeId))
            != nil
          let status =
            !authorized
            ? SpeechErrorCode.permissionDenied.rawValue
            : (supported ? "available" : SpeechErrorCode.onDeviceUnavailable.rawValue)
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
          let resolved = await resolvedLocale(localeId)
          let installed = await modelLocaleInstalled(resolved.identifier(.bcp47))
          DispatchQueue.main.async { result(installed) }
        }
      } else {
        // No app-managed model before iOS 26; treat the system recognizer as the model.
        result(onDeviceRecognizer(localeId) != nil)
      }
    case "supportedLocales":
      if #available(iOS 26.0, *) {
        Task {
          let tags = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
          DispatchQueue.main.async { result(tags.sorted()) }
        }
      } else {
        // Approximation: the classic API cannot cheaply report per-locale on-device
        // support (that needs a recognizer instance per locale), so this lists all
        // recognizer locales; availability still gates the honest answer per tag.
        // The manual underscore-to-dash mapping is deliberate: .identifier(.bcp47)
        // needs iOS 16, and this branch must run down to the 13.0 target.
        result(
          SFSpeechRecognizer.supportedLocales()
            .map { $0.identifier.replacingOccurrences(of: "_", with: "-") }
            .sorted())
      }
    case "installedLocales":
      if #available(iOS 26.0, *) {
        // Device-wide truth: assets are shared system assets, so this can list
        // languages another app or OS feature downloaded.
        Task {
          let tags = await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) }
          DispatchQueue.main.async { result(tags.sorted()) }
        }
      } else {
        // The classic API cannot enumerate installed models cheaply (it would
        // need a recognizer per locale); per-tag localeStatus answers readiness.
        result([String]())
      }
    case "localeStatus":
      let localeId = (call.arguments as? [String: Any])?["localeId"] as? String ?? "en-US"
      if #available(iOS 26.0, *) {
        #if targetEnvironment(simulator)
          // No on-device model on the simulator; unsupported is the honest state.
          result(["status": "unsupported", "reserved": false, "resolvedTag": localeId])
        #else
          Task {
            let locale = await resolvedLocale(localeId)
            let tag = locale.identifier(.bcp47)
            // Same transcriber shape as the transcribe paths, so the status can
            // never under-report relative to what transcription actually needs.
            let transcriber = makeTimedTranscriber(locale: locale)
            let status = await AssetInventory.status(forModules: [transcriber])
            let reserved = await reservedTagList().contains(tag)
            DispatchQueue.main.async {
              result(["status": statusName(status), "reserved": reserved, "resolvedTag": tag])
            }
          }
        #endif
      } else {
        // Pre-26 has no asset management: an available on-device recognizer IS
        // the installed model, and there is no reservation concept to fail on.
        let installed = onDeviceRecognizer(localeId) != nil
        result([
          "status": installed ? "installed" : "unsupported",
          "reserved": true,
          "resolvedTag": localeId,
        ])
      }
    case "reservationInfo":
      if #available(iOS 26.0, *) {
        Task {
          let reserved = await reservedTagList()
          let max = AssetInventory.maximumReservedLocales
          DispatchQueue.main.async { result(["max": max, "reserved": reserved]) }
        }
      } else {
        // No reservation concept pre-26; max 0 is the contract's "no cap here".
        result(["max": 0, "reserved": [String]()])
      }
    case "removeLanguage":
      // Strict, unlike the read-only handlers' en-US fallback: this one ACTS,
      // and garbage arguments must not release a language nobody named.
      guard let localeId = (call.arguments as? [String: Any])?["localeId"] as? String else {
        result(SpeechErrorCode.badArgs.error("localeId required"))
        return
      }
      if #available(iOS 26.0, *) {
        Task {
          // Match by tag rather than releasing the resolved Locale directly:
          // reservation identity is fragile (underscore/hyphen variants), and
          // the reserved instance is the one release recognizes.
          let locale = await resolvedLocale(localeId)
          let target = locale.identifier(.bcp47)
          var released = false
          for reserved in await AssetInventory.reservedLocales
          where reserved.identifier(.bcp47) == target {
            released = await AssetInventory.release(reservedLocale: reserved) || released
          }
          DispatchQueue.main.async { result(released) }
        }
      } else {
        result(false)
      }
    case "transcribeFile":
      guard let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(SpeechErrorCode.badArgs.error("path required"))
        return
      }
      let localeId = args["localeId"] as? String ?? "en-US"
      // Optional slice bounds, for one span of a mixed-language take.
      let startMs = (args["startMs"] as? NSNumber)?.intValue
      let endMs = (args["endMs"] as? NSNumber)?.intValue
      transcribeFile(path: path, localeId: localeId, startMs: startMs, endMs: endMs, result: result)
    case "startLive":
      let args = call.arguments as? [String: Any]
      let session = args?["session"] as? Int ?? 0
      startLive(localeId: args?["localeId"] as? String ?? "en-US", session: session)
      result(nil)
    case "stopLive":
      let session = (call.arguments as? [String: Any])?["session"] as? Int ?? -1
      // Only the current session may end live: a superseded take's late stop
      // must not tear down the take that replaced it.
      if session == liveSession { stopLive() }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Picks the batch strategy: the simulator has no model, iOS 26 uses SpeechAnalyzer,
  /// older iOS uses the classic recognizer (whole files only: a ranged ask FAILS
  /// there, never silently answers with the whole file as if it were the slice).
  private func transcribeFile(
    path: String, localeId: String, startMs: Int?, endMs: Int?, result: @escaping FlutterResult
  ) {
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
        transcribeFileWithAnalyzer(
          path: path, localeId: localeId, startMs: startMs, endMs: endMs, result: result)
      } else {
        if startMs != nil || endMs != nil {
          result(SpeechErrorCode.transcribeError.error("ranged transcription needs iOS 26"))
          return
        }
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
  /// A [startMs]/[endMs] slice transcribes ONE SPAN of a mixed-language take; its
  /// segment timings are relative to the slice, and Dart offsets them.
  @available(iOS 26.0, *)
  private func transcribeFileWithAnalyzer(
    path: String, localeId: String, startMs: Int?, endMs: Int?, result: @escaping FlutterResult
  ) {
    let url = URL(fileURLWithPath: path)
    Task {
      func reply(_ value: Any) { DispatchQueue.main.async { result(value) } }
      // Consumes transcriber.results; cancelled on any failure so it does not hang
      // awaiting a results stream that never finalizes.
      var collected: Task<AttributedString, Error>?
      // Held for the catch below: a failure mid-analysis must wind the
      // analyzer down, not leave it flushing results nobody consumes.
      var runningAnalyzer: SpeechAnalyzer?
      do {
        guard await requestSpeechAuthorization() == .authorized else {
          reply(SpeechErrorCode.permissionDenied.error(speechNotAuthorizedMessage))
          return
        }

        // Nearest supported model for the requested tag; an unsupported language
        // passes through and the download/analysis below surfaces the real error.
        let locale = await resolvedLocale(localeId)
        let transcriber = makeTimedTranscriber(locale: locale)
        do {
          try await installTranscriptionModel(transcriber, locale: locale)
        } catch {
          // Distinct codes: a download failure (or a full language cap) has a
          // different recovery story than a broken transcription.
          let failure = installFailure(error)
          reply(
            failure.code.error(
              failure.message, details: failure.extras.isEmpty ? nil : failure.extras))
          return
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        runningAnalyzer = analyzer
        let audioFile = try AVAudioFile(forReading: url)

        let collector = Task { () -> AttributedString in
          var text = AttributedString()
          for try await item in transcriber.results where item.isFinal {
            text.append(item.text)
          }
          return text
        }
        collected = collector

        if startMs == nil && endMs == nil {
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
        } else {
          // One span of a mixed-language take: pull just the slice's frames
          // through the analyzer in its own format (see [SliceFeed]).
          guard
            let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [
              transcriber
            ])
          else {
            await analyzer.cancelAndFinishNow()
            collector.cancel()
            reply(SpeechErrorCode.transcribeError.error("no compatible audio format"))
            return
          }
          let sampleRate = audioFile.processingFormat.sampleRate
          // Clamped in Double space FIRST: a corrupt span timestamp must not
          // trap the Int64 conversion.
          func frame(_ ms: Int) -> AVAudioFramePosition {
            let raw = (Double(ms) / 1000.0) * sampleRate
            return AVAudioFramePosition(min(max(raw, 0), Double(audioFile.length)))
          }
          let startFrame = frame(startMs ?? 0)
          let endFrame = endMs.map(frame) ?? audioFile.length
          let sameFormat = audioFile.processingFormat == format
          // One converter for the WHOLE slice, so resampler state carries
          // across chunks instead of clicking at every boundary.
          let converter = sameFormat
            ? nil : AVAudioConverter(from: audioFile.processingFormat, to: format)
          if !sameFormat && converter == nil {
            await analyzer.cancelAndFinishNow()
            collector.cancel()
            reply(SpeechErrorCode.transcribeError.error("audio format conversion unavailable"))
            return
          }
          audioFile.framePosition = startFrame
          var remaining = endFrame - startFrame
          // Pre-read the first chunk: a slice holding NO audio (bounds beyond
          // the file, or a truncated file whose header claims more than it
          // stores) must take the same empty-reply exit as the whole-file
          // path, never a finalize on an analyzer that was fed nothing.
          guard remaining > 0, let head = readSliceChunk(from: audioFile, remaining: &remaining)
          else {
            await analyzer.cancelAndFinishNow()
            collector.cancel()
            reply(["text": "", "segments": [[String: Any]]()])
            return
          }
          let feed = SliceFeed(
            file: audioFile, format: format, converter: converter, head: head,
            remaining: remaining)
          try await analyzer.start(inputSequence: feed)
          try await analyzer.finalizeAndFinishThroughEndOfInput()
        }

        let text = try await collector.value
        // Timed segments come from the attributed runs (attributeOptions
        // [.audioTimeRange]); the full text is the result text directly.
        reply(["text": text.plainText, "segments": analyzerSegments(from: text)])
      } catch {
        collected?.cancel()
        if let analyzer = runningAnalyzer { await analyzer.cancelAndFinishNow() }
        reply(SpeechErrorCode.transcribeError.error("\(error)"))
      }
    }
  }
}

/// Streams on-device model-install progress for the requested locale over the
/// `opentranscribe/speech/model` EventChannel. Single-flight: a new listen supersedes
/// any in-flight install and abandons its stream (the Dart engine serializes
/// overlapping installs onto this handler, one at a time). Payloads: {fraction, done:false} while installing, then a terminal
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
    // Install the nearest supported model for the requested tag, using the SAME
    // transcriber shape as the transcribe paths, so the install request can never
    // under-install relative to what transcription will actually need.
    let locale = await resolvedLocale(localeId)
    let transcriber = makeTimedTranscriber(locale: locale)
    do {
      // Reservations are NOT trimmed here: multiple languages may be held at
      // once, and the only release is the explicit removeLanguage call. A full
      // cap surfaces as the typed reservation_cap below.
      let status = await loggedAssetStatus(transcriber, locale: locale)
      guard let downloader = try await reserveAndRequestInstall(transcriber, locale: locale) else {
        emit(["fraction": 1.0, "done": true], generation: gen)  // already installed
        return
      }
      // Poll the fraction rather than KVO-observing it: the request's Progress
      // gains its real children only once downloadAndInstall is underway, so an
      // observation taken here can watch a husk that never moves (the bug that
      // held the UI at 0% through whole downloads). Reading fresh each tick sees
      // whatever object currently carries the fraction; unchanged reads are not
      // re-emitted.
      let progressTask = Task { [weak self] in
        var last = -1.0
        while !Task.isCancelled {
          let fraction = downloader.progress.fractionCompleted
          if fraction > last + 0.001 {
            last = fraction
            self?.emit(["fraction": fraction, "done": false], generation: gen)
          }
          try? await Task.sleep(nanoseconds: 150_000_000)
        }
      }
      defer { progressTask.cancel() }
      do {
        try await downloader.downloadAndInstall()
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw ModelInstallError(underlying: error, status: status)
      }
      emit(["fraction": 1.0, "done": true], generation: gen)
    } catch is CancellationError {
      // Normal teardown (Dart unsubscribed), not a failure.
    } catch {
      // Same (code, message, extras) shape as the transcribe paths, with the
      // extras inlined into the payload so Dart branches without string parsing.
      let failure = installFailure(error)
      var payload = errorPayload(failure.code, failure.message)
      for (key, value) in failure.extras { payload[key] = value }
      emit(payload, generation: gen)
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
