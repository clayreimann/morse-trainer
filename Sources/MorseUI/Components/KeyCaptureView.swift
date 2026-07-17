import SwiftUI
import MorseKit

#if os(macOS)
import AppKit

/// macOS-only: captures physical key presses for Morse sending.
/// - Straight key: the space bar's down/up edges (with real press timing).
/// - Paddle: the configured dot/dash keys (momentary — one element per press).
///
/// Key-repeat events are ignored so holding a key neither spams elements nor
/// distorts straight-key timing. Handled keys are consumed so they don't also
/// activate focused controls (e.g. space "clicking" a button).
struct KeyCaptureView: NSViewRepresentable {
    var inputMode: InputMode
    var dotKey: Character
    var dashKey: Character
    var onDown: () -> Void
    var onUp: () -> Void
    var onDot: () -> Void
    var onDash: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.focusRingType = .none
        view.owner = self
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.owner = self
        // Reclaim first-responder so key events keep flowing here — but only
        // while actually on screen in the key window, so we don't steal focus
        // from another tab's text field.
        DispatchQueue.main.async {
            guard let window = nsView.window, window.isKeyWindow else { return }
            if window.firstResponder !== nsView {
                window.makeFirstResponder(nsView)
            }
        }
    }
}

final class KeyCaptureNSView: NSView {
    var owner: KeyCaptureView?
    private var spaceIsDown = false

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let owner else { super.keyDown(with: event); return }
        // Swallow auto-repeat for keys we handle; pass everything else through.
        if event.isARepeat {
            if handles(event, owner: owner) { return }
            super.keyDown(with: event)
            return
        }
        switch owner.inputMode {
        case .straightKey:
            if isSpace(event) {
                if !spaceIsDown { spaceIsDown = true; owner.onDown() }
                return
            }
        case .paddle:
            if let ch = character(of: event) {
                if ch == lower(owner.dotKey) { owner.onDot(); return }
                if ch == lower(owner.dashKey) { owner.onDash(); return }
            }
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        guard let owner else { super.keyUp(with: event); return }
        if owner.inputMode == .straightKey, isSpace(event) {
            if spaceIsDown { spaceIsDown = false; owner.onUp() }
            return
        }
        super.keyUp(with: event)
    }

    // MARK: helpers

    private func isSpace(_ event: NSEvent) -> Bool { event.keyCode == 49 }

    private func character(of event: NSEvent) -> Character? {
        event.charactersIgnoringModifiers?.lowercased().first
    }

    private func lower(_ ch: Character) -> Character {
        Character(String(ch).lowercased())
    }

    private func handles(_ event: NSEvent, owner: KeyCaptureView) -> Bool {
        switch owner.inputMode {
        case .straightKey:
            return isSpace(event)
        case .paddle:
            guard let ch = character(of: event) else { return false }
            return ch == lower(owner.dotKey) || ch == lower(owner.dashKey)
        }
    }
}

#else

/// Non-macOS: keyboard sending is a no-op; touch input drives the KeyButton.
struct KeyCaptureView: View {
    var inputMode: InputMode
    var dotKey: Character
    var dashKey: Character
    var onDown: () -> Void
    var onUp: () -> Void
    var onDot: () -> Void
    var onDash: () -> Void

    var body: some View { Color.clear.allowsHitTesting(false) }
}

#endif
