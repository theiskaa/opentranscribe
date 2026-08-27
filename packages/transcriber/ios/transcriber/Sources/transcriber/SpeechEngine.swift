import AVFoundation
import Flutter
import Speech

// Apple's speech engines behind the Dart TranscriptionEngine contract. Every
// call names its engine ("analyzer" is the iOS 26 SpeechAnalyzer, "classic" the
// SFSpeechRecognizer) and the handler routes on it. Live: attaches to the shared
// capture session as a consumer and streams TranscriptEvents back over an
// EventChannel. Batch: transcribes a kept file. On-device only; neither engine
// ever uses a server recognizer.

/// Channel error codes. This set is the cross-boundary contract with
/// apple_speech_engines.dart; keep them in sync.
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

  /// The failure pair, or nil when ready. Convenience for checkAvailability's
  /// classic arm.
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

/// Whether the SpeechAnalyzer stack can transcribe on this device, behind the
/// analyzerAvailable method. The OS version alone does not answer it: the
/// analyzer model needs a 16-core Neural Engine, so 8-core devices (iPhone 11,
/// 11 Pro, SE 2) run iOS 26 yet answer an empty supported list and can never
/// install a model, and a device that cannot reach the asset catalog answers
/// empty too. Resolved once per process, so the answer cannot flip within a
/// session. Routing does NOT consult it: each call names its engine, and Dart
/// derives which engine to use from this one answer. The simulator answers
/// true: its explicit fail-fast arms stay the ones deciding there.
@available(iOS 26.0, *)
private enum AnalyzerCapability {
  // The probe races a deadline because supportedLocales has wedged a native
  // handler in the field without ever answering (the per-channel launch
  // watchdog in Deps.init exists for exactly that): no answer in time counts
  // as unavailable, so Dart derives the classic engine instead of wedging
  // launch. The deadline sits well under that watchdog so the answer still
  // reaches it.
  private static let probe = Task { () -> Bool in
    await withCheckedContinuation { continuation in
      let latch = FirstAnswerLatch(continuation)
      Task { latch.finish(!(await SpeechTranscriber.supportedLocales.isEmpty)) }
      Task {
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        latch.finish(false)
      }
    }
  }
  static var usable: Bool {
    get async {
      #if targetEnvironment(simulator)
        return true
      #else
        return await probe.value
      #endif
    }
  }
}

/// Resumes a continuation with whichever answer arrives first; the loser's
/// call (including a query that resolves long after the deadline) is a no-op.
private final class FirstAnswerLatch: @unchecked Sendable {
  private let lock = NSLock()
  private var resumed = false
  private let continuation: CheckedContinuation<Bool, Never>

  init(_ continuation: CheckedContinuation<Bool, Never>) {
    self.continuation = continuation
  }

  func finish(_ value: Bool) {
    lock.lock()
    let first = !resumed
    resumed = true
    lock.unlock()
    if first { continuation.resume(returning: value) }
  }
}

/// The engine a channel call routes to. This is the cross-boundary vocabulary
/// with apple_speech_engines.dart: "analyzer" is the iOS 26 SpeechAnalyzer,
/// "classic" the SFSpeechRecognizer path.
private enum EngineRoute: String {
  case analyzer
  case classic
}

/// The route named by a call's engine argument. Missing defaults to analyzer
/// (the argument convention, like localeId's en-US); unknown is nil and the
/// caller replies bad_args, so a misspelled engine can never silently
/// transcribe on the wrong stack.
private func engineRoute(_ arguments: Any?) -> EngineRoute? {
  guard let value = (arguments as? [String: Any])?["engine"] else { return .analyzer }
  guard let raw = value as? String else { return nil }
  return EngineRoute(rawValue: raw)
}

/// The one spelling of the unknown-engine refusal.
private let unknownEngineMessage = "unknown engine"

