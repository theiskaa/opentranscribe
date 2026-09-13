import XCTest

@testable import TranscriberCore

final class VoiceActivityTests: XCTestCase {
  private func frames(_ level: Float, _ count: Int) -> [Float] {
    Array(repeating: level, count: count)
  }

  func testASilentSliceHasNoVoice() {
    XCTAssertEqual(voicedRuns(levels: frames(-70, 100), frameMs: 20), [])
    XCTAssertEqual(voicedRuns(levels: frames(-120, 100), frameMs: 20), [])
  }

  func testWordsWithShortGapsAreOneRun() {
    let words = frames(-70, 10) + frames(-25, 10) + frames(-70, 5) + frames(-25, 10) + frames(-70, 10)
    XCTAssertEqual(voicedRuns(levels: words, frameMs: 20), [VoicedRun(startMs: 200, endMs: 700)])
  }

  func testAPauseSplitsTheRuns() {
    let sentences = frames(-70, 10) + frames(-25, 10) + frames(-70, 20) + frames(-25, 10)
    XCTAssertEqual(
      voicedRuns(levels: sentences, frameMs: 20),
      [VoicedRun(startMs: 200, endMs: 400), VoicedRun(startMs: 800, endMs: 1000)])
  }

  func testAClickIsNotAVoice() {
    let click = frames(-70, 20) + frames(-20, 2) + frames(-70, 20)
    XCTAssertEqual(voicedRuns(levels: click, frameMs: 20), [])
  }

  func testTheFloorFollowsTheSliceNotAnAbsoluteLevel() {
    let noisyRoom = frames(-40, 20) + frames(-36, 20) + frames(-20, 10)
    XCTAssertEqual(voicedRuns(levels: noisyRoom, frameMs: 20), [VoicedRun(startMs: 800, endMs: 1000)])
  }

  func testAWhisperInASilentRoomIsAVoice() {
    let whisper = frames(-82, 20) + frames(-62, 20) + frames(-82, 10)
    XCTAssertEqual(voicedRuns(levels: whisper, frameMs: 20), [VoicedRun(startMs: 400, endMs: 800)])
  }

  func testDigitalSilenceDoesNotLowerTheFloor() {
    let gated = frames(-120, 40) + frames(-70, 20) + frames(-40, 10)
    XCTAssertEqual(voicedRuns(levels: gated, frameMs: 20), [VoicedRun(startMs: 1200, endMs: 1400)])
  }

  func testSteadyRoomToneIsNoVoiceHoweverLoud() {
    let hum = frames(-41, 20) + frames(-40, 20) + frames(-41, 20)
    XCTAssertEqual(voicedRuns(levels: hum, frameMs: 20), [])
  }

  func testALevelThatMovesButNeverRisesClearOfTheRoomCannotSay() {
    let crowd = frames(-38, 20) + frames(-35, 20) + frames(-37, 20)
    XCTAssertNil(voicedRuns(levels: crowd, frameMs: 20))
    let softSpeaker = frames(-58, 20) + frames(-53, 20) + frames(-57, 20)
    XCTAssertNil(voicedRuns(levels: softSpeaker, frameMs: 20))
  }

  func testAShortWordInALongSteadyRoomIsAVoice() {
    let word = frames(-60, 400) + frames(-30, 10) + frames(-60, 400)
    XCTAssertEqual(voicedRuns(levels: word, frameMs: 20), [VoicedRun(startMs: 8000, endMs: 8200)])
  }

  func testAQuietWordInALongSteadyRoomIsAVoice() {
    let word = frames(-60, 400) + frames(-54, 10) + frames(-60, 400)
    XCTAssertEqual(voicedRuns(levels: word, frameMs: 20), [VoicedRun(startMs: 8000, endMs: 8200)])
  }

  func testNothingUnderTheQuietestLevelIsAVoice() {
    let hiss = frames(-95, 40) + frames(-80, 10)
    XCTAssertEqual(voicedRuns(levels: hiss, frameMs: 20), [])
  }

  func testFrameLevelsFoldSamplesIntoDecibelsPerFrame() {
    var levels = FrameLevels(sampleRate: 1000, frameMs: 10)
    let first: [Float] = Array(repeating: 0.1, count: 6)
    let second: [Float] = Array(repeating: 0.1, count: 4) + Array(repeating: 0, count: 5)
    first.withUnsafeBufferPointer { levels.add($0) }
    second.withUnsafeBufferPointer { levels.add($0) }
    let folded = levels.finish()
    XCTAssertEqual(folded.count, 2)
    XCTAssertEqual(folded[0], -20, accuracy: 0.01)
    XCTAssertEqual(folded[1], -120)
  }
}
