import AVFoundation
import Foundation
import TranscriberCore

/// Decodes a slice of a kept recording into what an on-device model reads:
/// 16 kHz mono Float32 samples, raw with no header, under Application
/// Support/scratch, or reads where the slice holds a voice without writing
/// anything. Constraints the rest relies on:
/// - The input is opened for reading only.
/// - A decode of a slice that would hold no frames fails typed rather than
///   answering silence; the voice of such a slice is none.
/// - A decode's output exists only once complete; a failed decode removes it.
/// - The caller deletes the output; nothing here sweeps the scratch directory.
/// - Decodes and voice reads are serialized on [queue].
enum AudioDecode {
  static let queue = DispatchQueue(label: "transcriber.decode", qos: .userInitiated)
  static let sampleRate: Double = 16_000

  struct Outcome {
    let path: String
    let frames: Int
  }

  enum DecodeError: LocalizedError {
    case badInput
    case missing
    case unreadable(String)
    case empty
    case writeFailed(String)

    var code: String {
      switch self {
      case .badInput: return "bad_args"
      case .missing: return "decode_missing"
      case .unreadable: return "decode_unreadable"
      case .empty: return "decode_empty"
      case .writeFailed: return "decode_failed"
      }
    }

    var errorDescription: String? {
      switch self {
      case .badInput: return "path required"
      case .missing: return "input not found"
      case .unreadable(let reason): return "input unreadable: \(reason)"
      case .empty: return "slice holds no frames"
      case .writeFailed(let reason): return reason
      }
    }
  }

  private static let chunkFrames: AVAudioFrameCount = 32_768

  static func scratchDirectory() throws -> URL {
    try AudioCaptureSession.protectedDirectory(named: "scratch")
  }

  /// The input's own duration in milliseconds, from its header; nothing is decoded.
  static func lengthMs(path: String) throws -> Int {
    let input = try open(path: path)
    return Int((Double(input.length) / input.processingFormat.sampleRate * 1000).rounded())
  }

  private static func open(path: String) throws -> AVAudioFile {
    guard !path.isEmpty else { throw DecodeError.badInput }
    guard FileManager.default.fileExists(atPath: path) else { throw DecodeError.missing }
    let input: AVAudioFile
    do {
      input = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    } catch {
      throw DecodeError.unreadable("\(error)")
    }
    let inFormat = input.processingFormat
    guard inFormat.sampleRate > 0, inFormat.channelCount > 0 else {
      throw DecodeError.unreadable("no format")
    }
    return input
  }

