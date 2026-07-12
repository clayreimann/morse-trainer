import SwiftUI
import Foundation
import MorseKit

/// Practice #1 — "Learn/Send". Drives a `KeyerEngine`/`SenderEngine` pair against
/// the current curriculum stage's words, recording mastery progress and
/// revealing/suppressing per-letter hints as the learner's confidence grows.
///
/// Intentionally decoupled from `SettingsStore`: the caller (a future
/// `RootView`) owns settings persistence and passes a plain `AppSettings`
/// snapshot down, along with the shared `ProgressStore`, `MorsePlayer`, and
/// `ToneGenerator`.
public struct LearnSendView: View {
    @StateObject private var coordinator: SendCoordinator
    private let settings: AppSettings

    public init(
        settings: AppSettings,
        progress: ProgressStore,
        player: MorsePlayer,
        tone: ToneGenerator,
        stageIndex: Int
    ) {
        self.settings = settings
        _coordinator = StateObject(wrappedValue: SendCoordinator(
            settings: settings, progress: progress, player: player, tone: tone, stageIndex: stageIndex
        ))
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Stage \(coordinator.stageIndex + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            LetterRow(
                letters: coordinator.word,
                completedCount: coordinator.completedCount,
                currentIndex: coordinator.currentIndex,
                hintForCurrent: coordinator.hintForCurrent
            )
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(coordinator.errorFlash ? Color.red.opacity(0.18) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.2), value: coordinator.errorFlash)

            TimingMeter(position: coordinator.timingPosition)
                .frame(height: 30)
                .padding(.horizontal)
                .opacity(settings.timingGate == .off ? 0.4 : 1)

            Button("Hear it") {
                coordinator.hearWord()
            }
            .buttonStyle(.bordered)

            Spacer()

            if coordinator.stageComplete {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Stage complete!")
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.mastered)
                    Text("All words in this stage are mastered.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if coordinator.isWordComplete {
                Button("Next word") {
                    coordinator.nextWord()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                KeyButton(
                    mode: settings.inputMode,
                    keySound: settings.keySound,
                    tone: coordinator.tone,
                    onDown: { coordinator.keyDown() },
                    onUp: { coordinator.keyUp() },
                    onSymbol: { coordinator.symbolPressed($0) }
                )
            }
        }
        .padding()
    }
}

/// Owns the mutable keying/matching state for `LearnSendView`: wires a
/// `KeyerEngine` (straight key) / direct symbol feed (paddle) into a
/// `SenderEngine`, tracks per-letter hesitancy, and advances through the
/// stage's word list.
@MainActor
private final class SendCoordinator: ObservableObject, @unchecked Sendable {
    let progress: ProgressStore
    let player: MorsePlayer
    let tone: ToneGenerator
    let settings: AppSettings
    let stageIndex: Int
    private let stage: CurriculumStage

    @Published private(set) var wordIndex = 0
    @Published private(set) var currentIndex = 0
    @Published private(set) var completedCount = 0
    @Published private(set) var isWordComplete = false
    @Published private(set) var stageComplete = false
    @Published var errorFlash = false
    @Published var timingPosition: Double = 0

    private var keyer: KeyerEngine!
    private var sender: SenderEngine!

    private var downAt: Date?
    private var letterStartAt = Date()
    private var firstKeyDownForLetter: Date?
    private var lastPressMs: Double?
    private var settleGeneration = 0
    private var errorFlashGeneration = 0

    var word: [Character] { Array(stage.words[wordIndex]) }

    var hintForCurrent: [MorseSymbol]? {
        guard currentIndex < word.count else { return nil }
        let letter = word[currentIndex]
        if errorFlash { return MorseCode.code(for: letter) } // force-reveal on error
        if settings.difficulty == .hard { return nil }
        if progress.isHintSuppressed(for: String(letter)) { return nil }
        return MorseCode.code(for: letter)
    }

    init(settings: AppSettings, progress: ProgressStore, player: MorsePlayer, tone: ToneGenerator, stageIndex: Int) {
        self.settings = settings
        self.progress = progress
        self.player = player
        self.tone = tone
        self.stageIndex = stageIndex
        self.stage = Curriculum.default.stages[stageIndex]
        setupWord()
    }

    private var unitMs: Double { Timing.unitMs(charWPM: settings.charWPM) }

