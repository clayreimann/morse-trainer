import SwiftUI
import MorseKit

/// Bridges `AppSettings` to `@AppStorage`-persisted UserDefaults keys (one per
/// field) behind a plain `ObservableObject` API. `@AppStorage` itself only
/// participates in SwiftUI's update cycle when declared directly inside a
/// `View`; since these are stored on a class instead, each public setter
/// calls `objectWillChange.send()` explicitly so views observing this store
/// (`@StateObject`/`@ObservedObject`) refresh correctly when a field changes —
/// including `$store.<field>` dynamic-member bindings used by `SettingsView`.
///
/// This store is owned by a later `RootView` and threaded to screens as a
/// plain `AppSettings` snapshot via `settings`; `LearnSendView`/`ListenView`
/// never reference `SettingsStore` directly.
public final class SettingsStore: ObservableObject {
    @AppStorage("morse.charWPM") private var storedCharWPM: Double = 20
    @AppStorage("morse.effectiveWPM") private var storedEffectiveWPM: Double = 20
    @AppStorage("morse.wordSpacing") private var storedWordSpacing: Double = 1
    @AppStorage("morse.frequencyHz") private var storedFrequencyHz: Double = 550
    @AppStorage("morse.keySound") private var storedKeySound: Bool = true
    @AppStorage("morse.inputMode") private var storedInputModeRaw: String = InputMode.straightKey.rawValue
    @AppStorage("morse.timingGate") private var storedTimingGateRaw: String = TimingGate.off.rawValue
    @AppStorage("morse.gateGracePercent") private var storedGateGracePercent: Double = 25
    @AppStorage("morse.difficulty") private var storedDifficultyRaw: String = Difficulty.easy.rawValue

    public init() {}

    public var charWPM: Double {
        get { storedCharWPM }
        set {
            objectWillChange.send()
            storedCharWPM = newValue
            // Keep effective WPM consistent if the char rate drops below it.
            storedEffectiveWPM = AppSettings.clampedEffectiveWPM(storedEffectiveWPM, charWPM: newValue)
        }
    }

    public var effectiveWPM: Double {
        get { storedEffectiveWPM }
        set {
            objectWillChange.send()
            storedEffectiveWPM = AppSettings.clampedEffectiveWPM(newValue, charWPM: storedCharWPM)
        }
    }

    public var wordSpacing: Double {
        get { storedWordSpacing }
        set { objectWillChange.send(); storedWordSpacing = newValue }
    }

    public var frequencyHz: Double {
        get { storedFrequencyHz }
        set { objectWillChange.send(); storedFrequencyHz = newValue }
    }

    public var keySound: Bool {
        get { storedKeySound }
        set { objectWillChange.send(); storedKeySound = newValue }
    }

    public var inputMode: InputMode {
        get { InputMode(rawValue: storedInputModeRaw) ?? .straightKey }
        set { objectWillChange.send(); storedInputModeRaw = newValue.rawValue }
    }

    public var timingGate: TimingGate {
        get { TimingGate(rawValue: storedTimingGateRaw) ?? .off }
        set { objectWillChange.send(); storedTimingGateRaw = newValue.rawValue }
    }

    public var gateGracePercent: Double {
        get { storedGateGracePercent }
        set { objectWillChange.send(); storedGateGracePercent = newValue }
    }

    public var difficulty: Difficulty {
        get { Difficulty(rawValue: storedDifficultyRaw) ?? .easy }
        set { objectWillChange.send(); storedDifficultyRaw = newValue.rawValue }
    }

    /// A plain, UI-framework-independent snapshot of the current settings —
    /// this is what `RootView` threads down into the practice screens.
    public var settings: AppSettings {
        var s = AppSettings()
        s.charWPM = charWPM
        s.effectiveWPM = effectiveWPM
        s.wordSpacing = wordSpacing
        s.frequencyHz = frequencyHz
        s.keySound = keySound
        s.inputMode = inputMode
        s.timingGate = timingGate
        s.gateGracePercent = gateGracePercent
        s.difficulty = difficulty
        return s
    }
}

/// Settings screen: WPM/Farnsworth/word-spacing timing, tone frequency, key
/// sound, input mode, timing gate + grace, and difficulty.
public struct SettingsView: View {
    @ObservedObject private var store: SettingsStore

    public init(store: SettingsStore) {
        self.store = store
    }

    public var body: some View {
        Form {
            Section("Timing") {
                Stepper(
                    "Character speed: \(Int(store.charWPM)) WPM",
                    value: $store.charWPM, in: 5...40, step: 1
                )
                Stepper(
                    "Effective (Farnsworth) speed: \(Int(store.effectiveWPM)) WPM",
                    value: $store.effectiveWPM, in: 5...store.charWPM, step: 1
                )
                VStack(alignment: .leading) {
                    Text("Word spacing: \(store.wordSpacing, specifier: "%.1f")\u{00D7}")
                    Slider(value: $store.wordSpacing, in: 1...3, step: 0.1)
                }
            }

            Section("Sound") {
                VStack(alignment: .leading) {
                    Text("Tone frequency: \(Int(store.frequencyHz)) Hz")
                    Slider(value: $store.frequencyHz, in: 300...900, step: 5)
                }
                Toggle("Key sound (sidetone)", isOn: $store.keySound)
            }

            Section("Input") {
                Picker("Input mode", selection: $store.inputMode) {
                    Text("Straight key").tag(InputMode.straightKey)
                    Text("Paddle").tag(InputMode.paddle)
                }
            }

            Section("Timing gate") {
                Picker("Gate", selection: $store.timingGate) {
                    Text("Off").tag(TimingGate.off)
                    Text("Match WPM").tag(TimingGate.matchWPM)
                    Text("Consistent").tag(TimingGate.consistent)
                }
                if store.timingGate != .off {
                    VStack(alignment: .leading) {
                        Text("Grace: \(Int(store.gateGracePercent))%")
                        Slider(value: $store.gateGracePercent, in: 5...50, step: 1)
                    }
                }
            }

            Section("Difficulty") {
                Picker("Difficulty", selection: $store.difficulty) {
                    Text("Easy (hints shown)").tag(Difficulty.easy)
                    Text("Hard (no hints)").tag(Difficulty.hard)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

#Preview("Settings") {
    SettingsView(store: SettingsStore())
}
