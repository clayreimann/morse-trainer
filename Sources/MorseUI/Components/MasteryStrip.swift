import SwiftUI

/// A horizontal strip of per-letter mastery chips: green once confidence
/// crosses `MasteryPolicy.hintSuppressThreshold`, amber while in progress,
/// gray if no attempts have been recorded yet.
public struct MasteryStrip: View {
    public let entries: [(letter: Character, confidence: Double)]

    public init(entries: [(letter: Character, confidence: Double)]) {
        self.entries = entries
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    let color = Theme.color(forConfidence: entry.confidence)
                    Text(String(entry.letter))
                        .font(Theme.codeFont.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.22))
                        .foregroundStyle(color)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(color, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xs)
        }
    }
}

#Preview("MasteryStrip") {
    MasteryStrip(entries: [
        ("A", 0.92), ("B", 0.45), ("C", 0.0), ("D", 0.71), ("E", 0.15), ("F", 0.0),
    ])
    .padding()
}
