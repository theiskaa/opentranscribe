import AVFoundation
import Foundation
import TranscriberCore

/// Decodes a slice of a kept recording into what an on-device model reads:
/// 16 kHz mono Float32 samples, raw with no header, under Application
/// Support/scratch. Constraints the rest relies on:
/// - The input is opened for reading only.
/// - A slice that would hold no frames fails typed rather than answering silence.
/// - The output exists only once complete; a failed decode removes it.
/// - The caller deletes the output; nothing here sweeps the scratch directory.
/// - Decodes are serialized on [queue].
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

  static func decodePcm(path: String, startMs: Int?, endMs: Int?) throws -> Outcome {
    guard !path.isEmpty else { throw DecodeError.badInput }
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else { throw DecodeError.missing }
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
    guard
      let slice = pcmSlice(
        startMs: startMs, endMs: endMs, sampleRate: inFormat.sampleRate, length: input.length)
    else { throw DecodeError.empty }
    guard
      let outFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
    else { throw DecodeError.writeFailed("no output format") }

    let out = try scratchDirectory().appendingPathComponent("otr-\(UUID().uuidString).pcm")
    guard fm.createFile(atPath: out.path, contents: nil) else {
      throw DecodeError.writeFailed("create failed")
    }
    do {
      let handle = try FileHandle(forWritingTo: out)
      defer { try? handle.close() }
      let frames = try write(input, slice: slice, as: outFormat, to: handle)
      return Outcome(path: out.path, frames: frames)
    } catch {
      try? fm.removeItem(at: out)
      throw error
    }
  }

  private static func write(
    _ input: AVAudioFile, slice: PcmSlice, as outFormat: AVAudioFormat, to handle: FileHandle
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
      let bytes = Int(buffer.frameLength) * MemoryLayout<Float>.size
      do {
        try handle.write(contentsOf: Data(bytes: channel, count: bytes))
      } catch {
        throw DecodeError.writeFailed("write failed: \(error)")
      }
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
