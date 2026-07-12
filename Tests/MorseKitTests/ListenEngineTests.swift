import XCTest
@testable import MorseKit

final class ListenEngineTests: XCTestCase {
    func testLiveModeChecksPerCharacter() {
        let e = ListenEngine(target: "TEA", mode: .live)
        XCTAssertEqual(e.type("T"), .correct)
        XCTAssertEqual(e.type("X"), .incorrect)   // wrong second char
        XCTAssertEqual(e.type("E"), .correct)
        XCTAssertEqual(e.type("A"), .correct)
        XCTAssertTrue(e.isComplete)
    }
    func testCopyThenCheckComparesWhole() {
        let e = ListenEngine(target: "TEA", mode: .copyThenCheck)
        let result = e.submit("TEA")
        XCTAssertEqual(result, .correct)
        XCTAssertEqual(e.submit("TEX"), .incorrect)
    }
}
