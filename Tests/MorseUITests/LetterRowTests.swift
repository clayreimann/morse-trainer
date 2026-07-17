import SwiftUI
import XCTest
@testable import MorseUI

@MainActor
final class LetterRowTests: XCTestCase {
    func testCompletedLetterUsesGreen() {
        XCTAssertEqual(
            LetterRow.color(
                for: 0,
                completedCount: 1,
                currentIndex: 1,
                accent: .blue
            ),
            Color.green
        )
    }
}
