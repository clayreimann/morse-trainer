import XCTest
@testable import MorseKit

/// Logic-level flow test for the Learn/Send screen: drives a `SenderEngine`
/// through a full word via the same `KeyerEvent` sequence the UI would
/// produce, asserting green progression (`completedCount`/`currentIndex`)
/// and completion, plus that a wrong pattern flags `lastLetterWasError`.
final class SenderFlowTests: XCTestCase {
    func testFullWordProgressesGreenToCompletion() {
        // "TEA": T = dash, E = dot, A = dot-dash
        let e = SenderEngine(target: "TEA", unitMs: 60, gate: .off, gracePercent: 25)
        var completedLetters: [Int] = []
        e.onLetterComplete = { completedLetters.append($0) }

        e.consume(.element(.dash)); e.consume(.letterBreak) // T
        XCTAssertEqual(e.completedCount, 1)
        XCTAssertEqual(e.currentIndex, 1)
        XCTAssertFalse(e.lastLetterWasError)

        e.consume(.element(.dot)); e.consume(.letterBreak) // E
        XCTAssertEqual(e.completedCount, 2)
        XCTAssertEqual(e.currentIndex, 2)

        e.consume(.element(.dot)); e.consume(.element(.dash)); e.consume(.letterBreak) // A
        XCTAssertEqual(e.completedCount, 3)
        XCTAssertTrue(e.isComplete)
        XCTAssertEqual(completedLetters, [0, 1, 2])
    }

    func testWrongPatternFlagsErrorAndDoesNotAdvance() {
        let e = SenderEngine(target: "TEA", unitMs: 60, gate: .off, gracePercent: 25)
        var errored: [Int] = []
        e.onError = { errored.append($0) }

        // T expected (dash); send a dot instead.
        e.consume(.element(.dot)); e.flushLetter()
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertEqual(e.currentIndex, 0)
        XCTAssertTrue(e.lastLetterWasError)
        XCTAssertEqual(errored, [0])
        XCTAssertFalse(e.isComplete)
    }
}
