import XCTest

@testable import TranscriberCore

final class PcmSliceTests: XCTestCase {
  func testNoBoundsIsTheWholeFile() {
    XCTAssertEqual(
      pcmSlice(startMs: nil, endMs: nil, sampleRate: 48_000, length: 96_000),
      PcmSlice(start: 0, end: 96_000))
  }

  func testBoundsConvertAtTheFilesOwnSampleRate() {
    XCTAssertEqual(
      pcmSlice(startMs: 500, endMs: 1500, sampleRate: 44_100, length: 441_000),
      PcmSlice(start: 22_050, end: 66_150))
  }

  func testAnEndPastTheFileClampsToItsLength() {
    XCTAssertEqual(
      pcmSlice(startMs: 1000, endMs: 60_000, sampleRate: 16_000, length: 32_000),
      PcmSlice(start: 16_000, end: 32_000))
  }

  func testAStartAtOrPastTheEndIsEmpty() {
    XCTAssertNil(pcmSlice(startMs: 2000, endMs: 2000, sampleRate: 16_000, length: 64_000))
    XCTAssertNil(pcmSlice(startMs: 3000, endMs: 2000, sampleRate: 16_000, length: 64_000))
  }

  func testAStartPastTheFileIsEmpty() {
    XCTAssertNil(pcmSlice(startMs: 10_000, endMs: nil, sampleRate: 16_000, length: 64_000))
  }

  func testANegativeStartClampsToZero() {
    XCTAssertEqual(
      pcmSlice(startMs: -250, endMs: 1000, sampleRate: 16_000, length: 64_000),
      PcmSlice(start: 0, end: 16_000))
  }

  func testAnEmptyFileIsEmpty() {
    XCTAssertNil(pcmSlice(startMs: nil, endMs: nil, sampleRate: 16_000, length: 0))
  }
}
