import XCTest
@testable import MorseKit

final class MorsePlayerScheduleTests: XCTestCase {
    func testBuildsScheduleFromTiming() {
        let s = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 1)
        let player = MorsePlayer(tone: ToneGenerator())
        XCTAssertEqual(player.buildSchedule(for: "E", settings: s),
                       Timing.schedule(for: "E", settings: s))
    }
}
