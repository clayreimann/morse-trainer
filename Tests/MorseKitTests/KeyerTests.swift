import XCTest
@testable import MorseKit

final class KeyerTests: XCTestCase {
    let unit = 60.0 // 20 WPM
    func testClassifyPress() {
        let k = Keyer(unitMs: unit)
        XCTAssertEqual(k.symbol(forPressMs: 55), .dot)   // ~1u
        XCTAssertEqual(k.symbol(forPressMs: 200), .dash) // >2u
    }
    func testClassifyGap() {
        let k = Keyer(unitMs: unit)
        XCTAssertEqual(k.gap(forMs: 60), .intraChar)   // 1u
        XCTAssertEqual(k.gap(forMs: 180), .interChar)  // 3u
        XCTAssertEqual(k.gap(forMs: 420), .interWord)  // 7u
    }
    func testStreamAssemblesLetterA() {
        // dot (dn 0 up 60), gap 60, dash (dn 120 up 300) then long gap -> letter A
        let e = KeyerEngine(unitMs: unit)
        var out: [KeyerEvent] = []
        e.onEvent = { out.append($0) }
        e.keyDown(at: 0);   e.keyUp(at: 60)
        e.keyDown(at: 120); e.keyUp(at: 300)
        e.flush(at: 900)    // long trailing gap => letter break
        XCTAssertEqual(out, [.element(.dot), .element(.dash), .letterBreak])
    }
}
