import SwiftUI
import MorseKit

/// Large tap/press target for keying Morse code.
///
/// - `.straightKey` mode renders a single full-width rounded-rectangle button
///   that reports press-down and press-up via `onDown`/`onUp`. The caller is
///   expected to timestamp those calls itself (e.g. `Date()` at the moment the
///   closure fires) and feed them to a `KeyerEngine`.
/// - `.paddle` mode renders a single full-width rounded-rectangle split into
///   two equal tap regions ("DIT"/"DAH") separated by a hairline divider; each
///   half reports a completed element via `onSymbol` as soon as its press ends.
///
/// Tone-gating is explicit and owned by this view: when `keySound` is `true`
/// and a `ToneGenerator` is injected, the button gates the tone on press-down
/// and off on press-up/release, so the sidetone tracks the physical gesture
/// exactly (independent of whatever the caller does with the timestamps).
public struct KeyButton: View {
    public let mode: InputMode
    public let keySound: Bool
    /// The key's fill color. Defaults to `.primary` (monochrome charcoal look).
    public let accent: Color
    /// The label/glyph color drawn on top of `accent`. Defaults to `.white`.
    public let accentOn: Color

    private let tone: ToneGenerator?
    private let onDown: () -> Void
    private let onUp: () -> Void
    private let onSymbol: (MorseSymbol) -> Void

    @State private var keyPressed = false
    @State private var dotPressed = false
    @State private var dashPressed = false

    private let keyHeight: CGFloat = 150

    public init(
        mode: InputMode,
        keySound: Bool,
        tone: ToneGenerator? = nil,
        accent: Color = .primary,
        accentOn: Color = .white,
        onDown: @escaping () -> Void = {},
        onUp: @escaping () -> Void = {},
        onSymbol: @escaping (MorseSymbol) -> Void = { _ in }
    ) {
        self.mode = mode
        self.keySound = keySound
        self.tone = tone
        self.accent = accent
        self.accentOn = accentOn
        self.onDown = onDown
        self.onUp = onUp
        self.onSymbol = onSymbol
    }

    public var body: some View {
        switch mode {
        case .straightKey:
            straightKeyBody
        case .paddle:
            paddleBody
        }
    }

    private var straightKeyBody: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.key)
            .fill(accent.opacity(keyPressed ? 0.82 : 1))
            .overlay(
                Text("KEY")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accentOn)
            )
            .frame(maxWidth: .infinity)
            .frame(height: keyHeight)
            .scaleEffect(keyPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: keyPressed)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.key))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !keyPressed else { return }
                        keyPressed = true
                        gateTone(true)
                        onDown()
                    }
                    .onEnded { _ in
                        keyPressed = false
                        gateTone(false)
                        onUp()
                    }
            )
    }

    private var paddleBody: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.key)
            .fill(accent)
            .frame(maxWidth: .infinity)
            .frame(height: keyHeight)
            .overlay(
                HStack(spacing: 0) {
                    paddleHalf(glyph: Theme.glyph(for: .dot), label: "DIT", isPressed: $dotPressed) {
                        gateTone(true)
                    } onRelease: {
                        gateTone(false)
                        onSymbol(.dot)
                    }
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 1)
                    paddleHalf(glyph: Theme.glyph(for: .dash), label: "DAH", isPressed: $dashPressed) {
                        gateTone(true)
                    } onRelease: {
                        gateTone(false)
                        onSymbol(.dash)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.key))
            )
    }

    private func paddleHalf(
        glyph: String,
        label: String,
        isPressed: Binding<Bool>,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(glyph)
                .font(.title2.weight(.bold))
            Text(label)
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(accentOn)
        .opacity(isPressed.wrappedValue ? 0.72 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(accent.opacity(isPressed.wrappedValue ? 0.82 : 1))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed.wrappedValue else { return }
                    isPressed.wrappedValue = true
                    onPress()
                }
                .onEnded { _ in
                    isPressed.wrappedValue = false
                    onRelease()
                }
        )
    }

    private func gateTone(_ on: Bool) {
        guard keySound else { return }
        tone?.gate(on)
    }
}

#Preview("Straight key") {
    KeyButton(mode: .straightKey, keySound: false)
        .padding()
}

#Preview("Paddle") {
    KeyButton(mode: .paddle, keySound: false)
        .padding()
}
