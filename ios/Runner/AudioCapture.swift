import AVFoundation
import Flutter

// Real audio capture behind the Dart `AudioRecorder` contract. One AVAudioEngine
// tap writes a kept m4a file and fans buffers out to consumers, so a streaming
// recognizer can attach to the SAME session in a later phase. This layer knows
// nothing about Speech: it captures and writes audio, nothing more.

/// Owns the capture session: engine, tap, m4a writer, and consumer fan-out.
final class AudioCaptureSession {
  // Rebuilt after a media-services reset, which invalidates the old instance.
  private var engine = AVAudioEngine()
  private var audioFile: AVAudioFile?
  private var fileURL: URL?
  private var fileWriteError: String?
  private var startedAt: Date?
  private var isRunning = false
  private var isPaused = false

  // Input-level aggregation across tap buffers. Written on the tap thread;
  // reset from the main thread in start(), before the tap is installed.
  private var levelSumSquares: Float = 0
  private var levelFrames = 0

  // Results of the last finished capture, so stop() stays correct even when an
  // interruption already tore the session down. That replay is load-bearing: the
  // service's stop-after-interruption path relies on it. Main-thread state, but
  // written/read under the lock alongside the file fields for one consistent rule.
  private var lastName = ""
  private var lastURL: URL?
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

  /// Capture lifecycle strings sent to Dart: recording / paused / interrupted /
  /// stopped. These strings must match _statusFrom in platform_audio_recorder.dart.
  var onStatus: ((String) -> Void)?

  /// Normalized input level (0..1) while capturing, for the live waveform.
  /// Fired on the main thread at roughly 20 Hz; silent while paused or idle.
  var onLevel: ((Double) -> Void)?

  /// Whether a capture is live now. Lets the plugin replay status to a late listener.
  var isCapturing: Bool { isRunning }

  /// Whether the live capture is paused, so the replay can say so.
  var isCapturePaused: Bool { isPaused }

  enum CaptureError: LocalizedError {
    case alreadyRunning
    case noInput
    case notRunning
    case alreadyPaused
    case notPaused
    case routeChanged

    var code: String {
      switch self {
      case .alreadyRunning: return "already_running"
      case .noInput: return "no_input"
      case .notRunning: return "not_running"
      case .alreadyPaused: return "already_paused"
      case .notPaused: return "not_paused"
      case .routeChanged: return "route_changed"
      }
    }

    var errorDescription: String? {
      switch self {
      case .alreadyRunning: return "capture already running"
      case .noInput: return "no audio input available"
      case .notRunning: return "no capture running"
      case .alreadyPaused: return "capture already paused"
      case .notPaused: return "capture not paused"
      case .routeChanged: return "audio route changed during pause"
      }
    }
  }

