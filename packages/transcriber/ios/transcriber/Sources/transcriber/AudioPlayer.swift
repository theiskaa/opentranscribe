import AVFoundation
import Flutter

// AVAudioPlayer behind the Dart `AudioPlayer` contract. Plays a kept file and reports
// position and lifecycle over an EventChannel. One playback at a time. Method calls
// and the position timer run on the main thread, and delegate/notification callbacks
// are hopped to main, so no locking is needed, unlike the capture session's realtime
// tap.

/// Lets capture see and stop the one live playback without coupling the two plugins.
/// Playback and capture share the global AVAudioSession; whichever starts must first
/// make the other yield, and neither may deactivate the session under the other.
enum PlaybackHub {
  static weak var player: AudioPlayerPlugin?

  /// Whether a playback is live (playing or paused) right now.
  static var isActive: Bool { player?.isActive ?? false }

  /// Stops any live playback with a terminal "stopped" event, so its UI never shows
  /// a phantom "playing" while capture rewires the session underneath it.
  static func yieldToCapture() { player?.yieldToCapture() }
}

final class AudioPlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, AVAudioPlayerDelegate
{
  private var player: AVAudioPlayer?
  private var ticker: Timer?
  private var stateSink: FlutterEventSink?
  // The last emitted state, replayed to a listener that subscribes mid-playback.
  private var lastPayload: [String: Any]?

  // Position update cadence while playing.
  private let tickInterval: TimeInterval = 0.2

  // Survives each teardown, so a replay keeps the chosen speed.
  private var rate: Float = 1

  /// Whether a player exists (playing or paused). Read by PlaybackHub for capture.
  var isActive: Bool { player != nil }

