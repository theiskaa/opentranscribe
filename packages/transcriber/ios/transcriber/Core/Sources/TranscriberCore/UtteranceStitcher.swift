import Foundation

/// Rebuilds a cumulative transcript from a classic recognizer's hypotheses. The
/// on-device recognizer holds only the current utterance: a pause of about two
/// seconds (in weak locales, nearly every word) RESETS its hypothesis, so the
/// latest one alone loses everything before it. Each finished utterance is
/// committed here, so [whole] is the whole take.
///
/// A reset cannot be read from timings alone: the recognizer's live hypotheses
/// carry words whose start and end are both zero, and real timings arrive only
/// in a refinement at each utterance's end and in the final result. Three
/// signals answer it instead, any one of them enough, because missing a reset
/// loses words while calling one wrongly only repeats a phrase:
///
/// - A timed hypothesis ends its utterance, so the next untimed one opens a new
///   one.
/// - The text ([revises]), the only signal most hypotheses carry.
/// - The timings, when both sides have them, which catch a new utterance that
///   reads like a revision (the same sentence said twice).
///
/// [supersedes] covers the other direction: a recognizer that re-delivers the
/// whole take in one hypothesis.
///
/// Safe to feed from the recognizer's queue while another thread reads [whole]
/// or [progressSeconds].
public final class UtteranceStitcher {
  private let lock = NSLock()
  private var committedText: [String] = []
  private var committedWords: [TimedWord] = []
  /// Set when an utterance is committed without timings. Its words can never be
  /// filled in later, and [whole] answers all of the take's words or none.
  private var committedUntimed = false
  /// Set when an utterance starts before the last one ended, which means the
  /// recognizer timed them on separate clocks and no word can be placed in the
  /// take as a whole.
  private var timelineBroken = false
  private var currentText = ""
  private var currentWords: [TimedWord] = []
  /// Nil while the current utterance has only ever been described by untimed
  /// hypotheses, which is most of a take.
  private var currentStartMs: Int?
  private var currentEndMs: Int?
  private var heardEndMs = 0

  /// Timing slack between a rewrite and a reset: rewrites start inside the
  /// current utterance, resets at or a hair before its end.
  private static let resetSlackMs = 150

  public init() {}

  public func feed(_ heard: SpeechHypothesis) {
    // A hypothesis with nothing to read is the recognizer clearing at a
    // boundary: absorbing it would erase the utterance it just delivered, and
    // its timings still say how far it has heard.
    let readable = !Self.comparable(heard.text).isEmpty
    lock.lock()
    defer { lock.unlock() }
    if let end = heard.endMs { heardEndMs = max(heardEndMs, end) }
    guard readable else { return }

    if currentText.isEmpty {
      begin(heard)
      return
    }
    if !committedText.isEmpty, Self.supersedes(stitched, heard.text) {
      committedText = []
      committedWords = []
      committedUntimed = false
      timelineBroken = false
      begin(heard)
      return
    }
    if resets(heard) {
      committedText.append(currentText)
      committedWords.append(contentsOf: currentWords)
      committedUntimed = committedUntimed || currentWords.isEmpty
      if let start = heard.startMs, let last = committedWords.last?.endMs, start < last {
        timelineBroken = true
      }
      begin(heard)
      return
    }
    currentText = heard.text
    guard heard.isTimed else { return }
    currentWords = heard.words
    currentStartMs = heard.startMs
    currentEndMs = heard.endMs
  }

  /// The take as stitched so far, and the words of it placed in the audio.
  /// Either every utterance is placed or none is: a half-timed answer would
  /// read as a whole transcript to a caller that renders words over text, and
  /// the untimed half would vanish.
  public var whole: (text: String, words: [TimedWord]) {
    lock.lock()
    defer { lock.unlock() }
    let placed = !committedUntimed && !timelineBroken && !currentWords.isEmpty
    return (stitched, placed ? committedWords + currentWords : [])
  }

  /// How far into the audio recognition has reached, for a file feeder's
  /// pacing. Only a timed hypothesis moves it, and it never walks backwards
  /// when an utterance restarts.
  public var progressSeconds: TimeInterval {
    lock.lock()
    defer { lock.unlock() }
    return Double(heardEndMs) / 1000
  }

  private func begin(_ heard: SpeechHypothesis) {
    currentText = heard.text
    currentWords = heard.isTimed ? heard.words : []
    currentStartMs = heard.startMs
    currentEndMs = heard.endMs
  }

  /// Whether [heard] opens a new utterance rather than revising the current
  /// one. See the class doc for why any one signal is enough.
  private func resets(_ heard: SpeechHypothesis) -> Bool {
    if currentEndMs != nil, !heard.isTimed { return true }
    if !Self.revises(currentText, heard.text) { return true }
    guard let start = heard.startMs, let currentStartMs = currentStartMs,
      let currentEndMs = currentEndMs
    else { return false }
    return start > currentStartMs && start >= currentEndMs - Self.resetSlackMs
  }

  private var stitched: String {
    var parts = committedText
    if !currentText.isEmpty { parts.append(currentText) }
    return parts.joined(separator: " ")
  }

  /// The comparable scalars of [text]: lowercased, stripped of punctuation and
  /// whitespace, so the rules below read a transcript the same way in a script
  /// that spaces its words and one that does not.
  private static func comparable(_ text: String) -> [Unicode.Scalar] {
    text.lowercased().unicodeScalars.filter {
      !CharacterSet.punctuationCharacters.contains($0)
        && !CharacterSet.whitespacesAndNewlines.contains($0)
    }
  }

  private static func sharedPrefix(_ a: [Unicode.Scalar], _ b: [Unicode.Scalar]) -> Int {
    var n = 0
    while n < a.count, n < b.count, a[n] == b[n] { n += 1 }
    return n
  }

  /// Whether [new] revises [current] rather than opening a new utterance.
  /// Hypotheses for one utterance grow and revise left to right, so one
  /// carrying the whole current text revises it and one sharing no leading
  /// character opens a new utterance. Between those, a revision still
  /// reproduces most of what it revises, while a new utterance that happens to
  /// start with the same letters keeps little of it.
  private static func revises(_ current: String, _ new: String) -> Bool {
    let c = comparable(current), n = comparable(new)
    if c.isEmpty || n.isEmpty { return true }
    let shared = sharedPrefix(c, n)
    if shared == 0 { return false }
    if shared == c.count { return true }
    return shared * 2 > c.count
  }

  /// Whether [new] re-delivers everything stitched so far, which makes it the
  /// whole take rather than the next utterance. It has to carry the whole
  /// accumulation: a new utterance reopening with an earlier one's words would
  /// otherwise wipe what a short take had stitched.
  private static func supersedes(_ accumulated: String, _ new: String) -> Bool {
    let a = comparable(accumulated), n = comparable(new)
    if a.isEmpty || n.count < a.count { return false }
    return sharedPrefix(a, n) == a.count
  }
}
