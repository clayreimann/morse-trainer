import XCTest
@testable import MorseKit

final class CurriculumTests: XCTestCase {
    func testStagesAreOrderedAndCumulative() {
        let stages = Curriculum.default.stages
        XCTAssertEqual(stages.first?.newLetters, ["E","T","A"])
        // every word in a stage uses only letters unlocked up to and including that stage
        var unlocked = Set<Character>()
        for stage in stages {
            unlocked.formUnion(stage.newLetters.map { Character($0) })
            for word in stage.words {
                XCTAssertTrue(Set(word).isSubset(of: unlocked), "\(word) uses unlearned letters")
            }
        }
    }
    func testLettersUnlockedThroughStage() {
        XCTAssertEqual(Curriculum.default.lettersUnlocked(throughStage: 1),
                       Set("ETAON".map { $0 }))
    }
    func testCurriculumCoversAllTwentySixLetters() {
        let all = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let unlocked = Curriculum.default.lettersUnlocked(throughStage: Curriculum.default.stages.count - 1)
        XCTAssertEqual(unlocked, all, "missing: \(all.subtracting(unlocked).sorted())")
    }
    func testEachStageIntroducesNewLetters() {
        // Indices are sequential and every stage adds at least one letter.
        for (i, stage) in Curriculum.default.stages.enumerated() {
            XCTAssertEqual(stage.index, i)
            XCTAssertFalse(stage.newLetters.isEmpty)
        }
    }
    func testQuizWords() {
        let words0 = Curriculum.default.quizWords(throughStage: 0)
        XCTAssertFalse(words0.isEmpty)
        XCTAssertTrue(words0.contains("AT"))
        XCTAssertTrue(words0.contains("EAT"))
        let allowed: Set<Character> = ["E", "T", "A"]
        for word in words0 {
            XCTAssertTrue(Set(word).isSubset(of: allowed), "\(word) uses letters beyond stage 0")
        }
        let words3 = Curriculum.default.quizWords(throughStage: 3)
        XCTAssertGreaterThanOrEqual(words3.count, words0.count)
    }
}
