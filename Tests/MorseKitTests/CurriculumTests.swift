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
}
