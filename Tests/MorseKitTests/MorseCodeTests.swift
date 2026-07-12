import XCTest
@testable import MorseKit

final class MorseCodeTests: XCTestCase {
    func testKnownLetters() {
        XCTAssertEqual(MorseCode.code(for: "A"), [.dot, .dash])
        XCTAssertEqual(MorseCode.code(for: "N"), [.dash, .dot])
        XCTAssertEqual(MorseCode.code(for: "5"), [.dot,.dot,.dot,.dot,.dot])
    }
    func testCaseInsensitive() {
        XCTAssertEqual(MorseCode.code(for: "a"), MorseCode.code(for: "A"))
    }
    func testDecodeRoundTrip() {
        for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" {
            let code = MorseCode.code(for: c)!
            XCTAssertEqual(MorseCode.character(for: code), c)
        }
    }
    func testEncodeString() {
        // "AN" -> [[.dot,.dash],[.dash,.dot]]
        XCTAssertEqual(MorseCode.encode("AN"), [[.dot,.dash],[.dash,.dot]])
    }
    func testUnknownCharacterIsNil() {
        XCTAssertNil(MorseCode.code(for: "~"))
    }
}
