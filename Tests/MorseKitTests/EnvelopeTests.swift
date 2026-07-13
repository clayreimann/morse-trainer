import XCTest
@testable import MorseKit

final class EnvelopeTests: XCTestCase {
    // 5 ms at 48 kHz = 240 samples per ramp.
    func testAttackRampsUpGradually() {
        let env = Envelope(sampleRate: 48000, rampMs: 5)
        var g = 0.0
        g = env.next(current: g, gateOn: true)
        XCTAssertGreaterThan(g, 0)  // rising
        XCTAssertLessThan(g, 1)     // ...but not instantly full
        for _ in 0..<240 { g = env.next(current: g, gateOn: true) }
        XCTAssertEqual(g, 1, accuracy: 0.001)  // reaches full within the ramp
    }

    // The release must ramp DOWN, not jump to zero — an instant drop is the
    // click/pop the learner hears when letting up the key.
    func testReleaseRampsDownGradually() {
        let env = Envelope(sampleRate: 48000, rampMs: 5)
        var g = 1.0
        g = env.next(current: g, gateOn: false)
        XCTAssertLessThan(g, 1)     // falling
        XCTAssertGreaterThan(g, 0)  // NOT silent immediately (this removes the click)
        for _ in 0..<240 { g = env.next(current: g, gateOn: false) }
        XCTAssertEqual(g, 0, accuracy: 0.001)  // reaches silence within the ramp
    }

    func testHoldsAtTarget() {
        let env = Envelope(sampleRate: 48000, rampMs: 5)
        XCTAssertEqual(env.next(current: 1, gateOn: true), 1)
        XCTAssertEqual(env.next(current: 0, gateOn: false), 0)
    }
}