/// The classic recognizer's locale list. An approximation: the classic API cannot
/// cheaply report per-locale on-device support (that needs a recognizer instance
/// per locale), so this lists all recognizer locales; availability still gates the
/// honest answer per tag. The manual underscore-to-dash mapping is deliberate: it
/// keeps the exact tags this path has always produced, which stored locale ids and
/// the Dart-side comparisons ride on; .identifier(.bcp47) can respell them.
private func classicSupportedTags() -> [String] {
  SFSpeechRecognizer.supportedLocales()
    .map { $0.identifier.replacingOccurrences(of: "_", with: "-") }
    .sorted()
}

/// The classic path's reservation answer: no reservation concept, and max 0 is
/// the contract's "no cap here". This and the two model answers below keep the
/// routing uniform; today's dictation engine is not model-managed, so only a
/// future managed classic caller would actually send them.
private func classicReservationInfo() -> [String: Any] {
  ["max": 0, "reserved": [String]()]
}

/// The classic path's installed answer: no app-managed model, so an available
/// on-device recognizer IS the model.
private func classicModelInstalled(_ localeId: String) -> Bool {
  onDeviceRecognizer(localeId) != nil
}

/// The classic path's installed-locales answer: the classic API cannot enumerate
/// installed models cheaply (a recognizer per locale), so per-tag localeStatus
/// answers readiness.
private func classicInstalledLocales() -> [String] { [] }

/// The classic path's per-locale status: no asset management, so an available
/// on-device recognizer IS the installed model, and there is no reservation
/// concept to fail on.
private func classicLocaleStatus(_ localeId: String) -> [String: Any] {
  let installed = onDeviceRecognizer(localeId) != nil
  return [
    "status": installed ? "installed" : "unsupported",
    "reserved": true,
    "resolvedTag": localeId,
  ]
}

/// A plain `String` view of an attributed transcript.
@available(iOS 15.0, *)
private extension AttributedString {
  var plainText: String { String(characters) }
}

/// Timed segments from the classic SFTranscription. Carries per-segment
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

/// The classic batch feeder's own failure: PCM buffer allocation refused, which
/// only an absurd processing format produces.
private enum SpeechFeedError: Error { case bufferAllocation }

/// Rebuilds a cumulative transcript from classic recognizer partials. In several
/// locales the on-device recognizer holds only the current utterance: a pause (in
/// weak locales, nearly every word) RESETS bestTranscription, so the latest
/// partial alone loses everything before the reset. A reset is detected by the
/// new partial starting at or after the current utterance's end; the finished
/// utterance is committed and the transcript is the committed text plus the
/// current utterance. A partial starting inside the current utterance, or
/// reusing its start, is the recognizer's own rewrite and replaces it (the
/// start test matters: a one-short-word utterance ends within the slack of its
/// own start, and only the reused start tells its rewrite from the next
/// utterance). When the recognizer carries the whole take in one transcription
/// (en-US does), every partial reuses the first word's start and this reduces
/// to plain replacement. Zero-timestamp results (a known on-device quirk) also
/// reduce to replacement rather than misfiling rewrites as resets.
private final class UtteranceStitcher {
  private let lock = NSLock()
  private var committedText: [String] = []
  private var committedSegments: [[String: Any]] = []
  private var currentText = ""
  private var currentSegments: [[String: Any]] = []
  private var currentStart: TimeInterval = -1
  private var currentEnd: TimeInterval = 0

  /// Timing slack between a rewrite and a reset: rewrites start inside the
  /// current utterance, resets at or a hair before its end.
  private static let resetSlack: TimeInterval = 0.15

  func feed(_ transcription: SFTranscription) {
    let text = transcription.formattedString
    // An empty partial is the recognizer clearing at a boundary; absorbing it
    // would erase the uncommitted utterance it just delivered.
    if text.isEmpty, transcription.segments.isEmpty { return }
    let start = transcription.segments.first?.timestamp ?? 0
    let end = transcription.segments.last.map { $0.timestamp + $0.duration } ?? 0
    lock.lock()
    defer { lock.unlock() }
    let resets =
      !currentText.isEmpty && currentEnd > 0 && start > currentStart
      && start >= currentEnd - Self.resetSlack
    if resets {
      committedText.append(currentText)
      committedSegments.append(contentsOf: currentSegments)
    }
    if resets || currentStart < 0 { currentStart = start }
    currentText = text
    currentSegments = segments(from: transcription)
    if end > 0 { currentEnd = end }
  }

