import XCTest
import SwiftData
@testable import MorseKit

final class ProgressStoreTests: XCTestCase {
    func testRecordAndReadBackConfidence() throws {
        let store = try ProgressStore(inMemory: true)
        for _ in 0..<8 { store.record(letter: "E", correct: true, hesitancyMs: 150) }
        XCTAssertTrue(store.isHintSuppressed(for: "E"))
        XCTAssertFalse(store.isHintSuppressed(for: "Q"))
    }
    func testStageUnlockPersists() throws {
        let store = try ProgressStore(inMemory: true)
        XCTAssertEqual(store.highestUnlockedStage, 0)
        store.completeStage(0)
        XCTAssertEqual(store.highestUnlockedStage, 1)
    }
}
