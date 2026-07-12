import SwiftUI
import MorseKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Design tokens (colors, typography, spacing) shared by every `MorseUI` component.
///
/// Colors are built on platform *system* colors so they automatically adapt to
/// light/dark mode (and accessibility contrast settings) without any custom logic.
public enum Theme {

    // MARK: - Colors

    #if canImport(UIKit)
    /// A letter/skill currently being learned (not yet mastered).
    public static let learning = Color(uiColor: .systemOrange)
    /// A letter/skill mastered (confidence >= `MasteryPolicy.hintSuppressThreshold`).
    public static let mastered = Color(uiColor: .systemGreen)
    /// A letter/stage not yet reached or with no recorded confidence.
    public static let locked = Color(uiColor: .systemGray)
    /// The item currently in focus/active.
    public static let current = Color(uiColor: .systemBlue)
    #elseif canImport(AppKit)
    public static let learning = Color(nsColor: .systemOrange)
    public static let mastered = Color(nsColor: .systemGreen)
    public static let locked = Color(nsColor: .systemGray)
    public static let current = Color(nsColor: .systemBlue)
    #else
    public static let learning = Color.orange
    public static let mastered = Color.green
    public static let locked = Color.gray
    public static let current = Color.blue
    #endif

    /// Maps a 0...1 mastery confidence value to a status color, per `MasteryPolicy`.
    public static func color(forConfidence confidence: Double) -> Color {
        if confidence >= MasteryPolicy.hintSuppressThreshold { return mastered }
        if confidence > 0 { return learning }
        return locked
    }

    // MARK: - Typography

    /// Monospace style used for rendering dot/dash code sequences.
    public static let codeFont: Font = .system(.body, design: .monospaced)
    public static let letterFont: Font = .system(.title2, design: .rounded).weight(.semibold)
    public static let titleFont: Font = .system(.title, design: .rounded).weight(.bold)

    /// Printable glyph for a single Morse element ("\u{00B7}" dot, "\u{2212}" dash).
    public static func glyph(for symbol: MorseSymbol) -> String {
        switch symbol {
        case .dot: return "\u{00B7}"
        case .dash: return "\u{2212}"
        }
    }

    /// Printable, space-separated glyph string for a full code sequence.
    public static func codeString(for code: [MorseSymbol]) -> String {
        code.map(glyph(for:)).joined(separator: " ")
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    // MARK: - Shape

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 20
    }
}
