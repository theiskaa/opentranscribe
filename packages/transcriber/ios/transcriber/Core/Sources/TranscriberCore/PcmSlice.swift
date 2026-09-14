/// Frame bounds of a decode request inside a file: start inclusive, end
/// exclusive, both within the file.
public struct PcmSlice: Equatable {
  public let start: Int64
  public let end: Int64

  public init(start: Int64, end: Int64) {
    self.start = start
    self.end = end
  }

  public var frames: Int64 { end - start }
}

/// Resolves millisecond bounds (nil = the file's own edge) to frames at the
/// file's sample rate, clamped to the file. nil when the slice would hold no
/// frames: a start at or past the end, or past the file.
public func pcmSlice(startMs: Int?, endMs: Int?, sampleRate: Double, length: Int64) -> PcmSlice? {
  guard length > 0, sampleRate > 0 else { return nil }
  func frame(_ ms: Int) -> Int64 {
    Int64(min(max((Double(ms) / 1000 * sampleRate).rounded(), 0), Double(length)))
  }
  let start = startMs.map(frame) ?? 0
  let end = endMs.map(frame) ?? length
  guard start < end else { return nil }
  return PcmSlice(start: start, end: end)
}
