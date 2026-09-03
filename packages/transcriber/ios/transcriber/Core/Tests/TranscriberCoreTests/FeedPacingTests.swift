import XCTest

@testable import TranscriberCore

final class FeedPacingTests: XCTestCase {
  func testAFeedInsideTheWindowNeverHolds() {
    XCTAssertFalse(feedHolds(fedSeconds: 20, progress: 0, progressAge: 20))
  }

  func testAFeedKeepingUpWithAMovingPositionDoesNotHold() {
    XCTAssertFalse(feedHolds(fedSeconds: 50, progress: 40, progressAge: 0.2))
  }

  func testAFeedRunningAheadOfAMovingPositionHolds() {
    XCTAssertTrue(feedHolds(fedSeconds: 120, progress: 40, progressAge: 0.2))
  }

  func testAPositionThatStoppedMovingIsAssumedToKeepAdvancing() {
    XCTAssertTrue(feedHolds(fedSeconds: 120, progress: 40, progressAge: 5))
    XCTAssertFalse(feedHolds(fedSeconds: 120, progress: 40, progressAge: 15))
  }

  func testAFeedWithNoPositionAtAllPacesAgainstTheClock() {
    XCTAssertTrue(feedHolds(fedSeconds: 300, progress: 0, progressAge: 5))
    XCTAssertFalse(feedHolds(fedSeconds: 300, progress: 0, progressAge: 120))
  }

  func testAStaleFeedIsHeldToFourAudioSecondsPerSecond() {
    XCTAssertTrue(feedHolds(fedSeconds: 1800, progress: 0, progressAge: 440))
    XCTAssertFalse(feedHolds(fedSeconds: 1800, progress: 0, progressAge: 460))
  }

  func testAFeedSlowerThanTheCapNeverHolds() {
    XCTAssertFalse(feedHolds(fedSeconds: 100, progress: 0, progressAge: 100))
  }

  func testTimeSpentBehindAMovingPositionEarnsNoCreditForLater() {
    XCTAssertFalse(feedHolds(fedSeconds: 630, progress: 600, progressAge: 0.1))
    XCTAssertTrue(feedHolds(fedSeconds: 660, progress: 600, progressAge: 2.5))
  }
}