  override init() {
    super.init()
    // Observed for the plugin's whole lifetime, mirroring the capture session: a
    // mediaserverd crash invalidates the AVAudioPlayer, and without this the UI
    // would wedge at "playing" while later calls message a dead object.
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleMediaServicesReset(_:)),
      name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AudioPlayerPlugin()
    // Channel names + payload shapes: must match platform_audio_player.dart.
    let methods = FlutterMethodChannel(
      name: "transcriber/player", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "transcriber/player/state", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    registrar.addMethodCallDelegate(instance, channel: methods)
    PlaybackHub.player = instance
  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError?
  {
    stateSink = eventSink
    if let payload = lastPayload { eventSink(payload) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    // The subscription lifecycle does not control playback; only stop() does.
    stateSink = nil
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "play":
      guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
        result(FlutterError(code: "bad_args", message: "path required", details: nil))
        return
      }
      play(path: path, result: result)
    case "pause":
      pause()
      result(nil)
    case "resume":
      resume(result: result)
    case "seek":
      guard let ms = (call.arguments as? [String: Any])?["positionMs"] as? Int else {
        result(FlutterError(code: "bad_args", message: "positionMs required", details: nil))
        return
      }
      seek(toMs: ms)
      result(nil)
    case "stop":
      stop()
      result(nil)
    case "setRate":
      guard let rate = (call.arguments as? [String: Any])?["rate"] as? Double else {
        result(FlutterError(code: "bad_args", message: "rate required", details: nil))
        return
      }
      setRate(rate)
      result(nil)
    case "peaks":
      guard let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        let buckets = args["buckets"] as? Int
      else {
        result(FlutterError(code: "bad_args", message: "path and buckets required", details: nil))
        return
      }
      peaks(path: path, buckets: buckets, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// The recording's amplitude envelope, [buckets] values in 0...1, for drawing
  /// a waveform of a file that is not playing. Reading is decode work measured
  /// in whole seconds for a long take, and this handler runs on the MAIN thread
  /// - so it hops straight off it and comes back only to answer.
  private func peaks(path: String, buckets: Int, result: @escaping FlutterResult) {
    guard buckets > 0 else {
      result([Double]())
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let answer: Any
      do {
        answer = try readPeaks(path: path, buckets: buckets)
      } catch {
        answer = FlutterError(code: "peaks_failed", message: "\(error)", details: path)
      }
      DispatchQueue.main.async { result(answer) }
    }
  }

  /// Stops playback because capture is taking the session. Emits the terminal
  /// "stopped" so the playback UI ends cleanly instead of freezing at "playing".
  /// Does NOT deactivate the session: capture is about to seize it anyway, and a
  /// deactivate here (with its notify-others hint) would let a backgrounded app
  /// resume audibly for a beat and add churn to record start.
  func yieldToCapture() {
    guard let player = player else { return }
    let positionMs = Int(player.currentTime * 1000)
    let durationMs = Int(player.duration * 1000)
    teardown(deactivate: false)
    emit(status: "stopped", positionMs: positionMs, durationMs: durationMs)
  }

  private func play(path: String, result: @escaping FlutterResult) {
    // Playback and capture share the one global audio session; refuse to hijack its
    // category and route while a recording is live. The UI keeps them apart; this
    // enforces it at the boundary.
    if CaptureHub.session.isCapturing {
      result(
        FlutterError(code: "busy_recording", message: "cannot play while recording", details: nil))
      return
    }
    teardown(deactivate: false)  // replace any current playback
    do {
      let session = AVAudioSession.sharedInstance()
      // .playback plays through the speaker regardless of the mute switch, the
      // expected behavior for intentional playback of a saved entry.
      try session.setCategory(.playback, mode: .spokenAudio)
      try session.setActive(true)

      let newPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
      newPlayer.delegate = self
      // Before prepareToPlay: rate is only honoured when enabled up front, and
      // enabling it afterwards leaves the first stretch playing at 1x.
      newPlayer.enableRate = true
      newPlayer.rate = rate
      newPlayer.prepareToPlay()
      player = newPlayer
      guard newPlayer.play() else {
        failPlayback("player refused to start", result: result)
        return
      }
      observeInterruptions()
      startTicker()
      emitCurrent(status: "playing")
      result(nil)
    } catch {
      failPlayback("\(error)", result: result)
    }
  }

  /// Tears down after a failed play/resume and emits a terminal "stopped", so the
  /// stream never stays wedged on a playback that silently died (the caller also
  /// gets the error through the method result). The position is captured before
  /// teardown so a failed resume does not snap the UI's scrubber to zero.
  private func failPlayback(_ message: String, result: @escaping FlutterResult) {
    let positionMs = Int((player?.currentTime ?? 0) * 1000)
    let durationMs = Int((player?.duration ?? 0) * 1000)
    teardown(deactivate: true)
    emit(status: "stopped", positionMs: positionMs, durationMs: durationMs)
    result(FlutterError(code: "playback_failed", message: message, details: nil))
  }

  private func pause() {
    guard let player = player else { return }
    player.pause()
    stopTicker()
    // Deliberate: pause keeps the non-mixable session active (it does not
    // deactivate), so resume is instant. Only stop/completion release the session.
    emitCurrent(status: "paused")
  }

  private func resume(result: @escaping FlutterResult) {
    // Same boundary as play(): a paused playback must not steal the session back
    // from a recording that started in the meantime.
    if CaptureHub.session.isCapturing {
      result(
        FlutterError(
          code: "busy_recording", message: "cannot resume while recording", details: nil))
      return
    }
    guard let player = player else {
      // Nothing to resume (completed, stopped, yielded, or media reset). A distinct
      // code lets the caller fall back to play(path) instead of waiting for a
      // "playing" event that will never come.
      result(FlutterError(code: "no_playback", message: "nothing to resume", details: nil))
      return
    }
    if player.isPlaying {
      // Already playing: self-heal a dead ticker rather than wedging a silent one.
      startTicker()
      result(nil)
      return
    }
    // Re-assert category and activation: an interruption or another plugin may have
    // changed the shared session while playback was paused.
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .spokenAudio)
    try? session.setActive(true)
    guard player.play() else {
      failPlayback("player refused to resume", result: result)
      return
    }
    startTicker()
    emitCurrent(status: "playing")
    result(nil)
  }

  private func seek(toMs ms: Int) {
    guard let player = player else { return }
    player.currentTime = max(0, min(Double(ms) / 1000, player.duration))
    emitCurrent(status: player.isPlaying ? "playing" : "paused")
  }

  /// Playback speed. Held on the plugin as well as the player: every play builds
  /// a NEW AVAudioPlayer, which would otherwise come back at 1x and silently
  /// drop a speed the user is still looking at.
  private func setRate(_ value: Double) {
    rate = Float(max(0.5, min(value, 3)))
    player?.rate = rate
  }

  private func stop() {
    guard let player = player else { return }
    // Capture the final position before releasing, so the stopped event is accurate.
    let positionMs = Int(player.currentTime * 1000)
    let durationMs = Int(player.duration * 1000)
    teardown(deactivate: true)
    emit(status: "stopped", positionMs: positionMs, durationMs: durationMs)
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    // Apple does not document the delegate's thread; hop to main defensively, like
    // the interruption handler. The identity guard (re-checked after the hop) makes
    // the stale-callback invariant local rather than dependent on teardown ordering.
    DispatchQueue.main.async { [weak self] in
      guard let self = self, player === self.player else { return }
      let durationMs = Int(player.duration * 1000)
      self.teardown(deactivate: true)
      self.emit(status: "completed", positionMs: durationMs, durationMs: durationMs)
    }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    // Reachable in normal use: the capture side deliberately keeps truncated m4a
    // files after a write error, and those decode-error mid-play. Without this the
    // ticker would mute and the UI would wedge at "playing" forever.
    DispatchQueue.main.async { [weak self] in
      guard let self = self, player === self.player else { return }
      let positionMs = Int(player.currentTime * 1000)
      let durationMs = Int(player.duration * 1000)
      self.teardown(deactivate: true)
      self.emit(status: "stopped", positionMs: positionMs, durationMs: durationMs)
    }
  }

  /// mediaserverd crashed; the AVAudioPlayer is invalid (Apple: dispose and
  /// recreate). End the playback with a terminal event; its position is
  /// unreadable from the dead object, so report zeros.
  @objc private func handleMediaServicesReset(_ note: Notification) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.player != nil else { return }
      self.teardown(deactivate: false)
      self.emit(status: "stopped", positionMs: 0, durationMs: 0)
    }
  }

