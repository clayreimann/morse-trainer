import SwiftUI
import MorseKit

/// Free-play sandbox: type any text, see it encoded to Morse live, and play
/// it back through the shared `MorsePlayer`. No progress tracking — this is
/// just an exploration/reference tool alongside the guided Learn/Listen
/// practice screens.
public struct PlaygroundView: View {
    private let settings: AppSettings
    private let player: MorsePlayer

    @State private var text: String = ""

    public init(settings: AppSettings, player: MorsePlayer) {
        self.settings = settings
        self.player = player
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            TextField("Type something\u{2026}", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(Theme.letterFont)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .autocorrectionDisabled()

            ScrollView {
                encodedDisplay
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .frame(maxHeight: .infinity)

            Button {
                player.play(text, settings: settings.timing, frequency: settings.frequencyHz)
            } label: {
                Label("Play", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .navigationTitle("Playground")
    }

    /// Renders each character of `text` as a letter-over-code chip, with
    /// spaces shown as a widened gap (word separation) rather than a chip,
    /// so letter boundaries and word boundaries both read clearly.
    private var encodedDisplay: some View {
        let characters = Array(text.uppercased())
        let codes = MorseCode.encode(text)
        return FlowLayout(spacing: Theme.Spacing.sm) {
            ForEach(Array(zip(characters.indices, characters)), id: \.0) { index, ch in
                if ch == " " {
                    Spacer()
                        .frame(width: Theme.Spacing.lg, height: 1)
                } else if let code = codes[index] {
                    VStack(spacing: 2) {
                        Text(String(ch))
                            .font(Theme.letterFont)
                        Text(Theme.codeString(for: code))
                            .font(Theme.codeFont)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(Color.secondary.opacity(0.08))
                    )
                } else {
                    VStack(spacing: 2) {
                        Text(String(ch))
                            .font(Theme.letterFont)
                        Text("?")
                            .font(Theme.codeFont)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Theme.Spacing.xs)
                }
            }
        }
    }
}

/// Minimal wrapping horizontal layout so long phrases don't overflow the
/// screen width; falls back to a simple `HStack` inside a wrap using
/// SwiftUI's `Layout` protocol.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Playground") {
    PlaygroundView(settings: AppSettings(), player: MorsePlayer(tone: ToneGenerator()))
}
