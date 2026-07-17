import XCTest
@testable import MorseKit

final class SenderEngineTests: XCTestCase {
    func makeEngine(_ word: String) -> SenderEngine {
        SenderEngine(target: word, unitMs: 60, gate: .off, gracePercent: 25)
    }
    func testCorrectLetterTurnsGreenAfterFlush() {
        let e = makeEngine("TE")
        e.consume(.element(.dash))
        XCTAssertEqual(e.completedCount, 0)
        e.flushLetter()
        XCTAssertEqual(e.completedCount, 1)
        XCTAssertEqual(e.currentIndex, 1)

        e.consume(.element(.dot))
        XCTAssertEqual(e.completedCount, 1)
        e.flushLetter()
        XCTAssertTrue(e.isComplete)
    }
    func testWrongPatternDoesNotAdvance() {
        let e = makeEngine("T")
        e.consume(.element(.dot)); e.flushLetter()    // wrong (E not T), judged via pause
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertTrue(e.lastLetterWasError)
    }
    func testGateMatchWPMRejectsBadTimingAfterFlush() {
        let e = SenderEngine(target: "T", unitMs: 60, gate: .matchWPM, gracePercent: 20)
        e.consumeTimed(.element(.dash), pressMs: 400)
        XCTAssertFalse(e.lastLetterWasError)
        e.flushLetter()
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertTrue(e.lastLetterWasError)
    }

    func testMultiElementLetterCompletesAfterFlush() {
        let e = makeEngine("A")
        e.consume(.element(.dot))
        e.consume(.element(.dash))
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertFalse(e.lastLetterWasError)
        e.flushLetter()
        XCTAssertTrue(e.isComplete)
    }

    func testPrematureLetterBreakDoesNotCompletePartialLetter() {
        let e = makeEngine("A")
        e.consume(.element(.dot))
        e.consume(.letterBreak)
        XCTAssertFalse(e.lastLetterWasError)
        XCTAssertEqual(e.completedCount, 0)
        e.consume(.element(.dash))
        XCTAssertEqual(e.completedCount, 0)
        e.flushLetter()
        XCTAssertTrue(e.isComplete)
    }

    // A buffer whose element COUNT matches the target but whose pattern is
    // wrong (·− sent as −·) must not be judged the instant the count is hit.
    // It should only be judged once the learner pauses (flushLetter()).
    func testWrongLengthNotJudgedUntilFlush() {
        let e = makeEngine("A")                 // A = ·−
        e.consume(.element(.dash)); e.consume(.element(.dot)) // −· (wrong order)
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertFalse(e.lastLetterWasError)    // not yet judged
        e.flushLetter()
        XCTAssertTrue(e.lastLetterWasError)
    }

    func testOvershootWaitsForFlushThenRejects() {
        let e = makeEngine("E")
        e.consume(.element(.dot))
        e.consume(.element(.dot))
        e.consume(.element(.dot))
        e.consume(.element(.dot))
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertFalse(e.lastLetterWasError)
        e.flushLetter()
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertTrue(e.lastLetterWasError)
    }

    // Flushing with nothing keyed is a no-op: no error, no advance.
    func testFlushWithEmptyBufferIsNoop() {
        let e = makeEngine("A")
        var errorCount = 0
        e.onError = { _ in errorCount += 1 }
        e.flushLetter()
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertFalse(e.lastLetterWasError)
        XCTAssertEqual(errorCount, 0)
    }

    func testExactMatchWaitsForFlush() {
        let e = makeEngine("E")
        e.consume(.element(.dot))
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertFalse(e.lastLetterWasError)
        e.flushLetter()
        XCTAssertTrue(e.isComplete)
    }
}