  /// A system interruption (a phone call) pauses the AVAudioPlayer without any
  /// delegate callback; without this observer the ticker would keep reporting a
  /// frozen "playing" forever and pause would be a dead button.
  private func observeInterruptions() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleInterruption(_:)),
      name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
  }

  @objc private func handleInterruption(_ note: Notification) {
    guard let info = note.userInfo,
      let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw), type == .began
    else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.player != nil else { return }
      self.stopTicker()
      self.emitCurrent(status: "paused")
    }
  }

  private func startTicker() {
    stopTicker()
    let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
      // Tick only while actually playing: state transitions (paused, completed) are
      // owned by pause/interruption/delegate, so a tick between natural end and the
      // delegate callback cannot flicker a spurious "paused" before "completed".
      guard let self = self, let player = self.player, player.isPlaying else { return }
      self.emitCurrent(status: "playing")
    }
    timer.tolerance = 0.05
    // .common mode so ticks keep firing during UI gesture tracking (dragging a
    // scrubber, scrolling), when the run loop leaves its default mode.
    RunLoop.main.add(timer, forMode: .common)
    ticker = timer
  }

  private func stopTicker() {
    ticker?.invalidate()
    ticker = nil
  }

  /// Releases the player and stops ticking. Clears lastPayload so a stale "playing"
  /// is never replayed to a late listener after playback ends or is replaced; a
  /// caller emitting a terminal state does so after this. Only deactivates the
  /// shared session when no capture is using it.
  private func teardown(deactivate: Bool) {
    stopTicker()
    player?.stop()
    player?.delegate = nil
    player = nil
    lastPayload = nil
    NotificationCenter.default.removeObserver(
      self, name: AVAudioSession.interruptionNotification, object: nil)
    if deactivate, !CaptureHub.session.isCapturing {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  /// Emits the current player's state at [status]. No-op if there is no player
  /// (terminal states after teardown go through [emit] with explicit values).
  private func emitCurrent(status: String) {
    guard let player = player else { return }
    emit(
      status: status,
      positionMs: Int(player.currentTime * 1000),
      durationMs: Int(player.duration * 1000))
  }

  /// The one payload builder and emitter. Caches only NON-terminal states for
  /// late-listener replay: a live listener receives stopped/completed directly, and
  /// a fresh subscriber (a new screen) must not inherit a previous playback's
  /// ending. The async hop (though already on main) avoids re-entrancy if an emit
  /// fires inside a sink callback, matching the recorder.
  private func emit(status: String, positionMs: Int, durationMs: Int) {
    let payload: [String: Any] = [
      "status": status,
      "positionMs": positionMs,
      "durationMs": durationMs,
    ]
    let terminal = status == "stopped" || status == "completed"
    lastPayload = terminal ? nil : payload
    DispatchQueue.main.async { self.stateSink?(payload) }
  }
}

/// The amplitude envelope of the file at [path]: [buckets] values in 0...1, one per
/// equal slice of the recording, each the loudest sample in its slice.
///
/// PEAK, not average: an average washes speech into a flat band, while the peak keeps
/// the shape of a voice - the attack of a word against the near-silence between them.
/// Normalized by the file's OWN loudest sample, so a take recorded at arm's length
/// still fills the band; the wave says where the sound is, not how close the mic was.
///
/// Reads in chunks: a whole recording decoded into one buffer is unbounded memory for
/// an unbounded take.
func readPeaks(path: String, buckets: Int) throws -> [Double] {
  let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
  let frames = file.length
  guard frames > 0, buckets > 0 else { return [] }

  let format = file.processingFormat
  let channels = Int(format.channelCount)
  // Capped in absolute terms, not just relative to the file: sized off the take
  // alone, an hour of 48kHz mono would ask for a single ~70MB float buffer.
  let chunkCeiling: Int64 = 1 << 18  // ~1MB of float32 mono
  let perBucket = max(1, Int(Double(frames) / Double(buckets)))
  let chunkFrames = AVAudioFrameCount(min(Int64(perBucket) * 32, chunkCeiling, frames))
  guard channels > 0, chunkFrames > 0,
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames)
  else { return [] }

  var peaks = [Double](repeating: 0, count: buckets)
  var loudest = 0.0
  var frame: Int64 = 0
  while frame < frames {
    try file.read(into: buffer, frameCount: chunkFrames)
    let read = Int(buffer.frameLength)
    if read == 0 { break }
    guard let samples = buffer.floatChannelData else { break }
    for i in 0..<read {
      var level = 0.0
      for channel in 0..<channels {
        level = max(level, Double(abs(samples[channel][i])))
      }
      // Proportional, not divided by a rounded slice size: rounding the slice up
      // leaves the last buckets unwritten, which draws a short take with a flat
      // right edge no matter what is in it.
      let bucket = min(buckets - 1, Int((frame + Int64(i)) * Int64(buckets) / frames))
      if level > peaks[bucket] { peaks[bucket] = level }
      if level > loudest { loudest = level }
    }
    frame += Int64(read)
  }

  guard loudest > 0 else { return peaks }
  return peaks.map { $0 / loudest }
}
