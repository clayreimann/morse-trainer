import XCTest
@testable import MorseKit

final class EnvelopeTests: XCTestCase {
    func testRampReachesFullThenZero() {
        let env = Envelope(sampleRate: 48000, rampMs: 5)
        XCTAssertEqual(env.gain(atSample: 0, gateOn: true), 0, accuracy: 0.01)   // start of attack
        XCTAssertEqual(env.gain(atSample: 240, gateOn: true), 1, accuracy: 0.01) // 5ms in = full
        XCTAssertEqual(env.gain(atSample: 10_000, gateOn: true), 1, accuracy: 0.0001)
    }
}
