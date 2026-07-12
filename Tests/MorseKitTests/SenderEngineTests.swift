import XCTest
@testable import MorseKit

final class SenderEngineTests: XCTestCase {
    func makeEngine(_ word: String) -> SenderEngine {
        SenderEngine(target: word, unitMs: 60, gate: .off, gracePercent: 25)
    }
    func testCorrectLetterTurnsGreen() {
        let e = makeEngine("TE")
        e.consume(.element(.dash)); e.consume(.letterBreak)   // T
        XCTAssertEqual(e.completedCount, 1)
        XCTAssertEqual(e.currentIndex, 1)
        e.consume(.element(.dot)); e.consume(.letterBreak)    // E
        XCTAssertTrue(e.isComplete)
    }
    func testWrongPatternDoesNotAdvance() {
        let e = makeEngine("T")
        e.consume(.element(.dot)); e.consume(.letterBreak)    // wrong (E not T)
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertTrue(e.lastLetterWasError)
    }
    func testGateMatchWPMRejectsBadTiming() {
        let e = SenderEngine(target: "T", unitMs: 60, gate: .matchWPM, gracePercent: 20)
        e.consumeTimed(.element(.dash), pressMs: 400)  // way over 3u=180ms +20%
        e.consume(.letterBreak)
        XCTAssertEqual(e.completedCount, 0) // pattern ok but timing gate fails
    }

    // Guided completion: the target is known, so a multi-element letter must
    // complete as soon as its expected number of elements are keyed — WITHOUT
    // needing a timing-driven letter break (humans can't hit inter-element
    // timing at speed). Reproduces the "can't send A (·−)" bug.
    func testMultiElementLetterCompletesByCount() {
        let e = makeEngine("A")                 // A = ·−
        e.consume(.element(.dot))
        XCTAssertEqual(e.completedCount, 0)     // only 1 of 2 elements so far
        XCTAssertFalse(e.lastLetterWasError)    // not rejected mid-letter
        e.consume(.element(.dash))              // no letterBreak needed
        XCTAssertTrue(e.isComplete)
    }

    // A premature letter break (from a natural pause between the dot and dash)
    // must NOT reject a letter the learner is still keying.
    func testPrematureLetterBreakDoesNotRejectPartialLetter() {
        let e = makeEngine("A")                 // A = ·−
        e.consume(.element(.dot))
        e.consume(.letterBreak)                 // spurious break during the pause
        XCTAssertFalse(e.lastLetterWasError)    // ignored, still waiting for the dash
        XCTAssertEqual(e.completedCount, 0)
        e.consume(.element(.dash))              // dash arrives → completes A
        XCTAssertTrue(e.isComplete)
    }
}