  /// How far into the audio recognition has reached, for the batch feeder's
  /// pacing. Advances only while the recognizer emits; silence moves nothing.
  var progressSeconds: TimeInterval {
    lock.lock()
    defer { lock.unlock() }
    return currentEnd
  }

  var whole: (text: String, segments: [[String: Any]]) {
    lock.lock()
    defer { lock.unlock() }
    var parts = committedText
    if !currentText.isEmpty { parts.append(currentText) }
    return (parts.joined(separator: " "), committedSegments + currentSegments)
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

/// The channel's status strings; one spelling with apple_speech_engines.dart.
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
/// honestly downstream instead of silently becoming another language. When the
/// equivalence probe knows nothing, any supported variant of the same LANGUAGE
/// still counts (tr-GE finds tr-TR): entries recorded under a region no model
/// ships for must not fail a language that exists.
@available(iOS 26.0, *)
private func resolvedLocale(_ localeId: String) async -> Locale {
  let requested = Locale(identifier: localeId)
  if let match = await SpeechTranscriber.supportedLocale(equivalentTo: requested) { return match }
  if let language = requested.language.languageCode {
    let variant = await SpeechTranscriber.supportedLocales
      .filter { $0.language.languageCode == language }
      .min { $0.identifier(.bcp47) < $1.identifier(.bcp47) }
    if let variant = variant { return variant }
  }
  return requested
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
  // A teardown landing while start() is awaiting is run by the start path itself
  // after start() returns, but published too late for a successor that already
  // captured pendingTeardown; that successor starts unchained beside the closing
  // analyzer (a known chain gap).
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
        lock.lock()
        // Teardown landed while start() was awaiting. An empty slot means
        // finish()/abort() saw the analyzer unstarted and skipped the
        // wind-down: ours to run. A filled slot means a graceful wind-down is
        // already in flight, and launching a cancel beside it would cut the
        // session's final live event short.
        if teardownTask == nil {
          teardownTask = Task { _ = try? await analyzer.cancelAndFinishNow() }
        }
        lock.unlock()
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
  // Classic batches cancelled through cancelBatches, so their error callback
  // answers cancellation honestly instead of salvaging heard-so-far text the
  // caller has abandoned. Entries are removed by the batch's own reply.
  private var cancelledBatches: Set<Int> = []
  // The iOS 26 analyzer-path counterpart to batchTasks, keyed from the same
  // nextBatchId sequence.
  private var batchAnalyzerTasks: [Int: Task<Void, Never>] = [:]
  // The analyzer counterpart of the classic path's `replied` latch: a task
  // fast enough to finish before its registration runs leaves a tombstone
  // here, so the registration cannot re-insert a dead task nothing would
  // ever remove. Guarded by [lock].
  private var finishedAnalyzerBatches: Set<Int> = []
  private var nextBatchId = 0

  // Streams model-install progress on its own channel. Held here so it lives as long
  // as the plugin.
  private let modelInstaller = ModelInstallStreamHandler()

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SpeechEnginePlugin()
    // Channel names + payload shapes: must match apple_speech_engines.dart.
    let methods = FlutterMethodChannel(
      name: "transcriber/speech", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "transcriber/speech/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    let modelEvents = FlutterEventChannel(
      name: "transcriber/speech/model", binaryMessenger: registrar.messenger())
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

  private func startLive(localeId: String, session: Int, route: EngineRoute) {
    // Re-entrancy guard: a new live session tears down any previous one first.
    stopLive()
    liveSession = session
    // One generation for BOTH engines: task cancellation is best-effort, so a
    // superseded session (classic or analyzer) can still be mid-emit; the guard at
    // delivery time is what actually keeps stale text, finals, and cancellation
    // errors out of the next session's stream.
    liveGeneration += 1
    let generation = liveGeneration
    if route == .classic {
      startLiveClassic(localeId: localeId, generation: generation)
      return
    }
    if #available(iOS 26.0, *) {
      #if targetEnvironment(simulator)
        // No on-device model on the simulator; fail fast instead of hanging on a
        // model download that never completes. Tagged (via emitLive) so Dart
        // routes it to this session's stream. The classic route above needs no
        // counterpart: resolveRecognizer already fails fast there.
        emitLive(
          errorPayload(.onDeviceUnavailable, "on-device speech is unavailable on the simulator"),
          generation: generation)
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
      #endif
    } else {
      emitLive(
        errorPayload(.onDeviceUnavailable, "the analyzer engine needs iOS 26"),
        generation: generation)
    }
  }

  private func startLiveClassic(localeId: String, generation: Int) {
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
    let stitcher = UtteranceStitcher()
    let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self = self else { return }
      if let result = result {
        stitcher.feed(result.bestTranscription)
        let whole = stitcher.whole
        var payload: [String: Any] = [
          "text": whole.text,
          "isFinal": result.isFinal,
        ]
        if result.isFinal { payload["segments"] = whole.segments }
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
      if let live = analyzerLive as? SpeechAnalyzerLiveSession {
        live.cancel()
        // Hand this session's wind-down to the next startLive to await. Only
        // with a session to capture from: writing nil here would drop a stored
        // wind-down no start has consumed yet (the routine stop-then-start
        // flow).
        pendingAnalyzerTeardown = live.pendingTeardown
      }
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

  /// The call's engine route, or nil after replying bad_args for an unknown one.
  private func routedEngine(_ call: FlutterMethodCall, _ result: FlutterResult) -> EngineRoute? {
    if let route = engineRoute(call.arguments) { return route }
    result(SpeechErrorCode.badArgs.error(unknownEngineMessage))
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkAvailability":
      let localeId = (call.arguments as? [String: Any])?["localeId"] as? String ?? "en-US"
      guard let route = routedEngine(call, result) else { return }
      if route == .classic {
        resolveRecognizer(localeId) { resolution in
          result(["status": resolution.failure?.code.rawValue ?? "available"])
        }
        return
      }
      if #available(iOS 26.0, *) {
        // Analyzer availability tracks its model, not the classic recognizer.
        // Available = authorized and the locale is supported (the model
        // downloads once on first use if not yet installed).
        Task {
          let authorized = await requestSpeechAuthorization() == .authorized
          // Supported means a model exists for the language, including near
          // variants (de-AT counts via de-DE, tr-GE via tr-TR, matching what
          // transcription itself resolves); a wholly unsupported language
          // reports unavailable rather than ever falling back silently.
          let resolved = await resolvedLocale(localeId).identifier(.bcp47)
          let supported = await SpeechTranscriber.supportedLocales
            .contains { $0.identifier(.bcp47) == resolved }
          let status =
            !authorized
            ? SpeechErrorCode.permissionDenied.rawValue
            : (supported ? "available" : SpeechErrorCode.onDeviceUnavailable.rawValue)
          DispatchQueue.main.async { result(["status": status]) }
        }
      } else {
        result(["status": SpeechErrorCode.onDeviceUnavailable.rawValue])
      }
    case "analyzerAvailable":
      if #available(iOS 26.0, *) {
        Task {
          let available = await AnalyzerCapability.usable
          DispatchQueue.main.async { result(available) }
        }
      } else {
        result(false)
      }
    case "isModelInstalled":
      let localeId = (call.arguments as? [String: Any])?["localeId"] as? String ?? "en-US"
      guard let route = routedEngine(call, result) else { return }
      if route == .classic {
        result(classicModelInstalled(localeId))
        return
      }
      if #available(iOS 26.0, *) {
        Task {
          let resolved = await resolvedLocale(localeId)
          let installed = await modelLocaleInstalled(resolved.identifier(.bcp47))
          DispatchQueue.main.async { result(installed) }
        }
      } else {
        result(false)
      }
    case "supportedLocales":
      guard let route = routedEngine(call, result) else { return }
      if route == .classic {
        result(classicSupportedTags())
        return
      }
      if #available(iOS 26.0, *) {
        Task {
          let tags = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
          DispatchQueue.main.async { result(tags.sorted()) }
        }
      } else {
        result([String]())
      }
    case "installedLocales":
      guard let route = routedEngine(call, result) else { return }
      if route == .classic {
        result(classicInstalledLocales())
        return
      }
      if #available(iOS 26.0, *) {
        // Device-wide truth: assets are shared system assets, so this can list
        // languages another app or OS feature downloaded.
        Task {
          let tags = await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) }
          DispatchQueue.main.async { result(tags.sorted()) }
        }
      } else {
        result([String]())
      }
    case "localeStatus":
      let localeId = (call.arguments as? [String: Any])?["localeId"] as? String ?? "en-US"
      guard let route = routedEngine(call, result) else { return }
      if route == .classic {
        result(classicLocaleStatus(localeId))
        return
      }
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
        result(["status": "unsupported", "reserved": false, "resolvedTag": localeId])
      }
    case "reservationInfo":
      guard let route = routedEngine(call, result) else { return }
      if route == .classic {
        result(classicReservationInfo())
        return
      }
      if #available(iOS 26.0, *) {
        Task {
          let reserved = await reservedTagList()
          let max = AssetInventory.maximumReservedLocales
          DispatchQueue.main.async { result(["max": max, "reserved": reserved]) }
        }
      } else {
        result(["max": 0, "reserved": [String]()])
      }
    case "removeLanguage":
      // Strict, unlike the read-only handlers' en-US fallback: this one ACTS,
      // and garbage arguments must not release a language nobody named.
      guard let localeId = (call.arguments as? [String: Any])?["localeId"] as? String else {
        result(SpeechErrorCode.badArgs.error("localeId required"))
        return
      }
      guard let route = routedEngine(call, result) else { return }
      if route == .classic {
        // No app-managed assets to release on the classic path.
        result(false)
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
      guard let route = routedEngine(call, result) else { return }
      // Optional slice bounds, for one span of a mixed-language take.
      let startMs = (args["startMs"] as? NSNumber)?.intValue
      let endMs = (args["endMs"] as? NSNumber)?.intValue
      transcribeFile(
        path: path, localeId: localeId, startMs: startMs, endMs: endMs, route: route,
        result: result)
    case "cancelBatches":
      // Abandons every in-flight batch task; each one's own completion/defer
      // removes it from its registry, so the dictionaries are not cleared here
      // (that would race a reply already in flight and double-remove).
      lock.lock()
      let tasks = Array(batchTasks.values)
      cancelledBatches.formUnion(batchTasks.keys)
      let analyzerTasks = Array(batchAnalyzerTasks.values)
      lock.unlock()
      tasks.forEach { $0.cancel() }
      analyzerTasks.forEach { $0.cancel() }
      result(nil)
    case "startLive":
      let args = call.arguments as? [String: Any]
      let session = args?["session"] as? Int ?? 0
      guard let route = routedEngine(call, result) else { return }
      startLive(localeId: args?["localeId"] as? String ?? "en-US", session: session, route: route)
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

  /// Dispatches the batch to the routed engine. The simulator has no model for
  /// either, so it fails fast before routing.
  private func transcribeFile(
    path: String, localeId: String, startMs: Int?, endMs: Int?, route: EngineRoute,
    result: @escaping FlutterResult
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
      if route == .classic {
        transcribeFileClassicGuarded(
          path: path, localeId: localeId, startMs: startMs, endMs: endMs, result: result)
        return
      }
      if #available(iOS 26.0, *) {
        transcribeFileWithAnalyzer(
          path: path, localeId: localeId, startMs: startMs, endMs: endMs, result: result)
      } else {
        result(SpeechErrorCode.onDeviceUnavailable.error("the analyzer engine needs iOS 26"))
      }
    #endif
  }

  /// The classic batch behind the ranged-ask guard: a ranged ask FAILS here, never
  /// silently answers with the whole file as if it were the slice.
  private func transcribeFileClassicGuarded(
    path: String, localeId: String, startMs: Int?, endMs: Int?, result: @escaping FlutterResult
  ) {
    if startMs != nil || endMs != nil {
      result(
        SpeechErrorCode.transcribeError.error("ranged transcription needs the analyzer engine"))
      return
    }
    transcribeFileClassic(path: path, localeId: localeId, result: result)
  }

  /// Classic on-device batch. Deliberately NOT SFSpeechURLRecognitionRequest: in
  /// several locales the on-device URL request errors or finalizes empty on audio
  /// the buffer request transcribes fine (tr-TR reproduces both), so the file is
  /// decoded here and fed through the same buffer request the live path runs on.
  /// Partials stay on so [UtteranceStitcher] keeps the text the recognizer drops
  /// at utterance resets; the reply is the stitched whole, and an error arriving
  /// after speech was heard salvages what accumulated instead of failing the take.
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

      let request = SFSpeechAudioBufferRecognitionRequest()
      request.requiresOnDeviceRecognition = true
      request.shouldReportPartialResults = true

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
        self.cancelledBatches.remove(id)
        self.lock.unlock()
        DispatchQueue.main.async { result(value) }
      }

      let stitcher = UtteranceStitcher()
      // Flipped by the feeder before endAudio(). Errors before it are a
      // recognizer dying mid-file: those must FAIL, not answer the heard prefix
      // as a successful transcript (retranscribe would install the truncation
      // over a fuller stored one). Errors after it are the recognizer's
      // end-of-audio quirks, where the stitched text is the honest result.
      var audioEnded = false
      // Create the task OUTSIDE the lock: the same lock serves the realtime buffer
      // consumer, and holding it across an opaque framework call would contend with
      // the audio tap thread. `replied` closes the store-vs-reply ordering instead.
      let task = recognizer.recognitionTask(with: request) { recognitionResult, error in
        if let recognitionResult = recognitionResult {
          stitcher.feed(recognitionResult.bestTranscription)
          if recognitionResult.isFinal {
            let whole = stitcher.whole
            reply(["text": whole.text, "segments": whole.segments])
          }
        }
        if let error = error {
          self.lock.lock()
          let cancelled = self.cancelledBatches.contains(id)
          let ended = audioEnded
          self.lock.unlock()
          let whole = stitcher.whole
          if cancelled || !ended || whole.text.isEmpty {
            reply(SpeechErrorCode.transcribeError.error("\(error)"))
          } else {
            reply(["text": whole.text, "segments": whole.segments])
          }
        }
      }
      self.lock.lock()
      if !replied { self.batchTasks[id] = task }
      self.lock.unlock()

      let done: () -> Bool = {
        self.lock.lock()
        defer { self.lock.unlock() }
        return replied || self.cancelledBatches.contains(id)
      }
      let endAudio = {
        self.lock.lock()
        audioEnded = true
        self.lock.unlock()
        request.endAudio()
      }
      // Decode and feed off the main thread; the recognizer transcribes as the
      // buffers land, and endAudio() makes it finalize. Paced: decode outruns
      // on-device recognition by orders of magnitude, and the request queues
      // every appended buffer, so an unpaced feed holds a long take's whole
      // decoded PCM in memory. Feeding holds while more than the window sits
      // unrecognized, as long as progress still advances: silence advances
      // nothing, so a stall lets the feed continue rather than deadlock.
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
          let format = file.processingFormat
          var fedSeconds: TimeInterval = 0
          while !done() {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32 * 1024)
            else { throw SpeechFeedError.bufferAllocation }
            try file.read(into: buffer)
            if buffer.frameLength == 0 { break }
            request.append(buffer)
            fedSeconds += TimeInterval(buffer.frameLength) / format.sampleRate
            var lastProgress = stitcher.progressSeconds
            var stalledFor: TimeInterval = 0
            while !done(), fedSeconds - stitcher.progressSeconds > 30, stalledFor < 2 {
              usleep(100_000)
              let progress = stitcher.progressSeconds
              if progress > lastProgress {
                lastProgress = progress
                stalledFor = 0
              } else {
                stalledFor += 0.1
              }
            }
          }
          endAudio()
        } catch {
          // Finalize what was heard before the decode broke; with nothing heard
          // the recognizer may never call back, so fail the batch here (the
          // `replied` latch makes the two answers race safely).
          endAudio()
          if stitcher.whole.text.isEmpty {
            reply(SpeechErrorCode.transcribeError.error("audio decode failed: \(error)"))
          }
        }
      }
    }
  }

  /// iOS 26 on-device batch transcription with SpeechAnalyzer (the dispatcher above
  /// fails fast on the simulator before reaching here). The first call for a
  /// locale downloads Apple's on-device model once (this needs the network that one
  /// time, the single dent in the airplane-mode promise); after that it runs fully
  /// offline.
  /// A [startMs]/[endMs] slice transcribes ONE SPAN of a mixed-language take; its
  /// segment timings are relative to the slice, and Dart offsets them.
  @available(iOS 26.0, *)
  private func transcribeFileWithAnalyzer(
    path: String, localeId: String, startMs: Int?, endMs: Int?, result: @escaping FlutterResult
  ) {
    let url = URL(fileURLWithPath: path)
    // Mint the id before the task exists, so it can be registered the moment
    // the task handle is available; the task body runs concurrently with the
    // registration, which the finished-tombstone below accounts for.
    lock.lock()
    let id = nextBatchId
    nextBatchId += 1
    lock.unlock()
    let task = Task { [weak self] in
      defer {
        self?.lock.lock()
        if self?.batchAnalyzerTasks.removeValue(forKey: id) == nil {
          self?.finishedAnalyzerBatches.insert(id)
        }
        self?.lock.unlock()
      }
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

        // The one wind-down for every early exit below: cancel the analyzer
        // and the collector rather than awaiting a collector whose stream a
        // cancellation may end with CancellationError (misreported as a
        // transcribe error), then reply.
        func bail(_ value: Any) async {
          await analyzer.cancelAndFinishNow()
          collector.cancel()
          reply(value)
        }

        if startMs == nil && endMs == nil {
          if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
          } else {
            // No analyzable audio at all: the valid empty result.
            await bail(["text": "", "segments": [[String: Any]]()])
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
            await bail(SpeechErrorCode.transcribeError.error("no compatible audio format"))
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
            await bail(SpeechErrorCode.transcribeError.error("audio format conversion unavailable"))
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
            await bail(["text": "", "segments": [[String: Any]]()])
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
        // A cancelBatches() call surfaces here as CancellationError: the same
        // path as any other failure, replying onto a Dart future that has
        // already given up. Harmless.
        reply(SpeechErrorCode.transcribeError.error("\(error)"))
      }
    }
    lock.lock()
    if finishedAnalyzerBatches.remove(id) == nil { batchAnalyzerTasks[id] = task }
    lock.unlock()
  }
}

/// Streams on-device model-install progress for the requested locale over the
/// `transcriber/speech/model` EventChannel. Single-flight: a new listen supersedes
/// any in-flight install and abandons its stream (the Dart engine serializes
/// overlapping installs onto this handler, one at a time). Payloads: {fraction,
/// done:false} while installing, then a terminal {fraction:1, done:true};
/// {type:error,...} on failure.
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
    guard let route = engineRoute(arguments) else {
      emit(errorPayload(.badArgs, unknownEngineMessage), generation: gen)
      return nil
    }
    // No app-managed model on the classic path; nothing to download, so the
    // stream completes immediately.
    if route == .classic {
      emit(["fraction": 1.0, "done": true], generation: gen)
      return nil
    }
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
      emit(
        errorPayload(.modelInstallFailed, "the analyzer engine needs iOS 26"), generation: gen)
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