  init() {
    // Observed for the session's whole lifetime, not per-capture: a mediaserverd
    // crash while IDLE also invalidates the engine, and without this the next
    // start() would run against a dead instance until app relaunch.
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleMediaServicesReset(_:)),
      name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
  }

  /// The durable, app-private directory for kept recordings:
  /// Application Support/recordings. Created on demand with data protection so a
  /// file is encrypted at rest when the device is locked, yet stays writable if the
  /// screen locks mid-recording (.completeUnlessOpen). New files inherit the
  /// directory's protection class. Defaults to excluded from backup so nothing
  /// rides iCloud off-device until the user opts in.
  static func recordingsDirectory() throws -> URL {
    let fm = FileManager.default
    let base = try fm.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var dir = base.appendingPathComponent("recordings", isDirectory: true)
    if !fm.fileExists(atPath: dir.path) {
      try fm.createDirectory(
        at: dir, withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.completeUnlessOpen])
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try dir.setResourceValues(values)
      } catch {
        // Never let the directory exist without its exclusion: a later call would
        // see it and skip this block, silently failing open on the one rule. Remove
        // the empty dir so the next call retries creation plus exclusion atomically.
        // (Accepted residue: if this removeItem ALSO fails, the dir persists
        // unexcluded. We deliberately do not re-assert exclusion on the exists path,
        // because that would silently override a user's backup opt-in every call.)
        try? fm.removeItem(at: dir)
        throw error
      }
    }
    return dir
  }

  /// Includes or excludes the whole recordings directory from device backup.
  /// Directory-level exclusion covers every kept file, present and future.
  static func setBackupExcluded(_ excluded: Bool) throws {
    var dir = try recordingsDirectory()
    var values = URLResourceValues()
    values.isExcludedFromBackup = excluded
    try dir.setResourceValues(values)
  }

  /// Registers a consumer of buffers and the stop signal (a recognizer finalizes on
  /// stop). Returns a token to remove it. Subscriptions persist across start/stop
  /// cycles; removing them is the caller's responsibility. Threading: onBuffer fires
  /// on the capture tap thread, onStop on the main thread.
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

    // Capture owns the shared audio session while recording. Any live playback is
    // stopped first WITH a terminal event, so its UI never shows a phantom
    // "playing" while the mic reroutes the session underneath it.
    PlaybackHub.yieldToCapture()

    let session = AVAudioSession.sharedInstance()
    // .measurement disables system input processing (AGC/EQ) for a raw, consistent
    // signal; .allowBluetooth permits headset mics at HFP quality. Both are
    // deliberate defaults to re-evaluate on device once real recordings exist.
    try session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth])
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw CaptureError.noInput
    }

    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: format.sampleRate,
      AVNumberOfChannelsKey: format.channelCount,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
    let url: URL
    let file: AVAudioFile
    do {
      // Kept audio lives in a durable, protected, app-private directory, not temp.
      url = try AudioCaptureSession.recordingsDirectory()
        .appendingPathComponent("otr-\(UUID().uuidString).m4a")
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

    // Before the tap exists, which is the only moment nothing else can be
    // writing these: a previous session may have ended mid-aggregation, and its
    // residue must not color this session's first level emission. Reset after
    // installTap (or after engine.start()) and the tap thread is already
    // accumulating into them.
    levelSumSquares = 0
    levelFrames = 0

    // 1024 frames per buffer: ~21ms at 48kHz, small enough for responsive live
    // partials, large enough to keep per-buffer overhead trivial.
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

      // Input level for the live waveform: RMS over the buffer, to dBFS, then
      // normalized so -60dB..0dB maps to 0..1. Aggregated by frame count, not
      // buffer count: the tap's 1024-frame request is advisory and devices
      // deliver larger buffers, so ~2048 frames keeps the cadence near 20 Hz
      // regardless of what the hardware hands us.
      if let data = buffer.floatChannelData?[0] {
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames { sum += data[i] * data[i] }
        self.levelSumSquares += sum
        self.levelFrames += frames
        if self.levelFrames >= 2048 {
          let rms = sqrt(self.levelSumSquares / Float(self.levelFrames))
          let db = 20 * log10(max(rms, 1e-6))
          let level = min(max((Double(db) + 60) / 60, 0), 1)
          self.levelSumSquares = 0
          self.levelFrames = 0
          DispatchQueue.main.async { [weak self] in self?.onLevel?(level) }
        }
      }
    }

    engine.prepare()
    do {
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      lock.lock()
      audioFile = nil
      let orphan = fileURL
      fileURL = nil
      fileWriteError = nil
      lock.unlock()
      // AVAudioFile already created the (empty) file; drop it so a failed start
      // does not leave a 0-byte m4a behind in the durable directory.
      if let orphan = orphan { try? FileManager.default.removeItem(at: orphan) }
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw error
    }

    // A fresh capture invalidates the previous outcome, so a stray stop() can never
    // replay an older session's file as if it were this one. Cleared only AFTER
    // every failable step above: a failed start must not wipe an unconsumed
    // interruption outcome (its file would become undiscoverable). The interruption
    // replay this state exists for repopulates it at teardown.
    lock.lock()
    lastName = ""
    lastURL = nil
    lastDurationMs = 0
    lastWriteError = nil
    lock.unlock()

    isRunning = true
    isPaused = false
    startedAt = Date()
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleInterruption(_:)),
      name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    // A route loss (earbuds die, mic unplugged) stops the engine WITHOUT an
    // interruption notification. It must finalize like an interruption, or capture
    // dies silently while Dart still shows "recording". (The media-services-reset
    // observer is registered for the session's lifetime in init.)
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleConfigurationChange(_:)),
      name: .AVAudioEngineConfigurationChange, object: engine)
    onStatus?("recording")
  }

  struct Outcome {
    let name: String
    let durationMs: Int
    let writeError: String?
  }

  func stop() -> Outcome {
    // Emit "stopped" only when this call actually ended a capture: after an
    // interruption already tore down, the stream carried "interrupted" and a second
    // terminal event would double-count captures for a persistent listener.
    let endedCapture = isRunning
    teardown()
    if endedCapture { onStatus?("stopped") }
    lock.lock()
    defer { lock.unlock() }
    return Outcome(name: lastName, durationMs: lastDurationMs, writeError: lastWriteError)
  }

  /// Suspends capture without ending it: the engine pauses, so the tap goes
  /// silent, the file stays open, and consumers stay attached. Resume continues
  /// into the same file; seal-time duration stays honest because it counts
  /// frames written, not wall clock. The mic is genuinely off while paused.
  func pause() throws {
    guard isRunning else { throw CaptureError.notRunning }
    guard !isPaused else { throw CaptureError.alreadyPaused }
    engine.pause()
    isPaused = true
    onStatus?("paused")
  }

  /// Resumes a paused capture. A failure leaves the session paused, never
  /// half-running, so the caller can still stop or cancel cleanly. A route
  /// change during the pause (earbuds died, headphones plugged) can swap the
  /// input format out from under the open file; resuming then would either
  /// crash in CoreAudio or write-fail every buffer while status says
  /// recording. Detect it and finalize as an interruption instead: the
  /// pre-pause audio is kept and auto-saved.
  func resume() throws {
    guard isRunning, isPaused else { throw CaptureError.notPaused }
    let input = engine.inputNode.outputFormat(forBus: 0)
    lock.lock()
    let fileFormat = audioFile?.processingFormat
    lock.unlock()
    if let fileFormat = fileFormat,
      input.sampleRate != fileFormat.sampleRate || input.channelCount != fileFormat.channelCount
    {
      teardown()
      onStatus?("interrupted")
      throw CaptureError.routeChanged
    }
    try engine.start()
    isPaused = false
    onStatus?("recording")
  }

  /// Ends capture and deletes its audio: the discard path for a recording the
  /// user never wanted. Quiet when idle so Dart can cancel defensively.
  func cancel() {
    let endedCapture = isRunning
    teardown()
    discardLastRecording()
    if endedCapture { onStatus?("stopped") }
  }

  /// Removes the last capture's file. Called when a stop produced no audio, so a
  /// header-only m4a does not sit in the durable directory forever, unreferenced by
  /// any entry and invisible to deletion.
  func discardLastRecording() {
    lock.lock()
    let url = lastURL
    lastURL = nil
    lastName = ""
    lastDurationMs = 0
    lastWriteError = nil
    lock.unlock()
    if let url = url { try? FileManager.default.removeItem(at: url) }
  }

  /// Forgets the last outcome once Dart has taken custody of the file: an entry
  /// now references it, so a later defensive cancel must not be able to delete
  /// it. An unconsumed interruption outcome (torn down natively, not yet
  /// processed by Dart) deliberately stays discardable.
  func consumeLastOutcome() {
    lock.lock()
    lastName = ""
    lastURL = nil
    lastDurationMs = 0
    lastWriteError = nil
    lock.unlock()
  }

  /// Finalizes the file and engine exactly once. Idempotent so a stop() after an
  /// interruption returns the already-captured result rather than re-running.
  /// Always called on the main thread.
  private func teardown() {
    guard isRunning else { return }
    isRunning = false
    isPaused = false

    // Unconditional: a paused engine reports isRunning false but still holds
    // prepared resources; stop() is harmless on an already-stopped engine.
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)

    lock.lock()
    let file = audioFile
    let url = fileURL
    audioFile = nil
    fileURL = nil
    lastWriteError = fileWriteError
    lastName = url?.lastPathComponent ?? ""
    lastURL = url
    lock.unlock()

    // Duration from encoded frames, not wall clock, so it matches the real file.
    var durationMs: Int
    if let file = file, file.processingFormat.sampleRate > 0 {
      durationMs = Int(Double(file.length) / file.processingFormat.sampleRate * 1000)
    } else if let startedAt = startedAt {
      durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
    } else {
      durationMs = 0
    }
    startedAt = nil

    // Finalize the container explicitly where the API allows it: the moov atom is
    // otherwise written in dealloc, which cannot report failure. In the disk-full
    // scenario that finalization write is the likeliest thing to fail; report no
    // audio then, so Dart discards instead of persisting an entry no player or
    // transcriber can ever open.
    if #available(iOS 18.0, *), let file = file {
      do {
        try file.close()
      } catch {
        lock.lock()
        lastWriteError = "finalize failed: \(error)"
        lock.unlock()
        durationMs = 0
      }
    }

    lock.lock()
    lastDurationMs = durationMs
    lock.unlock()

    // Seal the finished file explicitly: relying on directory inheritance alone
    // can silently degrade to a weaker class. (Data protection is a no-op on a
    // device with no passcode; that is an iOS limitation, not ours.)
    if let url = url {
      try? FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
    }

    lock.lock()
    let stops = consumers.values.map { $0.onStop }
    lock.unlock()
    for stop in stops { stop() }

    NotificationCenter.default.removeObserver(
      self, name: AVAudioSession.interruptionNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: .AVAudioEngineConfigurationChange, object: nil)
    // Defensive symmetry with the player's guard. Under current invariants playback
    // can never be active here (play/resume refuse during capture), so this guard
    // is insurance against a future entry point, not a reachable state.
    if !PlaybackHub.isActive {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  @objc private func handleInterruption(_ note: Notification) {
    guard let info = note.userInfo,
      let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw), type == .began
    else { return }
    // iOS stops the engine on interruption. Finalize cleanly and end the capture,
    // preserving the kept audio up to this point. We do not auto-resume (that needs
    // a new file); the user restarts. Hop to main so this cannot race stop().
    // Known, accepted window: a queued notification delivered after a stop+start
    // pair completed would tear down the new session; unreachable with the current
    // Dart service (two platform-channel round trips inside one main hop).
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.isRunning else { return }
      self.teardown()
      self.onStatus?("interrupted")
    }
  }

  /// The engine stopped because the audio route changed (earbuds died, mic
  /// unplugged). Same outcome as an interruption: finalize and keep the audio.
  @objc private func handleConfigurationChange(_ note: Notification) {
    DispatchQueue.main.async { [weak self] in
      // While paused the engine is legitimately not running, so a benign route
      // change (headphones in) must not read as engine death. A route lost
      // during a pause surfaces at resume, which fails and leaves the session
      // paused for a clean stop or cancel.
      guard let self = self, self.isRunning, !self.isPaused, !self.engine.isRunning else { return }
      self.teardown()
      self.onStatus?("interrupted")
    }
  }

  /// mediaserverd crashed; the engine instance is invalid, whether or not a capture
  /// was running. Swap in a fresh engine FIRST, so the finalize below never messages
  /// the dead one (Apple: discard it without further use), then finalize what audio
  /// we have. The next start() then works without an app relaunch.
  @objc private func handleMediaServicesReset(_ note: Notification) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.engine = AVAudioEngine()
      if self.isRunning {
        self.teardown()
        self.onStatus?("interrupted")
      }
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

