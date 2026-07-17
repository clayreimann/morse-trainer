import XCTest
@testable import MorseKit

final class TimingTests: XCTestCase {
    func testUnitMs() {
        XCTAssertEqual(Timing.unitMs(charWPM: 20), 60, accuracy: 0.0001)
    }
    func testParisIdentity() {
        // "PARIS " at 20 WPM (no Farnsworth) = 50 units = 3000 ms
        let s = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 1)
        let total = Timing.schedule(for: "PARIS ", settings: s)
            .reduce(0.0) { $0 + $1.duration }
        XCTAssertEqual(total, 3000, accuracy: 0.001)
    }
    func testScheduleForE() {
        // "E" = single dot = one .on of 1u; no trailing gap for a single char/no next char
        let s = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 1)
        XCTAssertEqual(Timing.schedule(for: "E", settings: s), [ToneEvent(on: true, duration: 60)])
    }
    func testFarnsworthStretchesTotalToEffective() {
        // char 20 WPM, effective 10 WPM: "PARIS " should take the 10-WPM duration = 6000 ms
        let s = TimingSettings(charWPM: 20, effectiveWPM: 10, wordSpacing: 1)
        let total = Timing.schedule(for: "PARIS ", settings: s)
            .reduce(0.0) { $0 + $1.duration }
        XCTAssertEqual(total, 6000, accuracy: 0.5)
    }
    func testWordSpacingAddsGapBetweenWords() {
        let base = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 1)
        let wide = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 2)
        let b = Timing.schedule(for: "E E", settings: base).reduce(0.0){$0+$1.duration}
        let w = Timing.schedule(for: "E E", settings: wide).reduce(0.0){$0+$1.duration}
        XCTAssertGreaterThan(w, b)
    }
}
