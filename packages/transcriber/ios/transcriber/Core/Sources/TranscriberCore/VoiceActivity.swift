import Foundation

/// A stretch of a slice that holds a voice, in milliseconds from the slice's
/// start: start inclusive, end exclusive.
public struct VoicedRun: Equatable {
  public let startMs: Int
  public let endMs: Int

  public init(startMs: Int, endMs: Int) {
    self.startMs = startMs
    self.endMs = endMs
  }
}

/// Mono samples folded into the level of each [frameMs] frame, in dBFS; the
/// last frame may be short.
public struct FrameLevels {
  public let frameMs: Int
  private let frameSize: Int
  private var sum: Double = 0
  private var count = 0
  private var levels: [Float] = []

  public init(sampleRate: Double, frameMs: Int = 20) {
    self.frameMs = frameMs
    frameSize = max(1, Int((sampleRate * Double(frameMs) / 1000).rounded()))
  }

  public mutating func add(_ samples: UnsafeBufferPointer<Float>) {
    for sample in samples {
      sum += Double(sample) * Double(sample)
      count += 1
      if count == frameSize { flush() }
    }
  }

  /// The levels, the short last frame included.
  public mutating func finish() -> [Float] {
    if count > 0 { flush() }
    return levels
  }

  private mutating func flush() {
    let rms = (sum / Double(count)).squareRoot()
    levels.append(rms > 0 ? Float(20 * log10(rms)) : -120)
    sum = 0
    count = 0
  }
}

/// Where [levels] (one per [frameMs] frame, dBFS) hold a voice, or nil when
/// they cannot say. The floor is the slice's 10th percentile over frames that
/// hold any sound (digital silence would drag it down); a frame is voiced at
/// or above the floor plus [lift] (twice [steady] in a steady room) and never
/// below [quietest]; quiet under [bridgeMs] between voiced frames is the gap
/// between words, and a voiced run under [shortestMs] is a click. A slice that
/// moves less than [steady] from its floor to its 90th percentile is a steady
/// room, where a voice counts however little of the slice it fills; one that
/// moves more but less than [lift] is as likely noise as a voice under it:
/// nil, so a caller never drops words it could not see.
public func voicedRuns(
  levels: [Float],
  frameMs: Int,
  lift: Float = 9,
  steady: Float = 2.5,
  quietest: Float = -75,
  bridgeMs: Int = 250,
  shortestMs: Int = 100
) -> [VoicedRun]? {
  guard frameMs > 0 else { return nil }
  let sounding = levels.filter { $0 > -100 }.sorted()
  guard !sounding.isEmpty else { return [] }
  let floor = sounding[(sounding.count - 1) / 10]
  let spread = sounding[(sounding.count - 1) * 9 / 10] - floor
  let steadyRoom = spread < steady
  if !steadyRoom && spread < lift { return nil }
  let threshold = max(floor + (steadyRoom ? 2 * steady : lift), quietest)
  var runs: [VoicedRun] = []
  var start: Int?
  var lastVoiced = 0
  for (i, level) in levels.enumerated() where level >= threshold {
    if let open = start, (i - lastVoiced - 1) * frameMs >= bridgeMs {
      runs.append(VoicedRun(startMs: open * frameMs, endMs: (lastVoiced + 1) * frameMs))
      start = i
    } else if start == nil {
      start = i
    }
    lastVoiced = i
  }
  if let open = start {
    runs.append(VoicedRun(startMs: open * frameMs, endMs: (lastVoiced + 1) * frameMs))
  }
  return runs.filter { $0.endMs - $0.startMs >= shortestMs }
}