    private func setupWord() {
        currentIndex = 0
        completedCount = 0
        isWordComplete = false
        errorFlash = false
        letterStartAt = Date()
        firstKeyDownForLetter = nil
        settleGeneration += 1
        errorFlashGeneration += 1

        let k = KeyerEngine(unitMs: unitMs)
        let s = SenderEngine(
            target: stage.words[wordIndex],
            unitMs: unitMs,
            gate: settings.timingGate,
            gracePercent: settings.gateGracePercent
        )
        k.onEvent = { [weak self] event in self?.handle(event) }
        s.onLetterComplete = { [weak self] idx in self?.handleLetterComplete(idx) }
        s.onError = { [weak self] idx in self?.handleError(idx) }
        keyer = k
        sender = s
    }

    private func handle(_ event: KeyerEvent) {
        switch event {
        case .element(let sym):
            sender.consumeTimed(.element(sym), pressMs: lastPressMs)
            updateTimingMeter(sym: sym, pressMs: lastPressMs)
        case .letterBreak, .wordBreak:
            sender.consumeTimed(event, pressMs: nil)
        }
    }

    private func handleLetterComplete(_ idx: Int) {
        let hesitancy = (firstKeyDownForLetter ?? Date()).timeIntervalSince(letterStartAt) * 1000
        progress.record(letter: String(word[idx]), correct: true, hesitancyMs: hesitancy)
        completedCount = sender.completedCount
        currentIndex = sender.currentIndex
        errorFlash = false
        letterStartAt = Date()
        firstKeyDownForLetter = nil
        if sender.isComplete { wordCompleted() }
    }

    private func handleError(_ idx: Int) {
        errorFlash = true
        errorFlashGeneration += 1
        let gen = errorFlashGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.errorFlashGeneration == gen else { return }
            self.errorFlash = false
        }
    }

    private func wordCompleted() {
        isWordComplete = true
        if wordIndex >= stage.words.count - 1 {
            stageComplete = true
            progress.completeStage(stageIndex)
        }
    }

    func nextWord() {
        guard !stageComplete, wordIndex < stage.words.count - 1 else { return }
        wordIndex += 1
        setupWord()
    }

    func hearWord() {
        player.play(String(word), settings: settings.timing, frequency: settings.frequencyHz)
    }

    // MARK: - Key input

    func keyDown() {
        let now = Date()
        if firstKeyDownForLetter == nil { firstKeyDownForLetter = now }
        downAt = now
        keyer.keyDown(at: now.timeIntervalSince1970 * 1000)
        resetSettleDebounce()
    }

    func keyUp() {
        let now = Date()
        if let d = downAt { lastPressMs = now.timeIntervalSince(d) * 1000 }
        keyer.keyUp(at: now.timeIntervalSince1970 * 1000)
        downAt = nil
        resetSettleDebounce()
    }

    func symbolPressed(_ sym: MorseSymbol) {
        // Paddle mode: KeyButton already classifies the element, so feed the
        // sender directly (no raw press duration to measure) and rely on the
        // settle debounce below to close the letter after a pause.
        if firstKeyDownForLetter == nil { firstKeyDownForLetter = Date() }
        let ideal = (sym == .dot ? 1.0 : 3.0) * unitMs
        sender.consumeTimed(.element(sym), pressMs: ideal)
        updateTimingMeter(sym: sym, pressMs: ideal)
        resetSettleDebounce()
    }

    /// After a pause with no new key activity, close out the current letter
    /// so a trailing element isn't left stranded in the buffer.
    private func resetSettleDebounce() {
        settleGeneration += 1
        let gen = settleGeneration
        let delaySeconds = (unitMs * 2.5) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            guard let self, self.settleGeneration == gen else { return }
            switch self.settings.inputMode {
            case .straightKey:
                self.keyer.flush(at: Date().timeIntervalSince1970 * 1000)
            case .paddle:
                self.sender.consumeTimed(.letterBreak, pressMs: nil)
            }
        }
    }

    private func updateTimingMeter(sym: MorseSymbol, pressMs: Double?) {
        guard let pressMs else { return }
        let ideal = (sym == .dot ? 1.0 : 3.0) * unitMs
        guard ideal > 0 else { return }
        timingPosition = max(-1, min(1, (pressMs - ideal) / ideal))
    }
}

#Preview("LearnSend") {
    LearnSendView(
        settings: AppSettings(),
        progress: try! ProgressStore(inMemory: true),
        player: MorsePlayer(tone: ToneGenerator()),
        tone: ToneGenerator(),
        stageIndex: 0
    )
}
