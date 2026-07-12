import XCTest
@testable import MorseKit

final class MasteryTests: XCTestCase {
    func testConfidenceRisesWithCorrectLowHesitancy() {
        var s = LetterStat(letter: "E")
        for _ in 0..<8 { s.record(correct: true, hesitancyMs: 200) }
        XCTAssertGreaterThan(s.confidence, MasteryPolicy.hintSuppressThreshold)
    }
    func testConfidenceStaysLowWithErrors() {
        var s = LetterStat(letter: "Q")
        for _ in 0..<8 { s.record(correct: false, hesitancyMs: 1500) }
        XCTAssertLessThan(s.confidence, MasteryPolicy.hintSuppressThreshold)
    }
    func testHintSuppressed() {
        var s = LetterStat(letter: "E")
        for _ in 0..<8 { s.record(correct: true, hesitancyMs: 150) }
        XCTAssertTrue(MasteryPolicy.shouldSuppressHint(for: s))
    }
}
