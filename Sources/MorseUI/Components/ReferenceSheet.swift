import SwiftUI
import MorseKit

/// A–Z / 0–9 Morse reference chart, presented as a sheet. Each row shows the
/// letter's code and is tappable to hear it; row tint reflects the caller's
/// mastery confidence for that letter.
public struct ReferenceSheet: View {
    /// A–Z followed by 0–9, in `MorseCode.table` order of definition.
    public static let characters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    private let play: (String) -> Void
    private let confidence: (Character) -> Double

    /// - Parameters:
    ///   - play: Invoked with the tapped letter (as a `String`) so the caller
    ///     can drive its own `MorsePlayer` with whatever timing/frequency
    ///     settings are current (e.g. `{ morsePlayer.play($0, settings: settings.timing) }`).
    ///   - confidence: Returns 0...1 mastery confidence for a letter, used to tint its row.
    public init(
        play: @escaping (String) -> Void,
        confidence: @escaping (Character) -> Double
    ) {
        self.play = play
        self.confidence = confidence
    }

    public var body: some View {
        NavigationStack {
            List(ReferenceSheet.characters, id: \.self) { letter in
                Button {
                    play(String(letter))
                } label: {
                    HStack {
                        Text(String(letter))
                            .font(Theme.letterFont)
                            .frame(width: 32, alignment: .leading)
                        Text(ReferenceSheet.codeString(for: letter))
                            .font(Theme.codeFont)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(Theme.color(forConfidence: confidence(letter)))
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Reference")
        }
    }

    private static func codeString(for letter: Character) -> String {
        guard let code = MorseCode.code(for: letter) else { return "" }
        return Theme.codeString(for: code)
    }
}

#Preview("ReferenceSheet") {
    ReferenceSheet(
        play: { _ in },
        confidence: { letter in
            switch letter {
            case "A", "E", "T": return 0.9
            case "B", "S": return 0.35
            default: return 0.0
            }
        }
    )
}
