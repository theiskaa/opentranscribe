import AVFoundation
import Foundation

/// Joins kept recordings into one new file. Constraints the rest relies on:
/// - Inputs are opened for reading only; they are never modified or deleted.
/// - One code path: every input decodes to PCM and is written once at the first
///   input's sample rate and channel count, so mixed routes merge seamlessly.
/// - Offsets are the writer's own frame count at each input start, the same
///   count `probeAudio` reads back from the output.
/// - The output lives under `compose/` until complete and enters the recordings
///   directory by a rename, so nothing partial is ever where a sweep looks.
/// - Reads and writes touch no audio session; a merge never disturbs capture.
/// - Merges are serialized on [queue], which is also the only thread that clears
///   the staging directory.
enum AudioCompose {
  static let queue = DispatchQueue(label: "transcriber.compose", qos: .userInitiated)

  struct Outcome {
    let name: String
    let durationMs: Int
    /// Where each input starts in the output, from the writer's own frame count.
    let startsMs: [Int]
  }

  enum ComposeError: LocalizedError {
    case badInput
    case missing(String)
    case unreadable(String)
    case writeFailed(String)

    var code: String {
      switch self {
      case .badInput: return "bad_args"
      case .missing: return "compose_missing"
      case .unreadable: return "compose_unreadable"
      case .writeFailed: return "compose_failed"
      }
    }

    var errorDescription: String? {
      switch self {
      case .badInput: return "two or more bare names required"
      case .missing(let name): return "input not found: \(name)"
      case .unreadable(let name): return "input unreadable: \(name)"
      case .writeFailed(let reason): return reason
      }
    }
  }

  private static let chunkFrames: AVAudioFrameCount = 32_768

  /// Application Support/compose, protected and backup-excluded like the
  /// recordings directory. Emptied on every call: anything in it is a merge a
  /// kill cut short.
  static func stagingDirectory() throws -> URL {
    let dir = try AudioCaptureSession.protectedDirectory(named: "compose")
    let fm = FileManager.default
    if let stale = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
      for url in stale { try? fm.removeItem(at: url) }
    }
    return dir
  }

  static func concatenate(names: [String]) throws -> Outcome {
    guard names.count >= 2, names.allSatisfy({ !$0.isEmpty && !$0.contains("/") }) else {
      throw ComposeError.badInput
    }
    let recordings = try AudioCaptureSession.recordingsDirectory()
    let fm = FileManager.default
    let inputs = names.map { recordings.appendingPathComponent($0) }
    for (name, url) in zip(names, inputs) where !fm.fileExists(atPath: url.path) {
      throw ComposeError.missing(name)
    }

    let files = try zip(names, inputs).map { name, url -> AVAudioFile in
      do { return try AVAudioFile(forReading: url) } catch { throw ComposeError.unreadable(name) }
    }
    let target = files[0].processingFormat
    guard target.sampleRate > 0, target.channelCount > 0 else {
      throw ComposeError.unreadable(names[0])
    }
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: target.sampleRate,
      AVNumberOfChannelsKey: target.channelCount,
      AVEncoderBitRateKey: AudioCaptureSession.aacBitRate(
        sampleRate: target.sampleRate, channels: Int(target.channelCount)),
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    let name = "otr-\(UUID().uuidString).m4a"
    let staged = try stagingDirectory().appendingPathComponent(name)
    var startsMs: [Int] = []
    var written: AVAudioFramePosition = 0
    do {
      // Scoped so the writer closes (and flushes its header) before the move.
      try autoreleasepool {
        let out = try AVAudioFile(forWriting: staged, settings: settings)
        for (name, file) in zip(names, files) {
          startsMs.append(Int(Double(written) / target.sampleRate * 1000))
          written += try append(file, named: name, to: out)
        }
        if #available(iOS 18, *) { out.close() }
      }
    } catch {
      try? fm.removeItem(at: staged)
      throw error
    }

    let final = recordings.appendingPathComponent(name)
    do {
      try fm.moveItem(at: staged, to: final)
    } catch {
      try? fm.removeItem(at: staged)
      throw ComposeError.writeFailed("move failed: \(error)")
    }
    return Outcome(
      name: name,
      durationMs: Int(Double(written) / target.sampleRate * 1000),
      startsMs: startsMs)
  }

  /// Streams one input into the writer, converting when its PCM shape differs
  /// from the writer's. Returns the frames written.
  private static func append(_ input: AVAudioFile, named name: String, to out: AVAudioFile)
    throws -> AVAudioFramePosition
  {
    func read(into buffer: AVAudioPCMBuffer) throws {
      do {
        try input.read(into: buffer)
      } catch {
        throw ComposeError.unreadable("\(name): \(error)")
      }
    }
    func write(_ buffer: AVAudioPCMBuffer) throws {
      do {
        try out.write(from: buffer)
      } catch {
        throw ComposeError.writeFailed("write failed: \(error)")
      }
    }
    let inFormat = input.processingFormat
    let outFormat = out.processingFormat
    var frames: AVAudioFramePosition = 0
    if inFormat.sampleRate == outFormat.sampleRate
      && inFormat.channelCount == outFormat.channelCount
      && inFormat.commonFormat == outFormat.commonFormat
      && inFormat.isInterleaved == outFormat.isInterleaved
    {
      while true {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: chunkFrames)
        else { throw ComposeError.writeFailed("buffer allocation failed") }
        try read(into: buffer)
        if buffer.frameLength == 0 { break }
        try write(buffer)
        frames += AVAudioFramePosition(buffer.frameLength)
      }
      return frames
    }

    guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
      throw ComposeError.writeFailed("no converter from \(inFormat) to \(outFormat)")
    }
    var drained = false
    var readError: Error?
    while true {
      guard let buffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: chunkFrames)
      else { throw ComposeError.writeFailed("buffer allocation failed") }
      var error: NSError?
      let status = converter.convert(to: buffer, error: &error) { requested, outStatus in
        if drained {
          outStatus.pointee = .endOfStream
          return nil
        }
        let capacity = min(max(requested, 1), chunkFrames)
        guard let chunk = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: capacity) else {
          drained = true
          outStatus.pointee = .endOfStream
          return nil
        }
        do {
          try read(into: chunk)
        } catch {
          readError = error
          drained = true
          outStatus.pointee = .endOfStream
          return nil
        }
        if chunk.frameLength == 0 {
          drained = true
          outStatus.pointee = .endOfStream
          return nil
        }
        outStatus.pointee = .haveData
        return chunk
      }
      if let readError { throw readError }
      if status == .error {
        throw ComposeError.writeFailed("convert failed: \(error?.localizedDescription ?? "?")")
      }
      if buffer.frameLength > 0 {
        try write(buffer)
        frames += AVAudioFramePosition(buffer.frameLength)
      }
      if status == .endOfStream { break }
    }
    return frames
  }
}
