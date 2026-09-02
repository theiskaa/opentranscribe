import XCTest

@testable import TranscriberCore

private func untimed(_ text: String) -> SpeechHypothesis {
  SpeechHypothesis(text: text, words: [])
}

private func timed(_ text: String, from startMs: Int) -> SpeechHypothesis {
  var words: [TimedWord] = []
  var at = startMs
  for word in text.split(separator: " ") {
    words.append(TimedWord(text: String(word), startMs: at, endMs: at + 300, confidence: 0.9))
    at += 300
  }
  return SpeechHypothesis(text: text, words: words)
}

private func stitch(_ heard: [SpeechHypothesis]) -> String {
  let stitcher = UtteranceStitcher()
  for hypothesis in heard { stitcher.feed(hypothesis) }
  return stitcher.whole.text
}

final class UtteranceStitcherTests: XCTestCase {
  func testAnUtteranceGrowingThroughUntimedHypothesesReadsAsItsLatestText() {
    XCTAssertEqual(
      stitch([untimed("First"), untimed("First I"), untimed("First I went")]), "First I went")
  }

  func testWordsSpokenBeforeAPauseSurviveTheUtteranceThatFollowsThem() {
    let heard = [
      untimed("First I went to the market"),
      timed("First I went to the market", from: 0),
      untimed("Then"),
      untimed("Then I walked home"),
      timed("Then I walked home", from: 12000),
    ]
    XCTAssertEqual(stitch(heard), "First I went to the market Then I walked home")
  }

  func testThreeUtterancesLandInTheOrderTheyWereSpoken() {
    let heard = [
      untimed("One"), timed("One", from: 0),
      untimed("Two"), timed("Two", from: 5000),
      untimed("Three"), timed("Three", from: 10000),
    ]
    XCTAssertEqual(stitch(heard), "One Two Three")
  }

  func testAnUtteranceOpeningWithThePreviousUtterancesFirstWordIsNotAbsorbedIntoIt() {
    let heard = [
      untimed("This is a test of the recorder"),
      untimed("This"),
      untimed("This is another test entirely"),
    ]
    XCTAssertEqual(stitch(heard), "This is a test of the recorder This is another test entirely")
  }

  func testAOneWordUtteranceSurvivesTheUtteranceThatFollowsIt() {
    XCTAssertEqual(stitch([untimed("Yes"), untimed("Hello there")]), "Yes Hello there")
  }

  func testTheSameWordSpokenTwiceReadsTwiceWhenTheTimingsSaySo() {
    XCTAssertEqual(stitch([timed("Yes", from: 0), timed("Yes", from: 3000)]), "Yes Yes")
  }

  func testAnUtteranceIsNotSplitByARewriteOfItsTail() {
    let heard = [
      untimed("waiting for 10 full"),
      untimed("waiting for 10 seconds"),
      untimed("waiting for 10"),
    ]
    XCTAssertEqual(stitch(heard), "waiting for 10")
  }

  func testTimedHypothesesThroughoutStitchOneUtterance() {
    let heard = [timed("one", from: 0), timed("one two", from: 0), timed("one two three", from: 0)]
    XCTAssertEqual(stitch(heard), "one two three")
  }

  func testAnUtteranceRestartingItsOwnClockStillOpensANewOne() {
    let heard = [timed("Hello there friend", from: 0), timed("Another thing entirely", from: 0)]
    XCTAssertEqual(stitch(heard), "Hello there friend Another thing entirely")
  }

  func testAHypothesisCarryingTheWholeTakeReplacesWhatWasStitched() {
    let heard = [
      untimed("First I went"), untimed("Then I walked"),
      timed("First I went Then I walked home", from: 0),
    ]
    XCTAssertEqual(stitch(heard), "First I went Then I walked home")
  }

  func testAnEmptyHypothesisLeavesTheCurrentUtteranceStanding() {
    XCTAssertEqual(stitch([untimed("Something"), untimed("")]), "Something")
  }

  func testAScriptThatDoesNotSpaceItsWordsStillSplitsAtAReset() {
    XCTAssertEqual(
      stitch([untimed("こんにちは"), untimed("こんにちは今日"), untimed("そして明日")]),
      "こんにちは今日 そして明日")
  }

  func testAnUntimedHypothesisContributesNoWords() {
    let stitcher = UtteranceStitcher()
    stitcher.feed(untimed("nothing placed here"))
    XCTAssertTrue(stitcher.whole.words.isEmpty)
    XCTAssertEqual(stitcher.whole.text, "nothing placed here")
  }

  func testAnUntimedHypothesisAfterATimedOneOpensANewUtterance() {
    let stitcher = UtteranceStitcher()
    stitcher.feed(timed("one two", from: 0))
    stitcher.feed(untimed("three"))
    XCTAssertEqual(stitcher.whole.text, "one two three")
  }

  func testACommittedUtteranceKeepsItsWords() {
    let stitcher = UtteranceStitcher()
    stitcher.feed(timed("one", from: 0))
    stitcher.feed(timed("two", from: 5000))
    XCTAssertEqual(stitcher.whole.words.map(\.startMs), [0, 5000])
  }

