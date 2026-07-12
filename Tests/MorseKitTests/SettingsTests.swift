import XCTest
@testable import MorseKit

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let s = AppSettings()
        XCTAssertEqual(s.frequencyHz, 550)
        XCTAssertEqual(s.charWPM, 20)
        XCTAssertEqual(s.effectiveWPM, 20)
        XCTAssertEqual(s.wordSpacing, 1)
        XCTAssertTrue(s.keySound)
        XCTAssertEqual(s.inputMode, .straightKey)
        XCTAssertEqual(s.timingGate, .off)
        XCTAssertEqual(s.difficulty, .easy)
    }
    func testTimingSettingsProjection() {
        var s = AppSettings(); s.charWPM = 20; s.effectiveWPM = 10; s.wordSpacing = 1.5
        XCTAssertEqual(s.timing, TimingSettings(charWPM: 20, effectiveWPM: 10, wordSpacing: 1.5))
    }
}
