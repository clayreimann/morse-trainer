public enum InputMode: String, Codable, Sendable { case straightKey, paddle }
public enum TimingGate: String, Codable, Sendable { case off, matchWPM, consistent }
public enum Difficulty: String, Codable, Sendable { case easy, hard }

/// A user-chosen monochrome-first accent. `charcoal` is the neutral default;
/// the other three are the app's accent color options. Pure data — no
/// SwiftUI dependency — so it lives in `MorseKit`; `MorseUI.Theme` resolves
/// each case to an actual `Color`.
public enum AppColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case charcoal, indigo, teal, rust
    public var id: String { rawValue }
}

public struct AppSettings: Equatable, Sendable {
    public var charWPM: Double = 20
    public var effectiveWPM: Double = 20
    public var wordSpacing: Double = 1
    public var frequencyHz: Double = 550
    public var keySound: Bool = true
    public var inputMode: InputMode = .straightKey
    public var timingGate: TimingGate = .off
    public var gateGracePercent: Double = 25
    public var difficulty: Difficulty = .easy
    public var appColor: AppColor = .charcoal
    /// macOS: send with the physical keyboard (space = straight key; the paddle
    /// keys below for dot/dash). Ignored on platforms without a hardware keyboard.
    public var keyboardSendingEnabled: Bool = true
    public var paddleDotKey: String = "z"
    public var paddleDashKey: String = "x"
    public init() {}
    public var timing: TimingSettings {
        TimingSettings(charWPM: charWPM, effectiveWPM: effectiveWPM, wordSpacing: wordSpacing)
    }

    /// Farnsworth effective WPM can never exceed the character-sending WPM
    /// (that would mean "spacing out characters faster than they're sent").
    public static func clampedEffectiveWPM(_ effective: Double, charWPM: Double) -> Double {
        min(effective, charWPM)
    }
}