  func testAnUtteranceIsNotSwallowedByALongerOneSharingOnlyItsFirstLetter() {
    let heard = [
      untimed("Okay"), timed("Okay", from: 0),
      untimed("Obviously"), untimed("Obviously today was rough"),
      timed("Obviously today was rough", from: 3000),
    ]
    XCTAssertEqual(stitch(heard), "Okay Obviously today was rough")
  }

  func testAWordPerUtteranceLocaleKeepsEveryWordOnce() {
    var heard: [SpeechHypothesis] = []
    var at = 0
    for word in ["we", "were", "walking", "to", "the", "town", "today"] {
      heard.append(untimed(word))
      heard.append(timed(word, from: at))
      at += 400
    }
    XCTAssertEqual(stitch(heard), "we were walking to the town today")
  }

  func testAShortUtteranceIsNotWipedByALaterOneReopeningWithItsWords() {
    let heard = [
      untimed("Yes"), timed("Yes", from: 0),
      untimed("Yes hello"), untimed("Yes hello there my friend"),
      timed("Yes hello there my friend", from: 3000),
    ]
    XCTAssertEqual(stitch(heard), "Yes Yes hello there my friend")
  }

  func testAWordPerUtteranceTakeKeepsItsOpeningWords() {
    var heard: [SpeechHypothesis] = []
    var at = 0
    for word in ["So", "I", "sold", "the car"] {
      heard.append(untimed(word))
      heard.append(timed(word, from: at))
      at += 700
    }
    XCTAssertEqual(stitch(heard), "So I sold the car")
  }

  func testAnUtteranceSharingTheOpeningOfTheCurrentOneStillOpensANewOne() {
    let heard = [
      untimed("Okay so"), timed("Okay so", from: 0),
      untimed("Okay then"), untimed("Okay then we go"),
    ]
    XCTAssertEqual(stitch(heard), "Okay so Okay then we go")
  }

  func testWordsAreWithheldWhenTheUtterancesAreNotOnOneTimeline() {
    let stitcher = UtteranceStitcher()
    stitcher.feed(timed("Hello there friend", from: 0))
    stitcher.feed(timed("Another thing entirely", from: 0))
    XCTAssertEqual(stitcher.whole.text, "Hello there friend Another thing entirely")
    XCTAssertTrue(stitcher.whole.words.isEmpty)
  }

  func testAHypothesisRepeatingTheWholeTakeExactlyDoesNotRepeatIt() {
    let heard = [
      untimed("Alpha one"), timed("Alpha one", from: 0),
      untimed("Bravo two"),
      timed("Alpha one Bravo two", from: 0),
    ]
    XCTAssertEqual(stitch(heard), "Alpha one Bravo two")
  }

  func testAPunctuationOnlyHypothesisLeavesTheCurrentUtteranceStanding() {
    XCTAssertEqual(stitch([untimed("Hello there my friend"), untimed(".")]),
      "Hello there my friend")
  }

  func testATimedRewriteStartingInsideTheCurrentUtteranceDoesNotSplitIt() {
    XCTAssertEqual(
      stitch([timed("one two three", from: 0), timed("one two three four", from: 300)]),
      "one two three four")
  }

  func testWordsAreWithheldWhenAnEarlierUtteranceWasNeverPlaced() {
    let stitcher = UtteranceStitcher()
    stitcher.feed(untimed("First point"))
    stitcher.feed(untimed("And a second"))
    stitcher.feed(timed("And a second", from: 4000))
    XCTAssertTrue(stitcher.whole.words.isEmpty)
  }

  func testWordsAreAnsweredOnlyWhenEveryUtteranceCarriesThem() {
    let stitcher = UtteranceStitcher()
    stitcher.feed(untimed("First point"))
    stitcher.feed(timed("First point", from: 0))
    stitcher.feed(untimed("And a third one"))
    XCTAssertEqual(stitcher.whole.text, "First point And a third one")
    XCTAssertTrue(stitcher.whole.words.isEmpty)
  }

  func testProgressNeverWalksBackwardsAcrossAReset() {
    let stitcher = UtteranceStitcher()
    stitcher.feed(timed("one two", from: 4000))
    XCTAssertEqual(stitcher.progressSeconds, 4.6, accuracy: 0.001)
    stitcher.feed(timed("another", from: 0))
    XCTAssertEqual(stitcher.progressSeconds, 4.6, accuracy: 0.001)
  }

  func testSilenceMovesProgressNowhere() {
    let stitcher = UtteranceStitcher()
    stitcher.feed(untimed("heard but unplaced"))
    XCTAssertEqual(stitcher.progressSeconds, 0)
  }

  func testAHypothesisWithNothingToReadStillMovesProgress() {
    let stitcher = UtteranceStitcher()
    stitcher.feed(SpeechHypothesis(text: ".", words: [TimedWord(text: ".", startMs: 0, endMs: 900)]))
    XCTAssertEqual(stitcher.progressSeconds, 0.9, accuracy: 0.001)
  }
}
