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
    func testClampedEffectiveWPM() {
        // Effective WPM above charWPM is clamped down to charWPM...
        XCTAssertEqual(AppSettings.clampedEffectiveWPM(30, charWPM: 20), 20)
        // ...but a value already at or below charWPM passes through unchanged.
        XCTAssertEqual(AppSettings.clampedEffectiveWPM(15, charWPM: 20), 15)
        XCTAssertEqual(AppSettings.clampedEffectiveWPM(20, charWPM: 20), 20)
    }
}
