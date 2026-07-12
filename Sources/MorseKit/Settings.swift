public enum InputMode: String, Codable, Sendable { case straightKey, paddle }
public enum TimingGate: String, Codable, Sendable { case off, matchWPM, consistent }
public enum Difficulty: String, Codable, Sendable { case easy, hard }

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
    public init() {}
    public var timing: TimingSettings {
        TimingSettings(charWPM: charWPM, effectiveWPM: effectiveWPM, wordSpacing: wordSpacing)
    }
}