  /// What a model reads: 16 kHz mono Float32.
  private static let outFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)

  /// The input opened and its slice resolved, or nil for a slice holding no
  /// frames.
  private static func sliced(path: String, startMs: Int?, endMs: Int?) throws -> (
    input: AVAudioFile, slice: PcmSlice, outFormat: AVAudioFormat
  )? {
    let input = try open(path: path)
    guard
      let slice = pcmSlice(
        startMs: startMs, endMs: endMs, sampleRate: input.processingFormat.sampleRate,
        length: input.length)
    else { return nil }
    guard let outFormat else { throw DecodeError.writeFailed("no output format") }
    return (input, slice, outFormat)
  }

  static func decodePcm(path: String, startMs: Int?, endMs: Int?) throws -> Outcome {
    let fm = FileManager.default
    guard let (input, slice, outFormat) = try sliced(path: path, startMs: startMs, endMs: endMs)
    else { throw DecodeError.empty }

    let out = try scratchDirectory().appendingPathComponent("otr-\(UUID().uuidString).pcm")
    guard fm.createFile(atPath: out.path, contents: nil) else {
      throw DecodeError.writeFailed("create failed")
    }
    do {
      let handle = try FileHandle(forWritingTo: out)
      defer { try? handle.close() }
      let frames = try decode(input, slice: slice, as: outFormat) { samples in
        do {
          try handle.write(contentsOf: Data(buffer: samples))
        } catch {
          throw DecodeError.writeFailed("write failed: \(error)")
        }
      }
      return Outcome(path: out.path, frames: frames)
    } catch {
      try? fm.removeItem(at: out)
      throw error
    }
  }

  /// Where the slice holds a voice ([voicedRuns] over its 16 kHz samples), in
  /// milliseconds of the input and inside the slice, or nil when the levels
  /// cannot say. A slice holding no frames holds no voice.
  static func voicedRanges(path: String, startMs: Int?, endMs: Int?) throws -> [[Int]]? {
    guard let (input, slice, outFormat) = try sliced(path: path, startMs: startMs, endMs: endMs)
    else { return [] }
    var levels = FrameLevels(sampleRate: sampleRate)
    _ = try decode(input, slice: slice, as: outFormat) { levels.add($0) }
    let rate = input.processingFormat.sampleRate
    let offset = Int((Double(slice.start) / rate * 1000).rounded())
    let end = Int((Double(slice.end) / rate * 1000).rounded())
    return voicedRuns(levels: levels.finish(), frameMs: levels.frameMs)?.map {
      [offset + $0.startMs, min(offset + $0.endMs, end)]
    }
  }

  /// The slice converted to [outFormat], handed to [sink] a buffer at a time.
  private static func decode(
    _ input: AVAudioFile, slice: PcmSlice, as outFormat: AVAudioFormat,
    to sink: (UnsafeBufferPointer<Float>) throws -> Void
  ) throws -> Int {
    let inFormat = input.processingFormat
    input.framePosition = slice.start
    var remaining = slice.frames
    var written = 0

    func read(into buffer: AVAudioPCMBuffer, frames: AVAudioFrameCount) throws {
      do {
        try input.read(into: buffer, frameCount: frames)
      } catch {
        throw DecodeError.unreadable("\(error)")
      }
      remaining -= min(Int64(buffer.frameLength), remaining)
    }
    func nextChunk(_ requested: AVAudioFrameCount) -> AVAudioFrameCount {
      AVAudioFrameCount(min(Int64(min(max(requested, 1), chunkFrames)), remaining))
    }
    func emit(_ buffer: AVAudioPCMBuffer) throws {
      guard buffer.frameLength > 0, let channel = buffer.floatChannelData?[0] else { return }
      try sink(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
      written += Int(buffer.frameLength)
    }

    if inFormat.sampleRate == outFormat.sampleRate
      && inFormat.channelCount == outFormat.channelCount
      && inFormat.commonFormat == outFormat.commonFormat
      && inFormat.isInterleaved == outFormat.isInterleaved
    {
      while remaining > 0 {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: chunkFrames)
        else { throw DecodeError.writeFailed("buffer allocation failed") }
        try read(into: buffer, frames: nextChunk(chunkFrames))
        if buffer.frameLength == 0 { break }
        try emit(buffer)
      }
      return written
    }

    guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
      throw DecodeError.writeFailed("no converter from \(inFormat) to \(outFormat)")
    }
    // Without this a stereo take keeps only its left channel.
    converter.downmix = true
    var drained = false
    var readError: Error?
    while true {
      guard let buffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: chunkFrames)
      else { throw DecodeError.writeFailed("buffer allocation failed") }
      var error: NSError?
      let status = converter.convert(to: buffer, error: &error) { requested, outStatus in
        if drained || remaining == 0 {
          drained = true
          outStatus.pointee = .endOfStream
          return nil
        }
        let capacity = nextChunk(requested)
        guard let chunk = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: capacity) else {
          drained = true
          outStatus.pointee = .endOfStream
          return nil
        }
        do {
          try read(into: chunk, frames: capacity)
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
        throw DecodeError.writeFailed("convert failed: \(error?.localizedDescription ?? "?")")
      }
      try emit(buffer)
      if status == .endOfStream { break }
    }
    return written
  }
}