/// Sink holder for the input-level EventChannel. Levels are ephemeral, so there
/// is no replay: a listener simply starts receiving the next emission.
final class LevelStreamHandler: NSObject, FlutterStreamHandler {
  var sink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}

/// Bridges the capture session to Dart: MethodChannel for control, EventChannels
/// for capture status and input level.
final class AudioRecorderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let session = CaptureHub.session
  private var statusSink: FlutterEventSink?
  private let levelHandler = LevelStreamHandler()

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AudioRecorderPlugin()
    // Channel names + payload shapes: must match platform_audio_recorder.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/audio", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "opentranscribe/audio/status", binaryMessenger: registrar.messenger())
    let levels = FlutterEventChannel(
      name: "opentranscribe/audio/level", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    levels.setStreamHandler(instance.levelHandler)
    registrar.addMethodCallDelegate(instance, channel: methods)
    instance.session.onStatus = { [weak instance] status in
      DispatchQueue.main.async { instance?.statusSink?(status) }
    }
    // onLevel already fires on main.
    instance.session.onLevel = { [weak instance] level in
      instance?.levelHandler.sink?(level)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    statusSink = eventSink
    // Replay the live state so a listener that subscribed after start() is not stale.
    if session.isCapturing { eventSink(session.isCapturePaused ? "paused" : "recording") }
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
    case "pause":
      do {
        try session.pause()
        result(nil)
      } catch let error as AudioCaptureSession.CaptureError {
        result(FlutterError(code: error.code, message: error.errorDescription, details: nil))
      } catch {
        result(FlutterError(code: "capture_failed", message: "\(error)", details: nil))
      }
    case "resume":
      do {
        try session.resume()
        result(nil)
      } catch let error as AudioCaptureSession.CaptureError {
        result(FlutterError(code: error.code, message: error.errorDescription, details: nil))
      } catch {
        result(FlutterError(code: "capture_failed", message: "\(error)", details: nil))
      }
    case "cancel":
      session.cancel()
      result(nil)
    case "stop":
      let outcome = session.stop()
      if outcome.durationMs > 0 {
        // Keep the recording even if a write error truncated it: partial audio is
        // better than losing it, and it can be re-transcribed. Any write error was
        // already logged; we never fail a capture that produced audio. Dart takes
        // custody of the file here, so the outcome is consumed: a later defensive
        // cancel must not be able to delete what an entry now references.
        session.consumeLastOutcome()
        result(["name": outcome.name, "durationMs": outcome.durationMs])
      } else {
        // No audio at all (e.g. the file could not be created). This is a real
        // failure, and the header-only file must not linger in the durable
        // directory: no entry will ever reference it.
        session.discardLastRecording()
        result(
          FlutterError(
            code: "capture_failed", message: outcome.writeError ?? "no audio captured",
            details: nil))
      }
    case "recordingsDirectory":
      do {
        result(try AudioCaptureSession.recordingsDirectory().path)
      } catch {
        result(FlutterError(code: "storage_failed", message: "\(error)", details: nil))
      }
    case "probeAudio":
      // Readability probe for the reconciliation sweep: a kept file that opens
      // reports its duration (recoverable as an entry); one that does not (e.g. an
      // unfinalized header after a mid-recording kill) reports nil (delete it).
      guard let name = (call.arguments as? [String: Any])?["name"] as? String,
        !name.isEmpty, !name.contains("/")
      else {
        result(FlutterError(code: "bad_args", message: "name required", details: nil))
        return
      }
      do {
        let url = try AudioCaptureSession.recordingsDirectory().appendingPathComponent(name)
        let file = try AVAudioFile(forReading: url)
        let sampleRate = file.processingFormat.sampleRate
        result(sampleRate > 0 ? Int(Double(file.length) / sampleRate * 1000) : nil)
      } catch {
        result(nil)
      }
    case "setBackupExcluded":
      do {
        let excluded = (call.arguments as? [String: Any])?["excluded"] as? Bool ?? true
        try AudioCaptureSession.setBackupExcluded(excluded)
        result(nil)
      } catch {
        result(FlutterError(code: "storage_failed", message: "\(error)", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
