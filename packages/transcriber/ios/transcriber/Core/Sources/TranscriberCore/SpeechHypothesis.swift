import Foundation

/// One word of a transcript, with the audio it was heard in. A recognizer that
/// hands out a hypothesis without timings gives none of these.
public struct TimedWord: Sendable {
  public let text: String
  public let startMs: Int
  public let endMs: Int
  public let confidence: Double?

  public init(text: String, startMs: Int, endMs: Int, confidence: Double? = nil) {
    self.text = text
    self.startMs = startMs
    self.endMs = endMs
    self.confidence = confidence
  }
}

/// What a recognizer answered at one moment: the text it reads as, and the
/// words it could place in the audio. Both halves are needed to tell a rewrite
/// of the current utterance from the start of a new one.
public struct SpeechHypothesis: Sendable {
  public let text: String
  public let words: [TimedWord]

  public init(text: String, words: [TimedWord] = []) {
    self.text = text
    self.words = words
  }

  /// Whether the recognizer placed these words at all: its live hypotheses
  /// carry words whose start and end are both zero, which is not a time.
  var isTimed: Bool { words.contains { $0.startMs > 0 || $0.endMs > 0 } }

  var startMs: Int? { isTimed ? words.first?.startMs : nil }
  var endMs: Int? { isTimed ? words.last?.endMs : nil }
}
