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
    /// The user's chosen accent, used for the current letter and its hint.
    public let accent: Color

    /// Fixed width for every letter's column, sized to fit the longest
    /// curriculum word (7 letters, e.g. "NUCLEAR") within a phone width. The
    /// current-letter hint may extend slightly past its slot (it uses
    /// `.fixedSize` and doesn't drive slot width) — that's fine.
    private let slotWidth: CGFloat = 40

    public init(
        letters: [Character],
        completedCount: Int,
        currentIndex: Int,
        hintForCurrent: [MorseSymbol]?,
        accent: Color = .primary
    ) {
        self.letters = letters
        self.completedCount = completedCount
        self.currentIndex = currentIndex
        self.hintForCurrent = hintForCurrent
        self.accent = accent
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                VStack(spacing: Theme.Spacing.xs) {
                    Text(String(letter))
                        .font(Theme.letterFont)
                        .foregroundStyle(Self.color(
                            for: index,
                            completedCount: completedCount,
                            currentIndex: currentIndex,
                            accent: accent
                        ))

                    if index == currentIndex, let hint = hintForCurrent {
                        Text(Theme.codeString(for: hint))
                            .font(Theme.codeFont)
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    } else {
                        // Reserve the row's height so letters don't jump when a hint appears/disappears.
                        Text(" ")
                            .font(Theme.codeFont)
                            .hidden()
                    }
                }
                .frame(width: slotWidth)
            }
        }
    }

    static func color(
        for index: Int,
        completedCount: Int,
        currentIndex: Int,
        accent: Color
    ) -> Color {
        if index < completedCount { return .green }
        if index == currentIndex { return accent }
        return Color(white: 0.75)
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
