import SwiftUI
import MorseKit

/// Large tap/press target for keying Morse code.
///
/// - `.straightKey` mode renders a single button that reports press-down and
///   press-up via `onDown`/`onUp`. The caller is expected to timestamp those
///   calls itself (e.g. `Date()` at the moment the closure fires) and feed
///   them to a `KeyerEngine`.
/// - `.paddle` mode renders two buttons ("dit"/"dah") that each report a
///   completed element via `onSymbol` as soon as the press ends.
///
/// Tone-gating is explicit and owned by this view: when `keySound` is `true`
/// and a `ToneGenerator` is injected, the button gates the tone on press-down
/// and off on press-up/release, so the sidetone tracks the physical gesture
/// exactly (independent of whatever the caller does with the timestamps).
public struct KeyButton: View {
    public let mode: InputMode
    public let keySound: Bool

    private let tone: ToneGenerator?
    private let onDown: () -> Void
    private let onUp: () -> Void
    private let onSymbol: (MorseSymbol) -> Void

    @State private var keyPressed = false
    @State private var dotPressed = false
    @State private var dashPressed = false

    public init(
        mode: InputMode,
        keySound: Bool,
        tone: ToneGenerator? = nil,
        onDown: @escaping () -> Void = {},
        onUp: @escaping () -> Void = {},
        onSymbol: @escaping (MorseSymbol) -> Void = { _ in }
    ) {
        self.mode = mode
        self.keySound = keySound
        self.tone = tone
        self.onDown = onDown
        self.onUp = onUp
        self.onSymbol = onSymbol
    }

    public var body: some View {
        switch mode {
        case .straightKey:
            pad(label: "KEY", isPressed: $keyPressed, size: 140) {
                gateTone(true)
                onDown()
            } onRelease: {
                gateTone(false)
                onUp()
            }
        case .paddle:
            HStack(spacing: Theme.Spacing.lg) {
                pad(label: "DIT", isPressed: $dotPressed, size: 110) {
                    gateTone(true)
                } onRelease: {
                    gateTone(false)
                    onSymbol(.dot)
                }
                pad(label: "DAH", isPressed: $dashPressed, size: 110) {
                    gateTone(true)
                } onRelease: {
                    gateTone(false)
                    onSymbol(.dash)
                }
            }
        }
    }

    private func gateTone(_ on: Bool) {
        guard keySound else { return }
        tone?.gate(on)
    }

    private func pad(
        label: String,
        isPressed: Binding<Bool>,
        size: CGFloat,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        Circle()
            .fill(isPressed.wrappedValue ? Theme.current : Theme.locked.opacity(0.25))
            .overlay(
                Text(label)
                    .font(.headline)
                    .foregroundStyle(isPressed.wrappedValue ? Color.white : Color.primary)
            )
            .frame(width: size, height: size)
            .contentShape(Circle())
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
}

#Preview("Straight key") {
    KeyButton(mode: .straightKey, keySound: false)
        .padding()
}

#Preview("Paddle") {
    KeyButton(mode: .paddle, keySound: false)
        .padding()
}
