import SwiftUI
import MorseKit

/// Renders the letters of the current target word: completed letters green,
/// the active letter blue (with an optional dot/dash hint beneath it), and
/// remaining letters gray.
public struct LetterRow: View {
    public let letters: [Character]
    public let completedCount: Int
    public let currentIndex: Int
    /// The current letter's code, shown beneath it. `nil` suppresses the hint
    /// entirely (hard difficulty, or the letter is already mastered).
    public let hintForCurrent: [MorseSymbol]?

    public init(letters: [Character], completedCount: Int, currentIndex: Int, hintForCurrent: [MorseSymbol]?) {
        self.letters = letters
        self.completedCount = completedCount
        self.currentIndex = currentIndex
        self.hintForCurrent = hintForCurrent
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                VStack(spacing: Theme.Spacing.xs) {
                    Text(String(letter))
                        .font(Theme.letterFont)
                        .foregroundStyle(color(for: index))

                    if index == currentIndex, let hint = hintForCurrent {
                        Text(Theme.codeString(for: hint))
                            .font(Theme.codeFont)
                            .foregroundStyle(Theme.current)
                    } else {
                        // Reserve the row's height so letters don't jump when a hint appears/disappears.
                        Text(" ")
                            .font(Theme.codeFont)
                            .hidden()
                    }
                }
            }
        }
    }

    private func color(for index: Int) -> Color {
        if index < completedCount { return Theme.mastered }
        if index == currentIndex { return Theme.current }
        return Theme.locked
    }
}

#Preview("With hint") {
    LetterRow(
        letters: Array("NOTE"),
        completedCount: 2,
        currentIndex: 2,
        hintForCurrent: MorseCode.code(for: "T")
    )
    .padding()
}

#Preview("Hint suppressed") {
    LetterRow(
        letters: Array("NOTE"),
        completedCount: 2,
        currentIndex: 2,
        hintForCurrent: nil
    )
    .padding()
}
