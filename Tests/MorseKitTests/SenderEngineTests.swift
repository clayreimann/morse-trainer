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
}
