import SwiftUI
import MorseKit

/// Practice #2 — "Listen". Plays a target word and checks the learner's typed
/// copy, either live (character-by-character) or copy-then-check (type the
/// whole word, then submit).
///
/// Intentionally decoupled from `SettingsStore` — see `LearnSendView` for the
/// same rationale. A future `RootView` owns `SettingsStore` and passes
/// `store.settings` down.
public struct ListenView: View {
    private let settings: AppSettings
    private let progress: ProgressStore
    private let player: MorsePlayer

    @State private var mode: ListenMode
    @State private var target: String
    @State private var engine: ListenEngine

    @State private var liveInput = ""
    @State private var liveResults: [(Character, CheckResult)] = []

    @State private var copyInput = ""
    @State private var copyResult: CheckResult?

    public init(settings: AppSettings, progress: ProgressStore, player: MorsePlayer) {
        self.settings = settings
        self.progress = progress
        self.player = player
        let word = ListenView.pickWord(progress: progress)
        _mode = State(initialValue: .live)
        _target = State(initialValue: word)
        _engine = State(initialValue: ListenEngine(target: word, mode: .live))
    }

    private var accent: Color {
        settings.appColor.color
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Picker("Mode", selection: $mode) {
                Text("Live").tag(ListenMode.live)
                Text("Copy then check").tag(ListenMode.copyThenCheck)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, newMode in resetAttempt(mode: newMode) }

            Button {
                player.play(target, settings: settings.timing, frequency: settings.frequencyHz)
            } label: {
                Label("Play", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(accent)

            switch mode {
            case .live:
                liveSection
            case .copyThenCheck:
                copySection
            }

            Spacer()

            Button("New word") {
                target = ListenView.pickWord(progress: progress)
                resetAttempt(mode: mode)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Live mode

    private var liveSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if !liveResults.isEmpty {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(Array(liveResults.enumerated()), id: \.offset) { _, entry in
                        let (ch, result) = entry
                        Group {
                            if result == .correct {
                                Text(String(ch))
                                    .font(Theme.codeFont.weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(accent))
                                    .foregroundStyle(settings.appColor.onColor)
                            } else {
                                Text(String(ch))
                                    .font(Theme.codeFont.weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(Circle().strokeBorder(Color.red, lineWidth: 2))
                                    .foregroundStyle(Color.red)
                            }
                        }
                    }
                }
            }

            TextField("Type what you hear\u{2026}", text: $liveInput)
                .textFieldStyle(.roundedBorder)
                .disabled(engine.isComplete)
                .onChange(of: liveInput) { oldValue, newValue in
                    guard newValue.count > oldValue.count, let last = newValue.last else { return }
                    let result = engine.type(String(last))
                    liveResults.append((last, result))
                }

            if engine.isComplete {
                Text("Copied correctly!")
                    .font(.headline)
                    .foregroundStyle(Theme.mastered)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Theme.cardStroke)
                )
        )
    }

    // MARK: - Copy-then-check mode

    private var copySection: some View {
        VStack(spacing: Theme.Spacing.md) {
            TextField("Type the whole word\u{2026}", text: $copyInput)
                .textFieldStyle(.roundedBorder)
                .disabled(copyResult != nil)
                .onSubmit(submitCopy)
                .autocorrectionDisabled()

            Button("Submit", action: submitCopy)
                .buttonStyle(.borderedProminent)
                .disabled(copyInput.isEmpty || copyResult != nil)

            if let copyResult {
                VStack(spacing: Theme.Spacing.xs) {
                    Text(copyResult == .correct ? "Correct!" : "Not quite.")
                        .font(.headline)
                        .foregroundStyle(copyResult == .correct ? Theme.mastered : Color.red)
                    Text("Answer: \(target)")
                        .font(Theme.codeFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Theme.cardStroke)
                )
        )
    }

    private func submitCopy() {
        guard copyResult == nil else { return }
        copyResult = engine.submit(copyInput)
    }

    // MARK: - Word selection / reset

    private func resetAttempt(mode: ListenMode) {
        engine = ListenEngine(target: target, mode: mode)
        liveInput = ""
        liveResults = []
        copyInput = ""
        copyResult = nil
    }

    /// Picks a random word whose letters are all within the learner's
    /// currently-unlocked curriculum stages.
    private static func pickWord(progress: ProgressStore) -> String {
        let stages = Curriculum.default.stages
        let unlockedStage = min(max(progress.highestUnlockedStage, 0), stages.count - 1)
        let unlockedLetters = Curriculum.default.lettersUnlocked(throughStage: unlockedStage)
        let candidates = stages.prefix(unlockedStage + 1)
            .flatMap { $0.words }
            .filter { Set($0).isSubset(of: unlockedLetters) }
        return candidates.randomElement() ?? stages[0].words[0]
    }
}

#Preview("Listen") {
    ListenView(
        settings: AppSettings(),
        progress: try! ProgressStore(inMemory: true),
        player: MorsePlayer(tone: ToneGenerator())
    )
}
